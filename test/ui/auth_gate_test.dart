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
}
