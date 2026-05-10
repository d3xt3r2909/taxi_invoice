import 'dart:typed_data';

import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_color_scheme.dart';
import 'package:app_taxi_invoice/src/ui/invoice_editor_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_date_formats.dart';
import 'package:app_taxi_invoice/src/util/reveal_saved_pdf.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

bool _isMobileDevice() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> _openSavedPdfInSystemUi(BuildContext context, String path) async {
  if (kIsWeb) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nije dostupno u pregledniku.')),
      );
    }
    return;
  }
  try {
    await revealSavedPdfInSystemUi(path);
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Ne mogu otvoriti'),
        content: Text('$e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('U redu'),
          ),
        ],
      ),
    );
  }
}

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({
    required this.store,
    required this.settings,
    required this.invoice,
    super.key,
  });

  final InvoiceStoreController store;
  final AppSettingsController settings;
  final StoredInvoice invoice;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  StoredInvoice? _resolveInvoice() {
    for (final i in widget.store.snapshot.invoices) {
      if (i.id == widget.invoice.id) {
        return i;
      }
    }
    return null;
  }

  Future<void> _previewPdf(BuildContext context, StoredInvoice invoice) async {
    final bytes = await buildInvoicePdfBytes(invoice);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(
          invoice: invoice,
          pdfBytes: bytes,
          initialSavedPdfPath: invoice.savedPdfPath,
        ),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context, StoredInvoice invoice) async {
    final bytes = await buildInvoicePdfBytes(invoice);
    await Printing.sharePdf(
      bytes: bytes,
      filename: invoicePdfFileName(invoice),
    );
  }

  Future<void> _openLastSavedPdf(
    BuildContext context,
    StoredInvoice invoice,
  ) async {
    final path = invoice.savedPdfPath;
    if (path == null) {
      return;
    }
    await _openSavedPdfInSystemUi(context, path);
  }

  Future<void> _confirmAndDeleteInvoice(
    BuildContext context,
    InvoiceStoreController store,
    StoredInvoice invoice,
  ) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Obriši ovaj račun?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Ovo se ne može poništiti. Račun će nestati sa liste.',
          style: theme.textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Ne, zadrži', style: theme.textTheme.titleMedium),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da, obriši'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await store.deleteInvoice(invoice.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final invoice = _resolveInvoice();
        if (invoice == null) {
          return const Scaffold(
            body: Center(child: Text('Račun nije pronađen.')),
          );
        }
        final store = widget.store;
        final savedPath = invoice.savedPdfPath;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final actionShape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        );

        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            centerTitle: false,
            surfaceTintColor: scheme.surfaceTint,
            title: Text(
              invoiceDocumentTitle(invoice),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            actions: [
              PopupMenuButton<_InvoiceOverflowAction>(
                tooltip: 'Akcije',
                icon: const Icon(Icons.more_vert),
                onSelected: (action) async {
                  switch (action) {
                    case _InvoiceOverflowAction.share:
                      await _sharePdf(context, invoice);
                    case _InvoiceOverflowAction.openSaved:
                      await _openLastSavedPdf(context, invoice);
                    case _InvoiceOverflowAction.delete:
                      if (context.mounted) {
                        await _confirmAndDeleteInvoice(context, store, invoice);
                      }
                  }
                },
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                      value: _InvoiceOverflowAction.share,
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 22,
                            color: scheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Podijeli PDF')),
                        ],
                      ),
                    ),
                    if (savedPath != null)
                      PopupMenuItem(
                        value: _InvoiceOverflowAction.openSaved,
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_open_outlined,
                              size: 22,
                              color: scheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isMobileDevice()
                                    ? 'Otvori sačuvani PDF'
                                    : 'Pronađi PDF u folderima',
                              ),
                            ),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: _InvoiceOverflowAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 22,
                            color: scheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Obriši ovaj račun',
                              style: TextStyle(
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    if (_invoiceRecipientHasData(invoice)) ...[
                      _InvoiceRecipientCard(invoice: invoice),
                      const SizedBox(height: 16),
                    ],
                    _IssueDateCard(issueDate: invoice.issueDate),
                    const SizedBox(height: 16),
                    Text(
                      'Stavke na računu (${invoice.lines.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...invoice.lines.map(
                      (line) => _InvoiceLineRowCard(line: line),
                    ),
                    _InvoiceTotalBanner(totalKm: invoice.totalKm),
                  ],
                ),
              ),
              Material(
                elevation: 6,
                shadowColor: scheme.shadow.withValues(alpha: 0.35),
                color: scheme.brightness == Brightness.dark
                    ? scheme.surfaceContainer
                    : scheme.surface,
                child: SafeArea(
                  top: false,
                  minimum: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: actionShape,
                          ),
                          onPressed: () => _previewPdf(context, invoice),
                          icon: const Icon(Icons.visibility, size: 24),
                          label: const Text('Pregledaj PDF'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: actionShape,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => InvoiceEditorScreen(
                                  store: store,
                                  settings: widget.settings,
                                  existing: invoice,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 22),
                          label: const Text('Uredi račun'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _InvoiceOverflowAction { share, openSaved, delete }

/// Tamna tema: jača granica kartice; svijetla ostaje na [ColorScheme.outline].
BorderSide _invoiceDetailCardBorderSide(ColorScheme scheme, {double width = 1.2}) {
  if (scheme.brightness == Brightness.dark) {
    return BorderSide(
      color: scheme.onSurface.withValues(alpha: 0.24),
      width: width,
    );
  }
  return BorderSide(color: scheme.outline, width: width);
}

bool _invoiceRecipientHasData(StoredInvoice invoice) {
  return invoice.recipientName.trim().isNotEmpty ||
      invoice.recipientAddress.trim().isNotEmpty ||
      invoice.recipientJib.trim().isNotEmpty;
}

final class _InvoiceRecipientCard extends StatelessWidget {
  const _InvoiceRecipientCard({required this.invoice});

  final StoredInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final lines = <String>[
      if (invoice.recipientName.trim().isNotEmpty) invoice.recipientName.trim(),
      if (invoice.recipientAddress.trim().isNotEmpty)
        invoice.recipientAddress.trim(),
      if (invoice.recipientJib.trim().isNotEmpty)
        invoice.recipientJib.trim().toLowerCase().contains('jib')
            ? invoice.recipientJib.trim()
            : 'JIB: ${invoice.recipientJib.trim()}',
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _invoiceDetailCardBorderSide(scheme),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Naručilac usluga',
              style: text.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: text.bodyLarge?.copyWith(
                    height: 1.35,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _IssueDateCard extends StatelessWidget {
  const _IssueDateCard({required this.issueDate});

  final DateTime issueDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _invoiceDetailCardBorderSide(scheme),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datum izdavanja računa',
              style: text.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              formatInvoiceDateFull(issueDate),
              style: text.bodyLarge?.copyWith(
                height: 1.35,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _InvoiceLineRowCard extends StatelessWidget {
  const _InvoiceLineRowCard({required this.line});

  final InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final price = line.iznosKm.toStringAsFixed(2);

    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _invoiceDetailCardBorderSide(scheme, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.putnaRelacija,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Datum: ${formatInvoiceDateFull(line.datumRacuna)}',
              style: text.bodyLarge?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 6),
            Text(
              'Narudžba / ime: ${line.brojNarudzbe}',
              style: text.bodyLarge?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 12),
            Text(
              'Iznos: $price KM',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.invoiceAccent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _InvoiceTotalBanner extends StatelessWidget {
  const _InvoiceTotalBanner({required this.totalKm});

  final double totalKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final amount = totalKm.toStringAsFixed(2);

    return Material(
      color: scheme.invoiceAccent,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UKUPNO ZA NAPLATU',
              style: text.titleSmall?.copyWith(
                color: scheme.invoiceOnAccent.withValues(alpha: 0.95),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$amount KM',
              style: text.headlineSmall?.copyWith(
                color: scheme.invoiceOnAccent,
                fontWeight: FontWeight.w800,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _layoutPrintPdf(
  BuildContext context,
  Uint8List bytes,
  String filename,
) async {
  try {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: filename,
      format: PdfPageFormat.a4,
      dynamicLayout: false,
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Štampa nije dostupna'),
        content: Text(
          'Simulator obično ne podržava štampu. Na pravom telefonu ili '
          'računaru pokušajte ponovo. Ili koristite dijeljenje da sačuvate '
          'PDF i odštampate ga iz drugog programa.\n\n'
          '($e)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('U redu'),
          ),
        ],
      ),
    );
  }
}

final class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    required this.invoice,
    required this.pdfBytes,
    this.initialSavedPdfPath,
    super.key,
  });

  final StoredInvoice invoice;
  final Uint8List pdfBytes;
  final String? initialSavedPdfPath;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late String? _lastSavedPath;

  @override
  void initState() {
    super.initState();
    _lastSavedPath = widget.initialSavedPdfPath;
  }

  String get _pdfFileName => invoicePdfFileName(widget.invoice);

  Future<void> _openSaved(BuildContext context) async {
    final path = _lastSavedPath;
    if (path == null) {
      return;
    }
    await _openSavedPdfInSystemUi(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF · ${invoiceDocumentTitle(widget.invoice)}'),
      ),
      body: PdfPreview(
        build: (format) async => widget.pdfBytes,
        pdfFileName: _pdfFileName,
        dynamicLayout: false,
        allowPrinting: false,
        allowSharing: true,
        // PDF is generated as fixed A4 portrait; we ignore `format` in `build`.
        canChangePageFormat: false,
        canChangeOrientation: false,
        // Hide printing package debug toggle (pw.Document.debug); it rarely
        // refreshes the raster without leaving the screen.
        canDebug: false,
        actions: [
          if (_lastSavedPath != null)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: _isMobileDevice()
                  ? 'Otvori sačuvani PDF'
                  : 'Prikaži u sistemskim datotekama',
              onPressed: () => _openSaved(context),
            ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Štampa',
            onPressed: () =>
                _layoutPrintPdf(context, widget.pdfBytes, _pdfFileName),
          ),
        ],
      ),
    );
  }
}
