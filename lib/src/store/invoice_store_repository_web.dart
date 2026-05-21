import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

InvoiceStoreTextStorage createInvoiceStoreTextStorage(String fileName) =>
    _SharedPreferencesInvoiceStoreTextStorage(fileName);

final class _SharedPreferencesInvoiceStoreTextStorage
    implements InvoiceStoreTextStorage {
  const _SharedPreferencesInvoiceStoreTextStorage(this._fileName);

  static const _keyPrefix = 'taxi_invoice_store:';

  final String _fileName;

  String get _key => '$_keyPrefix$_fileName';

  @override
  Future<InvoiceStoreTextRead> read() async {
    final prefs = await SharedPreferences.getInstance();
    return InvoiceStoreTextRead(
      text: prefs.getString(_key),
      syncStatus: InvoiceStoreSyncStatus.localOnly,
    );
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, text);
    return const InvoiceStoreTextWrite(
      syncStatus: InvoiceStoreSyncStatus.localOnly,
    );
  }
}
