import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

enum AppUserRole { unknown, user, admin }

extension AppUserRoleInfo on AppUserRole {
  bool get isAdmin => this == AppUserRole.admin;

  bool get isAllowed => this == AppUserRole.user || this == AppUserRole.admin;
}

final class AppUserAccessController extends ChangeNotifier {
  AppUserAccessController.configured({required FirebaseDatabase database})
    : _database = database;

  AppUserAccessController.notConfigured() : _database = null;

  final FirebaseDatabase? _database;

  AppUserRole _role = AppUserRole.unknown;
  String? _loadedUserId;
  bool _checking = false;
  String? _message;

  AppUserRole get role => _role;
  bool get isAdmin => _role.isAdmin;
  bool get isAllowed => _role.isAllowed;
  bool get isChecking => _checking;
  String? get message => _message;

  Future<void> loadForUser(String userId) async {
    final database = _database;
    if (database == null) {
      reset();
      return;
    }
    if (_loadedUserId == userId && !_checking) {
      return;
    }
    _loadedUserId = userId;
    _checking = true;
    _message = null;
    notifyListeners();
    try {
      final snapshot = await database.ref('allowedUsers/$userId').get();
      _role = appUserRoleFromFirebaseValue(snapshot.value);
      _message = _role.isAllowed
          ? null
          : 'Korisnik nije pronađen u listi odobrenih korisnika.';
    } catch (_) {
      _role = AppUserRole.unknown;
      _message =
          'Korisnička prava se nisu mogla provjeriti. Admin opcije su sakrivene.';
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  void reset() {
    _role = AppUserRole.unknown;
    _loadedUserId = null;
    _checking = false;
    _message = null;
    notifyListeners();
  }
}

AppUserRole appUserRoleFromFirebaseValue(Object? value) {
  if (value == true) {
    return AppUserRole.user;
  }
  if (value is! Map) {
    return AppUserRole.unknown;
  }

  final role = value['role'] ?? value['rola'];
  if (role is String) {
    return switch (role.trim().toLowerCase()) {
      'admin' || 'administrator' => AppUserRole.admin,
      'user' || 'korisnik' => AppUserRole.user,
      _ => AppUserRole.unknown,
    };
  }

  if (value['admin'] == true) {
    return AppUserRole.admin;
  }
  if (value['allowed'] == true || value['odobren'] == true) {
    return AppUserRole.user;
  }
  return AppUserRole.unknown;
}
