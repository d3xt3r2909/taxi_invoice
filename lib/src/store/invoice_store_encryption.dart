import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InvoiceStoreEncryptionStatus {
  disabled,
  checking,
  setupRequired,
  unlockRequired,
  unlocked,
  error,
}

extension InvoiceStoreEncryptionStatusInfo on InvoiceStoreEncryptionStatus {
  bool get isUnlocked => this == InvoiceStoreEncryptionStatus.unlocked;
}

final class InvoiceStoreEncryptionException implements Exception {
  const InvoiceStoreEncryptionException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class InvoiceStoreEncryptionController extends ChangeNotifier {
  InvoiceStoreEncryptionController({
    required InvoiceStoreTextStorage storage,
    RememberedInvoiceStoreKeyStorage? rememberedKeys,
    InvoiceStoreCryptor cryptor = const InvoiceStoreCryptor(),
  }) : _storage = storage,
       _rememberedKeys =
           rememberedKeys ?? const RememberedInvoiceStoreKeyStorage(),
       _cryptor = cryptor;

  final InvoiceStoreTextStorage _storage;
  final RememberedInvoiceStoreKeyStorage _rememberedKeys;
  final InvoiceStoreCryptor _cryptor;

  InvoiceStoreEncryptionStatus _status =
      InvoiceStoreEncryptionStatus.unlockRequired;
  String? _message;
  String? _userId;
  _UnlockedStoreKey? _key;
  bool _requiresSetup = false;

  InvoiceStoreEncryptionStatus get status => _status;
  String? get message => _message;
  bool get isUnlocked => _status.isUnlocked && _key != null;
  bool get requiresSetup => _requiresSetup;

  Future<void> inspectForUser(String userId) async {
    _userId = userId;
    _key = null;
    _setStatus(InvoiceStoreEncryptionStatus.checking);
    try {
      final read = await _storage.read();
      final raw = read.text;
      if (raw == null ||
          raw.trim().isEmpty ||
          !isEncryptedInvoiceStoreText(raw)) {
        _requiresSetup = true;
        _setStatus(InvoiceStoreEncryptionStatus.setupRequired);
        return;
      }

      _requiresSetup = false;
      final envelope = EncryptedInvoiceStoreEnvelope.fromJsonString(raw);
      final remembered = await _rememberedKeys.read(userId);
      if (remembered != null &&
          remembered.matches(
            salt: envelope.salt,
            iterations: envelope.iterations,
            keyLength: envelope.keyLength,
          )) {
        try {
          _cryptor.decrypt(envelope, remembered.key);
          _key = _UnlockedStoreKey(
            key: remembered.key,
            salt: envelope.salt,
            iterations: envelope.iterations,
            keyLength: envelope.keyLength,
          );
          _setStatus(InvoiceStoreEncryptionStatus.unlocked);
          return;
        } catch (_) {
          await _rememberedKeys.clear(userId);
        }
      }

      _requiresSetup = false;
      _setStatus(InvoiceStoreEncryptionStatus.unlockRequired);
    } catch (e) {
      _requiresSetup = false;
      _setError('Šifra baze se nije mogla provjeriti.', e);
    }
  }

  Future<void> setup({
    required String passphrase,
    required bool rememberOnDevice,
  }) async {
    final userId = _requireUserId();
    _requiresSetup = true;
    _setStatus(InvoiceStoreEncryptionStatus.checking);
    try {
      final normalized = _normalizePassphrase(passphrase);
      final raw = (await _storage.read()).text;
      if (raw != null && isEncryptedInvoiceStoreText(raw)) {
        await unlock(
          passphrase: normalized,
          rememberOnDevice: rememberOnDevice,
        );
        return;
      }
      final salt = _cryptor.randomBytes(InvoiceStoreCryptor.saltLength);
      final key = _cryptor.deriveKey(
        passphrase: normalized,
        salt: salt,
        iterations: _cryptor.iterations,
        keyLength: InvoiceStoreCryptor.keyLength,
      );
      final plaintext = raw == null || raw.trim().isEmpty
          ? storeSnapshotToJsonString(StoreSnapshot.empty())
          : raw;
      final encrypted = _cryptor.encrypt(
        plaintext: plaintext,
        key: key,
        salt: salt,
        iterations: _cryptor.iterations,
      );
      await _storage.write(encrypted);
      _key = _UnlockedStoreKey(
        key: key,
        salt: salt,
        iterations: _cryptor.iterations,
        keyLength: InvoiceStoreCryptor.keyLength,
      );
      if (rememberOnDevice) {
        await _rememberedKeys.write(userId, _key!.toRememberedKey());
      } else {
        await _rememberedKeys.clear(userId);
      }
      _setStatus(InvoiceStoreEncryptionStatus.unlocked);
    } on InvoiceStoreEncryptionException catch (e) {
      _setError(e.message, e);
    } catch (e) {
      _setError('Šifra baze se nije mogla postaviti.', e);
    }
  }

  Future<void> unlock({
    required String passphrase,
    required bool rememberOnDevice,
  }) async {
    final userId = _requireUserId();
    _setStatus(InvoiceStoreEncryptionStatus.checking);
    try {
      final normalized = _normalizePassphrase(passphrase);
      final raw = (await _storage.read()).text;
      if (raw == null || raw.trim().isEmpty) {
        _requiresSetup = true;
        _setStatus(InvoiceStoreEncryptionStatus.setupRequired);
        return;
      }
      if (!isEncryptedInvoiceStoreText(raw)) {
        _requiresSetup = true;
        _setStatus(InvoiceStoreEncryptionStatus.setupRequired);
        return;
      }
      _requiresSetup = false;
      final envelope = EncryptedInvoiceStoreEnvelope.fromJsonString(raw);
      final key = _cryptor.deriveKey(
        passphrase: normalized,
        salt: envelope.salt,
        iterations: envelope.iterations,
        keyLength: envelope.keyLength,
      );
      _cryptor.decrypt(envelope, key);
      _key = _UnlockedStoreKey(
        key: key,
        salt: envelope.salt,
        iterations: envelope.iterations,
        keyLength: envelope.keyLength,
      );
      if (rememberOnDevice) {
        await _rememberedKeys.write(userId, _key!.toRememberedKey());
      } else {
        await _rememberedKeys.clear(userId);
      }
      _setStatus(InvoiceStoreEncryptionStatus.unlocked);
    } on InvoiceStoreEncryptionException catch (e) {
      _setError(e.message, e);
    } catch (e) {
      _setError('Šifra nije ispravna.', e);
    }
  }

  Future<void> forgetRememberedKey() async {
    final userId = _userId;
    if (userId != null) {
      await _rememberedKeys.clear(userId);
    }
  }

  void lockInMemory() {
    _key = null;
    _message = null;
    _requiresSetup = false;
    _status = InvoiceStoreEncryptionStatus.unlockRequired;
    notifyListeners();
  }

  Future<InvoiceStoreTextRead> readDecrypted() async {
    final read = await _storage.read();
    final raw = read.text;
    if (raw == null || raw.trim().isEmpty) {
      return read;
    }
    if (!isEncryptedInvoiceStoreText(raw)) {
      return read;
    }
    final key = _requireKey();
    final envelope = EncryptedInvoiceStoreEnvelope.fromJsonString(raw);
    return InvoiceStoreTextRead(
      text: _cryptor.decrypt(envelope, key.key),
      syncStatus: read.syncStatus,
      message: read.message,
    );
  }

  Future<InvoiceStoreTextWrite> writeEncrypted(String plaintext) async {
    final key = _requireKey();
    final encrypted = _cryptor.encrypt(
      plaintext: plaintext,
      key: key.key,
      salt: key.salt,
      iterations: key.iterations,
    );
    return _storage.write(encrypted);
  }

  String _requireUserId() {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw const InvoiceStoreEncryptionException('Korisnik nije prijavljen.');
    }
    return userId;
  }

