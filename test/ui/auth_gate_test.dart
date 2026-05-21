import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows setup screen when Firebase config is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          auth: AppAuthController.notConfigured(),
          store: InvoiceStoreController(),
          settings: AppSettingsController(),
        ),
      ),
    );

    expect(find.text('Firebase nije podešen'), findsOneWidget);
  });

  testWidgets('shows Google sign-in on login screen', (tester) async {
    await tester.pumpLoginScreen();

    expect(find.text('Prijava Google računom'), findsOneWidget);
  });

  testWidgets('keeps email sign-in on login screen', (tester) async {
    await tester.pumpLoginScreen();

    expect(find.text('Prijava emailom'), findsOneWidget);
  });

  testWidgets('shows remember sign-in checkbox on login screen', (
    tester,
  ) async {
    await tester.pumpLoginScreen();

    expect(find.text('Zapamti prijavu'), findsOneWidget);
  });
}

extension on WidgetTester {
  Future<void> pumpLoginScreen() {
    return pumpWidget(
      MaterialApp(home: LoginScreen(auth: AppAuthController.notConfigured())),
    );
  }
}
