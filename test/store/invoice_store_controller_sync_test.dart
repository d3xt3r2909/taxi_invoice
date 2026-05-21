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

  test('invoice save can remember a service recipient', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(StoreSnapshot.empty()),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
    );
    await controller.load();

    await controller.upsertInvoiceWithSuggestions(
      _invoice(recipientId: 'recipient-1'),
      serviceRecipient: _recipient(),
    );

    expect(controller.recipientById('recipient-1')?.name, 'Firma d.o.o.');
  });

  test('matching service recipient ignores case and whitespace', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(StoreSnapshot.empty()),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
    );
    await controller.load();
    await controller.upsertServiceRecipient(_recipient());

    final match = controller.matchingServiceRecipient(
      name: ' firma d.o.o. ',
      address: ' adresa 1 ',
      jib: ' 123 ',
    );

    expect(match?.id, 'recipient-1');
  });

  test('hasInvoiceNumber ignores the excluded invoice id', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(
        StoreSnapshot.empty().copyWith(invoices: [_invoice()]),
      ),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
    );
    await controller.load();

    expect(
      controller.hasInvoiceNumber('1/26', exceptInvoiceId: 'invoice-1'),
      isFalse,
    );
  });

  test('hasInvoiceNumber detects duplicate invoice numbers', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(
        StoreSnapshot.empty().copyWith(invoices: [_invoice()]),
      ),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
    );
    await controller.load();

    expect(controller.hasInvoiceNumber(' 1/26 '), isTrue);
  });
}

StoredInvoice _invoice({String? recipientId}) {
  return StoredInvoice(
    id: 'invoice-1',
    invoiceNumber: '1/26',
    issueDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    recipientId: recipientId,
    recipientName: recipientId == null ? '' : 'Firma d.o.o.',
    recipientAddress: recipientId == null ? '' : 'Adresa 1',
    recipientJib: recipientId == null ? '' : '123',
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

ServiceRecipient _recipient() {
  return const ServiceRecipient(
    id: 'recipient-1',
    name: 'Firma d.o.o.',
    address: 'Adresa 1',
    jib: '123',
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