  _UnlockedStoreKey _requireKey() {
    final key = _key;
    if (key == null) {
      throw const InvoiceStoreEncryptionException(
        'Baza nije otključana. Unesite šifru baze.',
      );
    }
    return key;
  }

  String _normalizePassphrase(String passphrase) {
    final normalized = passphrase.trim();
    if (normalized.length < 8) {
      throw const InvoiceStoreEncryptionException(
        'Šifra baze mora imati najmanje 8 znakova.',
      );
    }
    return normalized;
  }

  void _setStatus(InvoiceStoreEncryptionStatus status) {
    _status = status;
    if (status != InvoiceStoreEncryptionStatus.error) {
      _message = null;
    }
    notifyListeners();
  }

  void _setError(String message, Object cause) {
    _message = message;
    _status = InvoiceStoreEncryptionStatus.error;
    notifyListeners();
  }
}

final class EncryptedInvoiceStoreTextStorage
    implements InvoiceStoreTextStorage {
  const EncryptedInvoiceStoreTextStorage({required this.encryption});

  final InvoiceStoreEncryptionController encryption;

  @override
  Future<InvoiceStoreTextRead> read() async {
    try {
      return await encryption.readDecrypted();
    } on InvoiceStoreEncryptionException catch (e) {
      throw InvoiceStoreTextStorageException(e.message, e);
    }
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    try {
      return await encryption.writeEncrypted(text);
    } on InvoiceStoreEncryptionException catch (e) {
      throw InvoiceStoreTextStorageException(e.message, e);
    }
  }
}

final class InvoiceStoreCryptor {
  const InvoiceStoreCryptor({this.iterations = defaultIterations});

  static const int defaultIterations = 210000;
  static const int keyLength = 32;
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int macSizeBits = 128;
  static const String associatedData = 'app_taxi_invoice_store_v1';

