import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders settings in clear sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: AppSettingsController(),
          store: InvoiceStoreController(),
          auth: AppAuthController.notConfigured(),
        ),
      ),
    );

    expect(find.text('Nalog i sinhronizacija'), findsOneWidget);
    expect(find.text('Izgled aplikacije'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('PDF računi'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Podaci i sigurnosna kopija'), findsOneWidget);
  });

  testWidgets('shows the current app version', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: AppSettingsController(),
          store: InvoiceStoreController(),
          auth: AppAuthController.notConfigured(),
        ),
      ),
    );

    await tester.dragUntilVisible(
      find.text('Verzija aplikacije'),
      find.byType(CustomScrollView),
      const Offset(0, -500),
    );

    expect(find.text('1.0.0+1'), findsOneWidget);
  });
}
