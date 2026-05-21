import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_chat_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts by asking for the invoice recipient', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceChatWizardScreen(
          store: InvoiceStoreController(),
          settings: AppSettingsController(),
        ),
      ),
    );

    expect(find.text('Za koga je račun?'), findsOneWidget);
  });
}
