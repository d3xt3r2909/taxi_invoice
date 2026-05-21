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

  Future<void> signIn({required String email, required String password}) async {
    if (!_isConfigured) {
      _errorMessage = 'Firebase nije podešen.';
      _status = AppAuthStatus.setupRequired;
      notifyListeners();
      return;
    }
    _status = AppAuthStatus.signingIn;
    _errorMessage = null;
    notifyListeners();
    try {
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

  Future<void> signOut() async {
    await _firebaseAuth?.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  static String _authMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'Email adresa nije ispravna.',
      'user-disabled' => 'Korisnik je onemogućen.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email ili lozinka nisu ispravni.',
      'network-request-failed' => 'Nema mrežne veze za Firebase prijavu.',
      _ => 'Prijava nije uspjela. Pokušajte ponovo.',
    };
  }
}
