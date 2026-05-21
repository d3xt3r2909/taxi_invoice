import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_chat_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('bs_BA');
  });

  testWidgets('starts by asking for the invoice recipient', (tester) async {
    await tester.pumpInvoiceChatWizard();

    expect(find.text('Za koga je račun?'), findsOneWidget);
  });

  testWidgets('shows inline recipient error', (tester) async {
    await tester.pumpInvoiceChatWizard();

    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();

    expect(find.text('Naziv naručioca je obavezan.'), findsOneWidget);
  });

  testWidgets('shows final review before saving', (tester) async {
    await tester.pumpInvoiceChatWizard();
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv naručioca'),
      'Zara',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Danas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Isto kao račun'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Relacija'),
      'Sarajevo - Mostar',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Broj narudžbe ili ime'),
      'Narudžba',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Iznos (KM)'), '45');
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Gotovo'));
    await tester.pumpAndSettle();

    expect(find.text('Provjerite prije čuvanja'), findsOneWidget);
  });
}

extension on WidgetTester {
  Future<void> pumpInvoiceChatWizard() async {
    await pumpWidget(
      MaterialApp(
        home: InvoiceChatWizardScreen(
          store: InvoiceStoreController(),
          settings: AppSettingsController(),
        ),
      ),
    );
  }
}
