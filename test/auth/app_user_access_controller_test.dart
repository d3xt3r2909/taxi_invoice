import 'package:app_taxi_invoice/src/auth/app_user_access_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy true entry is a normal user', () {
    expect(appUserRoleFromFirebaseValue(true), AppUserRole.user);
  });

  test('role admin entry is an admin user', () {
    expect(appUserRoleFromFirebaseValue({'role': 'admin'}), AppUserRole.admin);
  });

  test('missing entry is unknown', () {
    expect(appUserRoleFromFirebaseValue(null), AppUserRole.unknown);
  });
}
