import 'package:app_taxi_invoice/src/store/cached_invoice_store_text_storage.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('read returns cloud text and refreshes local cache', () async {
    final cloud = _MemoryInvoiceStoreTextStorage(
      '{"version":2,"cities":[],"orderNames":[],"serviceRecipients":[],"invoices":[]}',
      syncStatus: InvoiceStoreSyncStatus.online,
    );
    final cache = _MemoryInvoiceStoreTextStorage(null);
    final storage = CachedInvoiceStoreTextStorage(cloud: cloud, cache: cache);

    final result = await storage.read();

    expect(result.text, cache.text);
  });

  test('read returns offline cached text when cloud is unavailable', () async {
    final cloud = _MemoryInvoiceStoreTextStorage(null, throwsOnRead: true);
    final cache = _MemoryInvoiceStoreTextStorage(
      '{"version":2,"cities":[],"orderNames":[],"serviceRecipients":[],"invoices":[]}',
    );
    final storage = CachedInvoiceStoreTextStorage(cloud: cloud, cache: cache);

    final result = await storage.read();

    expect(result.syncStatus, InvoiceStoreSyncStatus.offlineCached);
  });

  test('write throws when cloud save fails', () async {
    final cloud = _MemoryInvoiceStoreTextStorage(null, throwsOnWrite: true);
    final cache = _MemoryInvoiceStoreTextStorage(null);
    final storage = CachedInvoiceStoreTextStorage(cloud: cloud, cache: cache);

    expect(
      () => storage.write('{}'),
      throwsA(isA<InvoiceStoreTextStorageException>()),
    );
  });
}

final class _MemoryInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  _MemoryInvoiceStoreTextStorage(
    this.text, {
    this.syncStatus = InvoiceStoreSyncStatus.localOnly,
    this.throwsOnRead = false,
    this.throwsOnWrite = false,
  });

  String? text;
  final InvoiceStoreSyncStatus syncStatus;
  final bool throwsOnRead;
  final bool throwsOnWrite;

  @override
  Future<InvoiceStoreTextRead> read() async {
    if (throwsOnRead) {
      throw const InvoiceStoreTextStorageException('read failed');
    }
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
