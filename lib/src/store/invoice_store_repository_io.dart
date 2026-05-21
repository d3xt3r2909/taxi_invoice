import 'dart:io';

import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

InvoiceStoreTextStorage createInvoiceStoreTextStorage(String fileName) =>
    _FileInvoiceStoreTextStorage(fileName);

final class _FileInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  const _FileInvoiceStoreTextStorage(this._fileName);

  final String _fileName;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  @override
  Future<InvoiceStoreTextRead> read() async {
    final file = await _file();
    if (!await file.exists()) {
      return const InvoiceStoreTextRead(
        text: null,
        syncStatus: InvoiceStoreSyncStatus.localOnly,
      );
    }
    return InvoiceStoreTextRead(
      text: await file.readAsString(),
      syncStatus: InvoiceStoreSyncStatus.localOnly,
    );
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    final file = await _file();
    await file.writeAsString(text);
    return const InvoiceStoreTextWrite(
      syncStatus: InvoiceStoreSyncStatus.localOnly,
    );
  }
}
