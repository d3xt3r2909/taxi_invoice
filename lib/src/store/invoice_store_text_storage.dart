abstract interface class InvoiceStoreTextStorage {
  Future<String?> read();

  Future<void> write(String text);
}
