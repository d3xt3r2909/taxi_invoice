import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';

final class CachedInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  const CachedInvoiceStoreTextStorage({
    required InvoiceStoreTextStorage cloud,
    required InvoiceStoreTextStorage cache,
  }) : _cloud = cloud,
       _cache = cache;

  final InvoiceStoreTextStorage _cloud;
  final InvoiceStoreTextStorage _cache;

  @override
  Future<InvoiceStoreTextRead> read() async {
    try {
      final cloudRead = await _cloud.read();
      final text = cloudRead.text;
      if (text != null) {
        await _cache.write(text);
      }
      return cloudRead;
    } catch (e) {
      final cached = await _cache.read();
      if (cached.text != null) {
        return InvoiceStoreTextRead(
          text: cached.text,
          syncStatus: InvoiceStoreSyncStatus.offlineCached,
          message:
              'Prikazana je zadnja lokalna kopija. Cloud sync nije dostupan.',
        );
      }
      return const InvoiceStoreTextRead(
        text: null,
        syncStatus: InvoiceStoreSyncStatus.unavailable,
        message: 'Cloud sync nije dostupan i nema lokalne kopije.',
      );
    }
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    try {
      final cloudWrite = await _cloud.write(text);
      await _cache.write(text);
      return cloudWrite;
    } catch (e) {
      throw InvoiceStoreTextStorageException(
        'Podaci nisu sačuvani u Firebase.',
        e,
      );
    }
  }
}
