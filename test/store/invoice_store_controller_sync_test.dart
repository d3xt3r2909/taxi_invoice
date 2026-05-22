import 'dart:async';

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
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
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
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
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
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
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
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
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
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
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
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
    );
    await controller.load();

    expect(controller.hasInvoiceNumber(' 1/26 '), isTrue);
  });

  test(
    'hasInvoiceNumberForRecipient detects same recipient duplicate',
    () async {
      final storage = _MemoryInvoiceStoreTextStorage(
        storeSnapshotToJsonString(
          StoreSnapshot.empty().copyWith(
            invoices: [_invoice(recipientName: 'Zara')],
          ),
        ),
      );
      final controller = InvoiceStoreController(
        repository: InvoiceStoreRepository(storage: storage),
        localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
      );
      await controller.load();

      expect(
        controller.hasInvoiceNumberForRecipient(
          ' 1/26 ',
          recipientName: ' zara ',
        ),
        isTrue,
      );
    },
  );

  test('hasInvoiceNumberForRecipient allows a different recipient', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(
        StoreSnapshot.empty().copyWith(
          invoices: [_invoice(recipientName: 'Zara')],
        ),
      ),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
    );
    await controller.load();

    expect(
      controller.hasInvoiceNumberForRecipient(
        '1/26',
        recipientName: 'Drugi naručilac',
      ),
      isFalse,
    );
  });

  test('isSaving is true while a cloud save is in flight', () async {
    final writeGate = Completer<void>();
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(StoreSnapshot.empty()),
      writeGate: writeGate,
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
    );
    await controller.load();

    final save = controller.upsertInvoice(_invoice());
    await Future<void>.delayed(Duration.zero);

    expect(controller.isSaving, isTrue);
    writeGate.complete();
    await save;
  });

  test('clearAllData removes invoices and suggestions', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(
        StoreSnapshot.empty().copyWith(
          cities: ['Sarajevo'],
          orderNames: ['Zara'],
          serviceRecipients: [_recipient()],
          invoices: [_invoice(recipientId: 'recipient-1')],
        ),
      ),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
    );
    await controller.load();

    await controller.clearAllData();

    expect(controller.snapshot.toJson(), StoreSnapshot.empty().toJson());
  });

  test('local-only invoice is listed as not stored online', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(StoreSnapshot.empty()),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(
        StoreSnapshot.empty().copyWith(invoices: [_invoice()]),
      ),
    );
    await controller.load();

    expect(controller.isInvoiceStoredOnline('invoice-1'), isFalse);
  });

  test('publishing local-only invoice moves it into online snapshot', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(StoreSnapshot.empty()),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(
        StoreSnapshot.empty().copyWith(invoices: [_invoice()]),
      ),
    );
    await controller.load();

    await controller.publishLocalOnlyInvoice('invoice-1');

    expect(controller.snapshot.invoices.single.id, 'invoice-1');
    expect(controller.localOnlySnapshot.invoices, isEmpty);
  });

  test('setInvoicePdfLayoutPreset updates an online invoice', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(
        StoreSnapshot.empty().copyWith(invoices: [_invoice()]),
      ),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
    );
    await controller.load();

    await controller.setInvoicePdfLayoutPreset(
      'invoice-1',
      InvoicePdfLayoutPreset.compact,
    );

    expect(
      controller.invoiceById('invoice-1')?.pdfLayoutPreset,
      InvoicePdfLayoutPreset.compact,
    );
  });

  test('setInvoicePdfLayoutPreset clears custom font settings', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(
        StoreSnapshot.empty().copyWith(
          invoices: [_invoice().copyWith(pdfFontSettings: _fontSettings())],
        ),
      ),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
    );
    await controller.load();

    await controller.setInvoicePdfLayoutPreset(
      'invoice-1',
      InvoicePdfLayoutPreset.dense,
    );

    expect(controller.invoiceById('invoice-1')?.pdfFontSettings, isNull);
  });

  test('setInvoicePdfFontSettings updates an online invoice', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(
        StoreSnapshot.empty().copyWith(invoices: [_invoice()]),
      ),
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
    );
    await controller.load();

    await controller.setInvoicePdfFontSettings('invoice-1', _fontSettings());

    expect(
      controller.invoiceById('invoice-1')?.pdfFontSettings?.tableFontSize,
      8.5,
    );
  });

  test('setInvoicePdfLayoutPreset updates a local-only invoice', () async {
    final storage = _MemoryInvoiceStoreTextStorage(
      storeSnapshotToJsonString(StoreSnapshot.empty()),
      syncStatus: InvoiceStoreSyncStatus.offlineCached,
    );
    final controller = InvoiceStoreController(
      repository: InvoiceStoreRepository(storage: storage),
      localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(
        StoreSnapshot.empty().copyWith(invoices: [_invoice()]),
      ),
    );
    await controller.load();

    await controller.setInvoicePdfLayoutPreset(
      'invoice-1',
      InvoicePdfLayoutPreset.dense,
    );

    expect(
      controller.invoiceById('invoice-1')?.pdfLayoutPreset,
      InvoicePdfLayoutPreset.dense,
    );
  });
}

StoredInvoice _invoice({String? recipientId, String recipientName = ''}) {
  return StoredInvoice(
    id: 'invoice-1',
    invoiceNumber: '1/26',
    issueDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    recipientId: recipientId,
    recipientName: recipientName.isNotEmpty
        ? recipientName
        : recipientId == null
        ? ''
        : 'Firma d.o.o.',
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

InvoicePdfFontSettings _fontSettings() {
  return const InvoicePdfFontSettings(
    providerFontSize: 9,
    recipientFontSize: 9,
    titleFontSize: 16,
    tableFontSize: 8.5,
    totalFontSize: 12,
    noteFontSize: 8,
    footerFontSize: 8,
  );
}

final class _MemoryInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  _MemoryInvoiceStoreTextStorage(
    this.text, {
    this.syncStatus = InvoiceStoreSyncStatus.online,
    this.throwsOnWrite = false,
    this.writeGate,
  });

  String? text;
  final InvoiceStoreSyncStatus syncStatus;
  final bool throwsOnWrite;
  final Completer<void>? writeGate;

  @override
  Future<InvoiceStoreTextRead> read() async {
    return InvoiceStoreTextRead(text: text, syncStatus: syncStatus);
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    if (throwsOnWrite) {
      throw const InvoiceStoreTextStorageException('write failed');
    }
    await writeGate?.future;
    this.text = text;
    return InvoiceStoreTextWrite(syncStatus: syncStatus);
  }
}

final class _MemoryLocalOnlyInvoiceStorage implements LocalOnlyInvoiceStorage {
  _MemoryLocalOnlyInvoiceStorage([StoreSnapshot? snapshot])
    : snapshot = snapshot ?? StoreSnapshot.empty();

  StoreSnapshot snapshot;

  @override
  Future<StoreSnapshot> read() async => snapshot;

  @override
  Future<void> write(StoreSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}
