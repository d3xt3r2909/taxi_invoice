import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_repository.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:app_taxi_invoice/src/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('filters invoice list by current and previous month', (
    tester,
  ) async {
    await initializeDateFormatting('bs_BA');
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 5);
    final previousMonth = DateTime(now.year, now.month - 1, 5);
    final store = await _loadedStore(
      invoices: [
        _invoice(
          id: 'current',
          invoiceNumber: 'current',
          recipientName: 'Ovaj mjesec firma',
          issueDate: currentMonth,
        ),
        _invoice(
          id: 'previous',
          invoiceNumber: 'previous',
          recipientName: 'Prošli mjesec firma',
          issueDate: previousMonth,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: store,
          settings: AppSettingsController(),
          auth: AppAuthController.notConfigured(),
        ),
      ),
    );
    await tester.tap(find.text('Ovaj mjesec'));
    await tester.pumpAndSettle();

    expect(find.text('Ovaj mjesec firma - current'), findsOneWidget);
    expect(find.text('Prošli mjesec firma - previous'), findsNothing);

    await tester.tap(find.text('Prošli mjesec'));
    await tester.pumpAndSettle();

    expect(find.text('Ovaj mjesec firma - current'), findsNothing);
    expect(find.text('Prošli mjesec firma - previous'), findsOneWidget);
  });

  testWidgets('renders invoice list at large text scale on narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(521, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await initializeDateFormatting('bs_BA');
    final store = await _loadedStore(
      invoices: [
        _invoice(
          id: 'large-text',
          invoiceNumber: '05/26',
          recipientName: 'Dugi naziv naručioca usluge',
          issueDate: DateTime(2026, 5, 5),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.6)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: HomeScreen(
          store: store,
          settings: AppSettingsController(),
          auth: AppAuthController.notConfigured(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

Future<InvoiceStoreController> _loadedStore({
  required List<StoredInvoice> invoices,
}) async {
  final storage = _MemoryInvoiceStoreTextStorage(
    storeSnapshotToJsonString(
      StoreSnapshot.empty().copyWith(invoices: invoices),
    ),
  );
  final controller = InvoiceStoreController(
    repository: InvoiceStoreRepository(storage: storage),
  );
  await controller.load();
  return controller;
}

StoredInvoice _invoice({
  required String id,
  required String invoiceNumber,
  required String recipientName,
  required DateTime issueDate,
}) {
  return StoredInvoice(
    id: id,
    invoiceNumber: invoiceNumber,
    recipientName: recipientName,
    issueDate: issueDate,
    createdAt: issueDate,
    lines: [
      InvoiceLine(
        datumRacuna: issueDate,
        putnaRelacija: 'Sarajevo - Mostar',
        brojNarudzbe: 'Narudžba',
        iznosKm: 10,
      ),
    ],
  );
}

final class _MemoryInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  const _MemoryInvoiceStoreTextStorage(this.text);

  final String text;

  @override
  Future<InvoiceStoreTextRead> read() async {
    return InvoiceStoreTextRead(
      text: text,
      syncStatus: InvoiceStoreSyncStatus.online,
    );
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    return const InvoiceStoreTextWrite(
      syncStatus: InvoiceStoreSyncStatus.online,
    );
  }
}
