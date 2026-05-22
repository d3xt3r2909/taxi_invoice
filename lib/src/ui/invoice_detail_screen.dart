import 'dart:typed_data';

import 'package:app_taxi_invoice/src/export/invoice_editable_export_builder.dart';
import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_color_scheme.dart';
import 'package:app_taxi_invoice/src/ui/invoice_editor_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_date_formats.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:app_taxi_invoice/src/util/file_download.dart';
import 'package:app_taxi_invoice/src/util/pdf_download.dart';
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

Future<void> _downloadEditableInvoice(
  BuildContext context,
  StoredInvoice invoice,
) async {
  try {
    await downloadFileBytes(
      bytes: buildInvoiceEditableDocxBytes(invoice),
      fileName: invoiceEditableExportFileName(invoice),
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      description: 'Word dokument',
      extensions: const ['.docx'],
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Izvoz nije dostupan'),
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
    return widget.store.invoiceById(widget.invoice.id);
  }

  Future<void> _previewPdf(BuildContext context, StoredInvoice invoice) async {
    final bytes = await buildInvoicePdfBytes(invoice);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(
          store: widget.store,
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
          '${invoiceDocumentTitle(invoice)} će nestati sa liste računa.\n\n'
          'PDF koji ste već preuzeli ili sačuvali na uređaju neće se obrisati. '
          'Ovu radnju u aplikaciji ne možete poništiti.',
          style: theme.textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Ne, zadrži', style: theme.textTheme.titleMedium),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Trajno obriši'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await store.deleteInvoice(invoice.id);
      } catch (e) {
        if (context.mounted) {
          showInvoiceStoreMutationError(context, e);
        }
        return;
      }
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
        final storedOnline = store.isInvoiceStoredOnline(invoice.id);
        final canDelete = storedOnline ? store.canWrite : true;
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
                    case _InvoiceOverflowAction.editableExport:
                      await _downloadEditableInvoice(context, invoice);
                    case _InvoiceOverflowAction.openSaved:
                      await _openLastSavedPdf(context, invoice);
                    case _InvoiceOverflowAction.delete:
                      if (context.mounted) {
                        if (!canDelete) {
                          showInvoiceStoreReadOnlyMessage(context, store);
                          return;
                        }
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
                    PopupMenuItem(
                      value: _InvoiceOverflowAction.editableExport,
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 22,
                            color: scheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Hitni izvoz za Word')),
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
                      enabled: canDelete,
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
                            if (!store.canWrite) {
                              showInvoiceStoreReadOnlyMessage(context, store);
                              return;
                            }
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

enum _InvoiceOverflowAction { share, editableExport, openSaved, delete }

/// Tamna tema: jača granica kartice; svijetla ostaje na [ColorScheme.outline].
BorderSide _invoiceDetailCardBorderSide(
  ColorScheme scheme, {
  double width = 1.2,
}) {
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
    this.store,
    this.initialSavedPdfPath,
    super.key,
  });

  final StoredInvoice invoice;
  final Uint8List pdfBytes;
  final InvoiceStoreController? store;
  final String? initialSavedPdfPath;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late String? _lastSavedPath;
  late InvoicePdfLayoutPreset _layoutPreset;
  late InvoicePdfFontSettings? _fontSettings;

  @override
  void initState() {
    super.initState();
    _lastSavedPath = widget.initialSavedPdfPath;
    _layoutPreset = widget.invoice.pdfLayoutPreset;
    _fontSettings = widget.invoice.pdfFontSettings;
  }

  StoredInvoice get _previewInvoice {
    return widget.invoice.copyWith(
      pdfLayoutPreset: _layoutPreset,
      pdfFontSettings: _fontSettings,
      clearPdfFontSettings: _fontSettings == null,
      savedPdfPath: _lastSavedPath,
    );
  }

  String get _pdfFileName => invoicePdfFileName(_previewInvoice);

  Future<Uint8List> _buildPdfBytes(PdfPageFormat format) {
    if (_layoutPreset == widget.invoice.pdfLayoutPreset &&
        _fontSettings == widget.invoice.pdfFontSettings) {
      return Future.value(widget.pdfBytes);
    }
    return buildInvoicePdfBytes(_previewInvoice);
  }

  Future<void> _openSaved(BuildContext context) async {
    final path = _lastSavedPath;
    if (path == null) {
      return;
    }
    await _openSavedPdfInSystemUi(context, path);
  }

  InvoicePdfFontSettings get _effectiveFontSettings {
    return _fontSettings ??
        InvoicePdfFontSettings.defaultsForPreset(_layoutPreset);
  }

  Future<void> _chooseLayoutPreset(BuildContext context) async {
    final selected = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Text(
                'Izgled PDF-a',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ako račun ne stane lijepo na stranicu, izaberite gušći '
                'izgled prije čuvanja ili štampe.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 10),
              for (final preset in InvoicePdfLayoutPreset.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    preset == _layoutPreset
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(_pdfLayoutPresetLabel(preset)),
                  subtitle: Text(_pdfLayoutPresetDescription(preset)),
                  onTap: () => Navigator.of(ctx).pop(preset),
                ),
              const Divider(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.text_fields_rounded),
                title: const Text('Napredne veličine teksta'),
                subtitle: const Text(
                  'Ručno podesite tekst po dijelovima računa.',
                ),
                onTap: () =>
                    Navigator.of(ctx).pop(_PdfLayoutSheetAction.advancedFonts),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !context.mounted) {
      return;
    }
    if (selected is InvoicePdfLayoutPreset) {
      if (selected == _layoutPreset && _fontSettings == null) {
        return;
      }
      await _setLayoutPreset(context, selected);
      return;
    }
    if (selected == _PdfLayoutSheetAction.advancedFonts) {
      await _chooseAdvancedFontSettings(context);
    }
  }

  Future<void> _setLayoutPreset(
    BuildContext context,
    InvoicePdfLayoutPreset preset,
  ) async {
    setState(() {
      _layoutPreset = preset;
      _fontSettings = null;
    });
    final store = widget.store;
    if (store == null) {
      return;
    }
    try {
      await store.setInvoicePdfLayoutPreset(widget.invoice.id, preset);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izgled je promijenjen samo za ovaj pregled. Nije sačuvan u bazi.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _chooseAdvancedFontSettings(BuildContext context) async {
    var draft = _effectiveFontSettings;
    final selected = await showModalBottomSheet<InvoicePdfFontSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void update(InvoicePdfFontSettings next) {
              setSheetState(() {
                draft = next;
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'Napredni tekst',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Promjena vrijedi za ovaj račun i koristi se kod '
                      'pregleda, čuvanja i štampe PDF-a.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    _PdfFontSizeSlider(
                      label: 'Podaci firme',
                      value: draft.providerFontSize,
                      onChanged: (value) =>
                          update(draft.copyWith(providerFontSize: value)),
                    ),
                    _PdfFontSizeSlider(
                      label: 'Naručilac',
                      value: draft.recipientFontSize,
                      onChanged: (value) =>
                          update(draft.copyWith(recipientFontSize: value)),
                    ),
                    _PdfFontSizeSlider(
                      label: 'Naslov računa',
                      value: draft.titleFontSize,
                      onChanged: (value) =>
                          update(draft.copyWith(titleFontSize: value)),
                    ),
                    _PdfFontSizeSlider(
                      label: 'Tabela stavki',
                      value: draft.tableFontSize,
                      onChanged: (value) =>
                          update(draft.copyWith(tableFontSize: value)),
                    ),
                    _PdfFontSizeSlider(
                      label: 'Ukupno',
                      value: draft.totalFontSize,
                      onChanged: (value) =>
                          update(draft.copyWith(totalFontSize: value)),
                    ),
                    _PdfFontSizeSlider(
                      label: 'Napomena',
                      value: draft.noteFontSize,
                      onChanged: (value) =>
                          update(draft.copyWith(noteFontSize: value)),
                    ),
                    _PdfFontSizeSlider(
                      label: 'Potpis i dno',
                      value: draft.footerFontSize,
                      onChanged: (value) =>
                          update(draft.copyWith(footerFontSize: value)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => update(
                        InvoicePdfFontSettings.defaultsForPreset(_layoutPreset),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Vrati na veličine iz preseta'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(draft),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Primijeni'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected == null || !context.mounted) {
      return;
    }
    await _setFontSettings(context, selected);
  }

  Future<void> _setFontSettings(
    BuildContext context,
    InvoicePdfFontSettings fontSettings,
  ) async {
    setState(() {
      _fontSettings = fontSettings;
    });
    final store = widget.store;
    if (store == null) {
      return;
    }
    try {
      await store.setInvoicePdfFontSettings(widget.invoice.id, fontSettings);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Veličine teksta su promijenjene samo za ovaj pregled.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _printCurrentPdf(BuildContext context) async {
    final bytes = await _buildPdfBytes(PdfPageFormat.a4);
    if (!context.mounted) {
      return;
    }
    await _layoutPrintPdf(context, bytes, _pdfFileName);
  }

  Future<void> _exportEditable(BuildContext context) async {
    await _downloadEditableInvoice(context, _previewInvoice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF · ${invoiceDocumentTitle(_previewInvoice)}'),
      ),
      body: PdfPreview(
        key: ValueKey(Object.hash(_layoutPreset, _fontSettings)),
        build: _buildPdfBytes,
        pdfFileName: _pdfFileName,
        dynamicLayout: false,
        allowPrinting: false,
        allowSharing: false,
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
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Izgled PDF-a',
            onPressed: () => _chooseLayoutPreset(context),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Hitni izvoz za Word',
            onPressed: () => _exportEditable(context),
          ),
          PdfPreviewAction(
            icon: const Tooltip(
              message: 'Sačuvaj PDF',
              child: Icon(Icons.save_alt),
            ),
            onPressed: (context, build, pageFormat) async {
              await downloadPdfBytes(
                bytes: await build(pageFormat),
                fileName: _pdfFileName,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Štampa',
            onPressed: () => _printCurrentPdf(context),
          ),
        ],
      ),
    );
  }
}

enum _PdfLayoutSheetAction { advancedFonts }

final class _PdfFontSizeSlider extends StatelessWidget {
  const _PdfFontSizeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    _formatPdfFontSize(value),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Slider(
            min: InvoicePdfFontSettings.minFontSize,
            max: InvoicePdfFontSettings.maxFontSize,
            divisions:
                ((InvoicePdfFontSettings.maxFontSize -
                            InvoicePdfFontSettings.minFontSize) *
                        2)
                    .round(),
            value: value
                .clamp(
                  InvoicePdfFontSettings.minFontSize,
                  InvoicePdfFontSettings.maxFontSize,
                )
                .toDouble(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

String _formatPdfFontSize(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) {
    return rounded.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _pdfLayoutPresetLabel(InvoicePdfLayoutPreset preset) {
  return switch (preset) {
    InvoicePdfLayoutPreset.normal => 'Normalno',
    InvoicePdfLayoutPreset.compact => 'Kompaktno',
    InvoicePdfLayoutPreset.dense => 'Najviše sabijeno',
  };
}

String _pdfLayoutPresetDescription(InvoicePdfLayoutPreset preset) {
  return switch (preset) {
    InvoicePdfLayoutPreset.normal => 'Originalni razmaci i veličina teksta.',
    InvoicePdfLayoutPreset.compact => 'Manji razmaci za račune sa više stavki.',
    InvoicePdfLayoutPreset.dense =>
      'Najmanji razmaci kada mora stati što više teksta.',
  };
}
