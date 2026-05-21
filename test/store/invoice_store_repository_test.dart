import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_repository.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'loadOrCreate returns an empty snapshot when storage is empty',
    () async {
      final repository = InvoiceStoreRepository(
        storage: _MemoryInvoiceStoreTextStorage(),
      );

      final snapshot = await repository.loadOrCreate();

      expect(
        storeSnapshotToJsonString(snapshot),
        storeSnapshotToJsonString(StoreSnapshot.empty()),
      );
    },
  );

  test(
    'loadOrCreate returns an empty snapshot for invalid stored JSON',
    () async {
      final repository = InvoiceStoreRepository(
        storage: _MemoryInvoiceStoreTextStorage('{'),
      );

      final snapshot = await repository.loadOrCreate();

      expect(
        storeSnapshotToJsonString(snapshot),
        storeSnapshotToJsonString(StoreSnapshot.empty()),
      );
    },
  );

  test('save makes the snapshot available to the next load', () async {
    final storage = _MemoryInvoiceStoreTextStorage();
    final repository = InvoiceStoreRepository(storage: storage);
    final saved = StoreSnapshot(
      version: StoreSnapshot.currentVersion,
      cities: ['Sarajevo'],
      orderNames: ['Narudzba 1'],
      serviceRecipients: [],
      invoices: [],
    );

    await repository.save(saved);
    final loaded = await repository.loadOrCreate();

    expect(storeSnapshotToJsonString(loaded), storeSnapshotToJsonString(saved));
  });

  test('default storage loads an empty snapshot in browser', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = InvoiceStoreRepository();

    final snapshot = await repository.loadOrCreate();

    expect(
      storeSnapshotToJsonString(snapshot),
      storeSnapshotToJsonString(StoreSnapshot.empty()),
    );
  }, testOn: 'browser');
}

final class _MemoryInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  _MemoryInvoiceStoreTextStorage([this._text]);

  String? _text;

  @override
  Future<String?> read() async => _text;

  @override
  Future<void> write(String text) async {
    _text = text;
  }
}
