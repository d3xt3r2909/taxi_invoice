enum InvoiceStoreSyncStatus {
  localOnly,
  online,
  offlineCached,
  unavailable,
  saveFailed,
}

extension InvoiceStoreSyncStatusInfo on InvoiceStoreSyncStatus {
  bool get canWrite {
    return switch (this) {
      InvoiceStoreSyncStatus.localOnly ||
      InvoiceStoreSyncStatus.online ||
      InvoiceStoreSyncStatus.saveFailed => true,
      InvoiceStoreSyncStatus.offlineCached ||
      InvoiceStoreSyncStatus.unavailable => false,
    };
  }
}

final class InvoiceStoreTextRead {
  const InvoiceStoreTextRead({
    required this.text,
    required this.syncStatus,
    this.message,
  });

  final String? text;
  final InvoiceStoreSyncStatus syncStatus;
  final String? message;
}

final class InvoiceStoreTextWrite {
  const InvoiceStoreTextWrite({required this.syncStatus, this.message});

  final InvoiceStoreSyncStatus syncStatus;
  final String? message;
}

final class InvoiceStoreTextStorageException implements Exception {
  const InvoiceStoreTextStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class InvoiceStoreTextStorage {
  Future<InvoiceStoreTextRead> read();

  Future<InvoiceStoreTextWrite> write(String text);
}
