import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter/material.dart';

String invoiceStoreSyncStatusLabel(
  InvoiceStoreSyncStatus status, {
  bool isSaving = false,
}) {
  if (isSaving) {
    return 'Sinhronizacija...';
  }
  return switch (status) {
    InvoiceStoreSyncStatus.localOnly => 'Sačuvano na uređaju',
    InvoiceStoreSyncStatus.online => 'Sačuvano',
    InvoiceStoreSyncStatus.offlineCached => 'Offline kopija',
    InvoiceStoreSyncStatus.unavailable => 'Nedostupno',
    InvoiceStoreSyncStatus.saveFailed => 'Greška pri čuvanju',
  };
}

IconData invoiceStoreSyncStatusIcon(
  InvoiceStoreSyncStatus status, {
  bool isSaving = false,
}) {
  if (isSaving) {
    return Icons.sync_rounded;
  }
  return switch (status) {
    InvoiceStoreSyncStatus.localOnly => Icons.phone_android_rounded,
    InvoiceStoreSyncStatus.online => Icons.check_circle_outline_rounded,
    InvoiceStoreSyncStatus.offlineCached => Icons.cloud_off_outlined,
    InvoiceStoreSyncStatus.unavailable => Icons.error_outline_rounded,
    InvoiceStoreSyncStatus.saveFailed => Icons.warning_amber_rounded,
  };
}

Color invoiceStoreSyncStatusColor(
  ColorScheme scheme,
  InvoiceStoreSyncStatus status, {
  bool isSaving = false,
}) {
  if (isSaving) {
    return scheme.primary;
  }
  return switch (status) {
    InvoiceStoreSyncStatus.localOnly ||
    InvoiceStoreSyncStatus.online => scheme.primary,
    InvoiceStoreSyncStatus.offlineCached => scheme.tertiary,
    InvoiceStoreSyncStatus.unavailable ||
    InvoiceStoreSyncStatus.saveFailed => scheme.error,
  };
}

void showInvoiceStoreReadOnlyMessage(
  BuildContext context,
  InvoiceStoreController store,
) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(store.readOnlyMessage)));
}

void showInvoiceStoreMutationError(BuildContext context, Object error) {
  final text = error is InvoiceStoreMutationException
      ? error.message
      : 'Podaci nisu sačuvani. Pokušajte ponovo.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
