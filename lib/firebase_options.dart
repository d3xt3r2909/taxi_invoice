import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

final class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _macosAppId = String.fromEnvironment('FIREBASE_MACOS_APP_ID');
  static const _windowsAppId = String.fromEnvironment(
    'FIREBASE_WINDOWS_APP_ID',
  );
  static const _fallbackAppId = String.fromEnvironment('FIREBASE_APP_ID');

  static bool get isConfigured {
    final hasBaseConfig =
        _apiKey.isNotEmpty &&
        _projectId.isNotEmpty &&
        _messagingSenderId.isNotEmpty &&
        _databaseUrl.isNotEmpty &&
        _appIdForCurrentPlatform.isNotEmpty;
    return hasBaseConfig && (!kIsWeb || _authDomain.isNotEmpty);
  }

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError('Firebase configuration is missing.');
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appIdForCurrentPlatform,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain: _emptyToNull(_authDomain),
      databaseURL: _databaseUrl,
      storageBucket: _emptyToNull(_storageBucket),
    );
  }

  static String get _appIdForCurrentPlatform {
    if (kIsWeb) {
      return _webAppId.isNotEmpty ? _webAppId : _fallbackAppId;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        _androidAppId.isNotEmpty ? _androidAppId : _fallbackAppId,
      TargetPlatform.iOS => _iosAppId.isNotEmpty ? _iosAppId : _fallbackAppId,
      TargetPlatform.macOS =>
        _macosAppId.isNotEmpty ? _macosAppId : _fallbackAppId,
      TargetPlatform.windows =>
        _windowsAppId.isNotEmpty ? _windowsAppId : _fallbackAppId,
      TargetPlatform.linux || TargetPlatform.fuchsia => _fallbackAppId,
    };
  }

  static String? _emptyToNull(String value) => value.isEmpty ? null : value;
}

final class FirebaseConfigKeys {
  const FirebaseConfigKeys._();

  static const requiredDartDefines = [
    'FIREBASE_API_KEY',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_DATABASE_URL',
    'FIREBASE_AUTH_DOMAIN',
    'FIREBASE_WEB_APP_ID or FIREBASE_APP_ID',
  ];
}
