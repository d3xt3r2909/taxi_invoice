import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum AppAuthStatus { setupRequired, signedOut, signingIn, signedIn }

final class AppAuthController extends ChangeNotifier {
  AppAuthController.configured({required FirebaseAuth firebaseAuth})
    : _firebaseAuth = firebaseAuth,
      _isConfigured = true,
      _status = AppAuthStatus.signedOut;

  AppAuthController.notConfigured()
    : _firebaseAuth = null,
      _isConfigured = false,
      _status = AppAuthStatus.setupRequired;

  final FirebaseAuth? _firebaseAuth;
  final bool _isConfigured;
  StreamSubscription<User?>? _authSubscription;
  AppAuthStatus _status;
  User? _user;
  String? _errorMessage;

  bool get isConfigured => _isConfigured;
  AppAuthStatus get status => _status;
  User? get user => _user;
  String? get email => _user?.email;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _status == AppAuthStatus.signedIn && _user != null;

  Future<void> load() async {
    if (!_isConfigured) {
      _status = AppAuthStatus.setupRequired;
      notifyListeners();
      return;
    }
    final auth = _firebaseAuth!;
    _user = auth.currentUser;
    _status = _user == null ? AppAuthStatus.signedOut : AppAuthStatus.signedIn;
    _authSubscription = auth.authStateChanges().listen((user) {
      _user = user;
      _errorMessage = null;
      _status = user == null ? AppAuthStatus.signedOut : AppAuthStatus.signedIn;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (!_isConfigured) {
      _setSetupRequired();
      return;
    }
    _status = AppAuthStatus.signingIn;
    _errorMessage = null;
    notifyListeners();
    try {
      await _applyPersistence(rememberMe: rememberMe);
      await _firebaseAuth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _status = AppAuthStatus.signedOut;
      _errorMessage = _authMessage(e);
      notifyListeners();
    } catch (_) {
      _status = AppAuthStatus.signedOut;
      _errorMessage = 'Prijava nije uspjela. Pokušajte ponovo.';
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle({bool rememberMe = true}) async {
    if (!_isConfigured) {
      _setSetupRequired();
      return;
    }
    _status = AppAuthStatus.signingIn;
    _errorMessage = null;
    notifyListeners();
    try {
      await _applyPersistence(rememberMe: rememberMe);
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      if (kIsWeb) {
        await _firebaseAuth!.signInWithPopup(provider);
      } else {
        await _firebaseAuth!.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      _status = AppAuthStatus.signedOut;
      _errorMessage = _authMessage(e);
      notifyListeners();
    } catch (_) {
      _status = AppAuthStatus.signedOut;
      _errorMessage = 'Google prijava nije uspjela. Pokušajte ponovo.';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth?.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setSetupRequired() {
    _errorMessage = 'Firebase nije podešen.';
    _status = AppAuthStatus.setupRequired;
    notifyListeners();
  }

  Future<void> _applyPersistence({required bool rememberMe}) async {
    if (!kIsWeb) {
      return;
    }
    await _firebaseAuth!.setPersistence(
      rememberMe ? Persistence.LOCAL : Persistence.SESSION,
    );
  }

  static String _authMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'account-exists-with-different-credential' =>
        'Račun već postoji s drugim načinom prijave.',
      'invalid-email' => 'Email adresa nije ispravna.',
      'operation-not-allowed' =>
        'Ovaj način prijave nije omogućen u Firebase konzoli.',
      'popup-closed-by-user' => 'Google prijava je otkazana.',
      'unauthorized-domain' =>
        'Domena nije odobrena za Google prijavu u Firebase konzoli.',
      'user-disabled' => 'Korisnik je onemogućen.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email ili lozinka nisu ispravni.',
      'network-request-failed' => 'Nema mrežne veze za Firebase prijavu.',
      _ => 'Prijava nije uspjela. Pokušajte ponovo.',
    };
  }
}
