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

  test('async key derivation matches synchronous PBKDF2 output', () async {
    const cryptor = InvoiceStoreCryptor(iterations: 1000);
    final salt = cryptor.randomBytes(InvoiceStoreCryptor.saltLength);

    final asyncKey = await cryptor.deriveKeyAsync(
      passphrase: passphrase,
      salt: salt,
      iterations: cryptor.iterations,
      keyLength: InvoiceStoreCryptor.keyLength,
      yieldEveryIterations: 64,
    );

    expect(
      asyncKey,
      cryptor.deriveKey(
        passphrase: passphrase,
        salt: salt,
        iterations: cryptor.iterations,
        keyLength: InvoiceStoreCryptor.keyLength,
      ),
    );
  });

  test('async key derivation reports progress to completion', () async {
    const cryptor = InvoiceStoreCryptor(iterations: 128);
    final salt = cryptor.randomBytes(InvoiceStoreCryptor.saltLength);
    final progress = <double>[];

    await cryptor.deriveKeyAsync(
      passphrase: passphrase,
      salt: salt,
      iterations: cryptor.iterations,
      keyLength: InvoiceStoreCryptor.keyLength,
      yieldEveryIterations: 16,
      onProgress: progress.add,
    );

    expect(
      progress,
      allOf(anyElement(allOf(greaterThan(0), lessThan(1))), contains(1)),
    );
  });

  test('changePassphrase rotates the database password', () async {
    const nextPassphrase = 'Nova Taxi Sifra 2026!';
    final plainText = storeSnapshotToJsonString(
      StoreSnapshot.empty().copyWith(orderNames: ['Zara']),
    );
    final storage = _MemoryTextStorage(text: plainText);
    final encryption = _encryption(storage);
    await encryption.inspectForUser(userId);
    await encryption.setup(passphrase: passphrase, rememberOnDevice: false);

    await encryption.changePassphrase(
      currentPassphrase: passphrase,
      newPassphrase: nextPassphrase,
      rememberOnDevice: false,
    );
    encryption.lockInMemory();
    await encryption.inspectForUser(userId);
    await encryption.unlock(
      passphrase: nextPassphrase,
      rememberOnDevice: false,
    );

    expect((await encryption.readDecrypted()).text, plainText);
  });

  test(
    'changePassphrase keeps the store unlocked when current password fails',
    () async {
      final storage = _MemoryTextStorage(text: null);
      final encryption = _encryption(storage);
      await encryption.inspectForUser(userId);
      await encryption.setup(passphrase: passphrase, rememberOnDevice: false);

      await expectLater(
        encryption.changePassphrase(
          currentPassphrase: 'wrong password',
          newPassphrase: 'Nova Taxi Sifra 2026!',
          rememberOnDevice: false,
        ),
        throwsA(isA<InvoiceStoreEncryptionException>()),
      );

      expect(encryption.isUnlocked, isTrue);
    },
  );

  test(
    'stale unlocked key cannot overwrite a rotated database password',
    () async {
      final storage = _MemoryTextStorage(text: null);
      final adminEncryption = _encryption(storage);
      await adminEncryption.inspectForUser(userId);
      await adminEncryption.setup(
        passphrase: passphrase,
        rememberOnDevice: false,
      );
      final staleEncryption = _encryption(storage);
      await staleEncryption.inspectForUser('firebase-user-2');
      await staleEncryption.unlock(
        passphrase: passphrase,
        rememberOnDevice: false,
      );
      await adminEncryption.changePassphrase(
        currentPassphrase: passphrase,
        newPassphrase: 'Nova Taxi Sifra 2026!',
        rememberOnDevice: false,
      );

      await expectLater(
        staleEncryption.writeEncrypted(
          storeSnapshotToJsonString(StoreSnapshot.empty()),
        ),
        throwsA(isA<InvoiceStoreEncryptionException>()),
      );
    },
  );
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
