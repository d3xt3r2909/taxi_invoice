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
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> write(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, text);
  }
}
