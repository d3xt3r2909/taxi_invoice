import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';

import 'invoice_store_repository_io.dart'
    if (dart.library.html) 'invoice_store_repository_web.dart'
    if (dart.library.js_interop) 'invoice_store_repository_web.dart'
    as platform;

/// Platform-backed persistence for [StoreSnapshot].
final class InvoiceStoreRepository {
  InvoiceStoreRepository({InvoiceStoreTextStorage? storage})
    : _storage = storage ?? platform.createInvoiceStoreTextStorage(fileName);

  static const String fileName = 'taxi_invoice_store.json';

  final InvoiceStoreTextStorage _storage;

  Future<StoreSnapshot> loadOrCreate() async {
    final raw = await _storage.read();
    if (raw == null || raw.trim().isEmpty) {
      return StoreSnapshot.empty();
    }
    try {
      return storeSnapshotFromJsonString(raw);
    } on FormatException {
      return StoreSnapshot.empty();
    }
  }

  Future<void> save(StoreSnapshot snapshot) async {
    await _storage.write(storeSnapshotToJsonString(snapshot));
  }

  /// Full store JSON string (for export).
  Future<String> readRaw() async {
    final raw = await _storage.read();
    if (raw == null) {
      return storeSnapshotToJsonString(StoreSnapshot.empty());
    }
    return raw;
  }

  /// Replace store from exported JSON.
  Future<void> writeRaw(String json) async {
    storeSnapshotFromJsonString(json);
    await _storage.write(json);
  }
}