  final int iterations;

  Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Uint8List deriveKey({
    required String passphrase,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  String encrypt({
    required String plaintext,
    required Uint8List key,
    required Uint8List salt,
    required int iterations,
  }) {
    final nonce = randomBytes(nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          macSizeBits,
          nonce,
          Uint8List.fromList(utf8.encode(associatedData)),
        ),
      );
    final encrypted = cipher.process(
      Uint8List.fromList(utf8.encode(plaintext)),
    );
    return EncryptedInvoiceStoreEnvelope(
      salt: salt,
      iterations: iterations,
      keyLength: key.length,
      nonce: nonce,
      ciphertext: encrypted,
    ).toJsonString();
  }

  String decrypt(EncryptedInvoiceStoreEnvelope envelope, Uint8List key) {
    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(key),
            macSizeBits,
            envelope.nonce,
            Uint8List.fromList(utf8.encode(associatedData)),
          ),
        );
      final decrypted = cipher.process(envelope.ciphertext);
      return utf8.decode(decrypted);
    } catch (e) {
      throw InvoiceStoreEncryptionException('Šifra nije ispravna.', e);
    }
  }
}

bool isEncryptedInvoiceStoreText(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('{')) {
    return false;
  }
  try {
    final json = jsonDecode(trimmed);
    if (json is! Map<String, dynamic>) {
      return false;
    }
    return json['kind'] == EncryptedInvoiceStoreEnvelope.kind;
  } catch (_) {
    return false;
  }
}

final class EncryptedInvoiceStoreEnvelope {
  const EncryptedInvoiceStoreEnvelope({
    required this.salt,
    required this.iterations,
    required this.keyLength,
    required this.nonce,
    required this.ciphertext,
  });

  static const String kind = 'app_taxi_invoice.encrypted_store';
  static const int version = 1;

  final Uint8List salt;
  final int iterations;
  final int keyLength;
  final Uint8List nonce;
  final Uint8List ciphertext;

  factory EncryptedInvoiceStoreEnvelope.fromJsonString(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['kind'] != kind || json['version'] != version) {
      throw const InvoiceStoreEncryptionException(
        'Encrypted store ima neočekivan format.',
      );
    }
    return EncryptedInvoiceStoreEnvelope(
      salt: _decodeBytes(json['salt'] as String),
      iterations: json['iterations'] as int,
      keyLength: json['keyLength'] as int? ?? InvoiceStoreCryptor.keyLength,
      nonce: _decodeBytes(json['nonce'] as String),
      ciphertext: _decodeBytes(json['ciphertext'] as String),
    );
  }

  String toJsonString() {
    return jsonEncode({
      'kind': kind,
      'version': version,
      'algorithm': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'keyLength': keyLength,
      'salt': _encodeBytes(salt),
      'nonce': _encodeBytes(nonce),
      'ciphertext': _encodeBytes(ciphertext),
    });
  }
}

final class RememberedInvoiceStoreKeyStorage {
  const RememberedInvoiceStoreKeyStorage();

  static const _prefix = 'taxi_invoice_store:remembered_database_key:';

  Future<RememberedInvoiceStoreKey?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$userId');
    if (raw == null) {
      return null;
    }
    try {
      return RememberedInvoiceStoreKey.fromJsonString(raw);
    } catch (_) {
      await prefs.remove('$_prefix$userId');
      return null;
    }
  }

  Future<void> write(String userId, RememberedInvoiceStoreKey key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$userId', key.toJsonString());
  }

  Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$userId');
  }
}

final class RememberedInvoiceStoreKey {
  const RememberedInvoiceStoreKey({
    required this.key,
    required this.salt,
    required this.iterations,
    required this.keyLength,
  });

  final Uint8List key;
  final Uint8List salt;
  final int iterations;
  final int keyLength;

  factory RememberedInvoiceStoreKey.fromJsonString(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return RememberedInvoiceStoreKey(
      key: _decodeBytes(json['key'] as String),
      salt: _decodeBytes(json['salt'] as String),
      iterations: json['iterations'] as int,
      keyLength: json['keyLength'] as int,
    );
  }

  bool matches({
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    return this.iterations == iterations &&
        this.keyLength == keyLength &&
        _bytesEqual(this.salt, salt);
  }

  String toJsonString() {
    return jsonEncode({
      'version': 1,
      'key': _encodeBytes(key),
      'salt': _encodeBytes(salt),
      'iterations': iterations,
      'keyLength': keyLength,
    });
  }
}

final class _UnlockedStoreKey {
  const _UnlockedStoreKey({
    required this.key,
    required this.salt,
    required this.iterations,
    required this.keyLength,
  });

  final Uint8List key;
  final Uint8List salt;
  final int iterations;
  final int keyLength;

  RememberedInvoiceStoreKey toRememberedKey() {
    return RememberedInvoiceStoreKey(
      key: key,
      salt: salt,
      iterations: iterations,
      keyLength: keyLength,
    );
  }
}

String _encodeBytes(Uint8List bytes) => base64UrlEncode(bytes);

Uint8List _decodeBytes(String text) =>
    Uint8List.fromList(base64Url.decode(text));

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
