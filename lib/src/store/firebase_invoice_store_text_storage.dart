import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:firebase_database/firebase_database.dart';

final class FirebaseInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  FirebaseInvoiceStoreTextStorage({
    required FirebaseDatabase database,
    this.path = 'stores/shared/taxi_invoice_store_json',
  }) : _database = database;

  final FirebaseDatabase _database;
  final String path;

  DatabaseReference get _ref => _database.ref(path);

  @override
  Future<InvoiceStoreTextRead> read() async {
    final snapshot = await _ref.get();
    final value = snapshot.value;
    if (value == null) {
      return const InvoiceStoreTextRead(
        text: null,
        syncStatus: InvoiceStoreSyncStatus.online,
      );
    }
    if (value is String) {
      return InvoiceStoreTextRead(
        text: value,
        syncStatus: InvoiceStoreSyncStatus.online,
      );
    }
    throw const InvoiceStoreTextStorageException(
      'Firebase store ima neočekivan format.',
    );
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    await _ref.set(text);
    return const InvoiceStoreTextWrite(
      syncStatus: InvoiceStoreSyncStatus.online,
    );
  }
}
