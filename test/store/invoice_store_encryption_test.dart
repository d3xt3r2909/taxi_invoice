import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_encryption.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const passphrase = 'Taxi Racuni 2026!';
  const userId = 'firebase-user-1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'setup encrypts existing plain store and reads decrypted text',
    () async {
      final plainText = storeSnapshotToJsonString(
        StoreSnapshot.empty().copyWith(orderNames: ['Zara']),
      );
      final storage = _MemoryTextStorage(text: plainText);
      final encryption = _encryption(storage);
      await encryption.inspectForUser(userId);

      await encryption.setup(passphrase: passphrase, rememberOnDevice: false);

      expect(isEncryptedInvoiceStoreText(storage.text!), isTrue);
      expect(storage.text, isNot(contains('Zara')));
      expect((await encryption.readDecrypted()).text, plainText);
    },
  );

  test('unlock rejects a wrong password', () async {
    final storage = _MemoryTextStorage(text: null);
    final encryption = _encryption(storage);
    await encryption.inspectForUser(userId);
    await encryption.setup(passphrase: passphrase, rememberOnDevice: false);
    encryption.lockInMemory();
    await encryption.inspectForUser(userId);

    await encryption.unlock(
      passphrase: 'wrong password',
      rememberOnDevice: false,
    );

    expect(encryption.status, InvoiceStoreEncryptionStatus.error);
  });

  test('inspect unlocks with remembered key for the same user', () async {
    final plainText = storeSnapshotToJsonString(
      StoreSnapshot.empty().copyWith(cities: ['Sarajevo']),
    );
    final storage = _MemoryTextStorage(text: plainText);
    final encryption = _encryption(storage);
    await encryption.inspectForUser(userId);
    await encryption.setup(passphrase: passphrase, rememberOnDevice: true);
    final nextEncryption = _encryption(storage);

    await nextEncryption.inspectForUser(userId);

    expect(nextEncryption.status, InvoiceStoreEncryptionStatus.unlocked);
    expect((await nextEncryption.readDecrypted()).text, plainText);
  });
}

InvoiceStoreEncryptionController _encryption(_MemoryTextStorage storage) {
  return InvoiceStoreEncryptionController(
    storage: storage,
    cryptor: const InvoiceStoreCryptor(iterations: 1000),
  );
}

final class _MemoryTextStorage implements InvoiceStoreTextStorage {
  _MemoryTextStorage({this.text});

  String? text;

  @override
  Future<InvoiceStoreTextRead> read() async {
    return InvoiceStoreTextRead(
      text: text,
      syncStatus: InvoiceStoreSyncStatus.online,
    );
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    this.text = text;
    return const InvoiceStoreTextWrite(
      syncStatus: InvoiceStoreSyncStatus.online,
    );
  }
}
