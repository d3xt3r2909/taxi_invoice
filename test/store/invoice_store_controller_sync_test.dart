import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_repository.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline cached store blocks invoice mutation', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(StoreSnapshot.empty()),
      syncStatus: InvoiceStoreSyncStatus.offlineCached,
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
    );
    await controller.load();

    expect(
      () => controller.upsertInvoice(_invoice()),
      throwsA(isA<InvoiceStoreMutationException>()),
    );
  });

  test('cloud save failure rolls back snapshot', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(StoreSnapshot.empty()),
      throwsOnWrite: true,
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
    );
    await controller.load();

    try {
      await controller.upsertInvoice(_invoice());
    } on InvoiceStoreMutationException {
      // Expected.
    }

    expect(controller.snapshot.invoices, isEmpty);
  });
}

StoredInvoice _invoice() {
  return StoredInvoice(
    id: 'invoice-1',
    invoiceNumber: '1/26',
    issueDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    lines: [
      InvoiceLine(
        datumRacuna: DateTime(2026, 1, 1),
        putnaRelacija: 'A - B',
        brojNarudzbe: 'Order',
        iznosKm: 10,
      ),
    ],
  );
}

final class _MemoryInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  _MemoryInvoiceStoreTextStorage(
    this.text, {
    this.syncStatus = InvoiceStoreSyncStatus.online,
    this.throwsOnWrite = false,
  });

  String? text;
  final InvoiceStoreSyncStatus syncStatus;
  final bool throwsOnWrite;

  @override
  Future<InvoiceStoreTextRead> read() async {
    return InvoiceStoreTextRead(text: text, syncStatus: syncStatus);
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    if (throwsOnWrite) {
      throw const InvoiceStoreTextStorageException('write failed');
    }
    this.text = text;
    return InvoiceStoreTextWrite(syncStatus: syncStatus);
  }
}
