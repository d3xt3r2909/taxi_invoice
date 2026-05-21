import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter/material.dart';

String invoiceStoreSyncStatusLabel(InvoiceStoreSyncStatus status) {
  return switch (status) {
    InvoiceStoreSyncStatus.localOnly => 'Lokalno',
    InvoiceStoreSyncStatus.online => 'Online',
    InvoiceStoreSyncStatus.offlineCached => 'Offline kopija',
    InvoiceStoreSyncStatus.unavailable => 'Nedostupno',
    InvoiceStoreSyncStatus.saveFailed => 'Greška pri čuvanju',
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
