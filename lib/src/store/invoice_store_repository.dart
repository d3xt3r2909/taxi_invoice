import 'package:app_taxi_invoice/src/store/cached_invoice_store_text_storage.dart';
import 'package:app_taxi_invoice/src/store/firebase_invoice_store_text_storage.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_encryption.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:firebase_database/firebase_database.dart';

import 'invoice_store_repository_io.dart'
    if (dart.library.html) 'invoice_store_repository_web.dart'
    if (dart.library.js_interop) 'invoice_store_repository_web.dart'
    as platform;

/// Platform-backed persistence for [StoreSnapshot].
final class InvoiceStoreRepository {
  InvoiceStoreRepository({InvoiceStoreTextStorage? storage})
    : _storage = storage ?? platform.createInvoiceStoreTextStorage(fileName);

  InvoiceStoreRepository.firebase({
    required FirebaseDatabase database,
    String cloudPath = 'stores/shared/taxi_invoice_store_json',
    InvoiceStoreEncryptionController? encryption,
  }) : _storage = encryption == null
           ? createFirebaseTextStorage(database: database, cloudPath: cloudPath)
           : EncryptedInvoiceStoreTextStorage(encryption: encryption);

  static const String fileName = 'taxi_invoice_store.json';

  static InvoiceStoreTextStorage createFirebaseTextStorage({
    required FirebaseDatabase database,
    String cloudPath = 'stores/shared/taxi_invoice_store_json',
  }) {
    return CachedInvoiceStoreTextStorage(
      cloud: FirebaseInvoiceStoreTextStorage(
        database: database,
        path: cloudPath,
      ),
      cache: platform.createInvoiceStoreTextStorage(fileName),
    );
  }

  final InvoiceStoreTextStorage _storage;
  InvoiceStoreSyncStatus _syncStatus = InvoiceStoreSyncStatus.localOnly;
  String? _syncMessage;

  InvoiceStoreSyncStatus get syncStatus => _syncStatus;
  String? get syncMessage => _syncMessage;
  bool get canWrite => _syncStatus.canWrite;

  Future<StoreSnapshot> loadOrCreate() async {
    final result = await _storage.read();
    _syncStatus = result.syncStatus;
    _syncMessage = result.message;
    final raw = result.text;
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
    try {
      final result = await _storage.write(storeSnapshotToJsonString(snapshot));
      _syncStatus = result.syncStatus;
      _syncMessage = result.message;
    } on InvoiceStoreTextStorageException catch (e) {
      _syncStatus = InvoiceStoreSyncStatus.saveFailed;
      _syncMessage = e.message;
      rethrow;
    } catch (e) {
      _syncStatus = InvoiceStoreSyncStatus.saveFailed;
      _syncMessage = 'Podaci nisu sačuvani u oblaku.';
      throw InvoiceStoreTextStorageException(_syncMessage!, e);
    }
  }

  /// Full store JSON string (for export).
  Future<String> readRaw() async {
    final result = await _storage.read();
    _syncStatus = result.syncStatus;
    _syncMessage = result.message;
    final raw = result.text;
    if (raw == null) {
      return storeSnapshotToJsonString(StoreSnapshot.empty());
    }
    return raw;
  }

  /// Replace store from exported JSON.
  Future<void> writeRaw(String json) async {
    storeSnapshotFromJsonString(json);
    try {
      final result = await _storage.write(json);
      _syncStatus = result.syncStatus;
      _syncMessage = result.message;
    } on InvoiceStoreTextStorageException catch (e) {
      _syncStatus = InvoiceStoreSyncStatus.saveFailed;
      _syncMessage = e.message;
      rethrow;
    }
  }
}
