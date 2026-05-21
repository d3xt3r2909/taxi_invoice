import 'dart:typed_data';

import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_detail_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_number.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:app_taxi_invoice/src/util/invoice_output_save.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

enum InvoiceSavePostAction { backToList, newInvoice }

Future<InvoiceSavePostAction?> saveInvoiceAndOpenPdfPreview({
  required BuildContext context,
  required StoredInvoice invoice,
  required InvoiceStoreController store,
  required AppSettingsController settings,
  Iterable<String> citiesToRemember = const [],
  Iterable<String> orderNamesToRemember = const [],
  ServiceRecipient? serviceRecipientToRemember,
}) async {
  if (!store.canWrite) {
    showInvoiceStoreReadOnlyMessage(context, store);
    return null;
  }
  final canSaveDuplicate = await confirmDuplicateInvoiceNumberIfNeeded(
    context: context,
    store: store,
    invoiceNumber: invoice.invoiceNumber,
    existingInvoiceId: invoice.id,
  );
  if (!context.mounted || !canSaveDuplicate) {
    return null;
  }
  try {
    await store.upsertInvoiceWithSuggestions(
      invoice,
      cities: citiesToRemember,
      orderNames: orderNamesToRemember,
      serviceRecipient: serviceRecipientToRemember,
    );
  } catch (e) {
    if (context.mounted) {
      showInvoiceStoreMutationError(context, e);
    }
    return null;
  }

  final bytes = await buildInvoicePdfBytes(invoice);
  if (!context.mounted) {
    return null;
  }

  var savedPath = invoice.savedPdfPath;

  if (!kIsWeb) {
    final dir = settings.pdfOutputDirectory;
    if (dir == null || dir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'U Postavkama odaberite folder u koji se snimaju PDF računi, '
            'pa pokušajte ponovo.',
          ),
        ),
      );
      return null;
    }
    final path = await saveInvoicePdfToOutputDirectory(
      context: context,
      directoryPath: dir,
      bytes: bytes,
      fileName: invoicePdfFileName(invoice),
    );
    if (!context.mounted || path == null) {
      return null;
    }
    savedPath = path;
    try {
      await store.setInvoiceSavedPdfPath(invoice.id, path);
    } catch (e) {
      if (context.mounted) {
        showInvoiceStoreMutationError(context, e);
      }
    }
  }

  if (!context.mounted) {
    return null;
  }
  final previewInvoice = savedPath == invoice.savedPdfPath
      ? invoice
      : invoice.copyWith(savedPdfPath: savedPath);
  final action = await Navigator.of(context).push<InvoiceSavePostAction>(
    MaterialPageRoute<InvoiceSavePostAction>(
      builder: (_) => InvoiceSavedScreen(
        invoice: previewInvoice,
        pdfBytes: bytes,
        savedPdfPath: savedPath,
      ),
    ),
  );
  return action ?? InvoiceSavePostAction.backToList;
}

final class InvoiceSavedScreen extends StatelessWidget {
  const InvoiceSavedScreen({
    required this.invoice,
    required this.pdfBytes,
    required this.savedPdfPath,
    super.key,
  });

  final StoredInvoice invoice;
  final Uint8List pdfBytes;
  final String? savedPdfPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Račun sačuvan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 76,
              color: scheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Račun je sačuvan',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              invoiceDocumentTitle(invoice),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (savedPdfPath != null && savedPdfPath!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'PDF je snimljen u odabrani folder.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PdfPreviewScreen(
                      invoice: invoice,
                      pdfBytes: pdfBytes,
                      initialSavedPdfPath: savedPdfPath,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Otvori PDF'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(InvoiceSavePostAction.newInvoice);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novi račun'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop(InvoiceSavePostAction.backToList);
              },
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Nazad na listu'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
