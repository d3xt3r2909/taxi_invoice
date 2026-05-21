import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_detail_screen.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:app_taxi_invoice/src/util/invoice_output_save.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

Future<bool> saveInvoiceAndOpenPdfPreview({
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
    return false;
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
    return false;
  }

  final bytes = await buildInvoicePdfBytes(invoice);
  if (!context.mounted) {
    return false;
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
      return false;
    }
    final path = await saveInvoicePdfToOutputDirectory(
      context: context,
      directoryPath: dir,
      bytes: bytes,
      fileName: invoicePdfFileName(invoice),
    );
    if (!context.mounted || path == null) {
      return false;
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
    return false;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PdfPreviewScreen(
        invoice: invoice,
        pdfBytes: bytes,
        initialSavedPdfPath: savedPath,
      ),
    ),
  );
  return true;
}
