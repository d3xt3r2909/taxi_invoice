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
  testWidgets('filters invoice list by recipient or all invoices', (
    tester,
  ) async {
    await initializeDateFormatting('bs_BA');
    final store = await _loadedStore(
      invoices: [
        _invoice(
          id: 'zara-1',
          invoiceNumber: '05/26',
          recipientName: 'Zara',
          issueDate: DateTime(2026, 5, 5),
        ),
        _invoice(
          id: 'hotel',
          invoiceNumber: '06/26',
          recipientName: 'Hotel',
          issueDate: DateTime(2026, 6, 5),
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

    expect(find.text('Zara - 05/26'), findsOneWidget);
    expect(find.text('Hotel - 06/26'), findsOneWidget);

    await tester.tap(find.text('Zara').first);
    await tester.pumpAndSettle();

    expect(find.text('Zara - 05/26'), findsOneWidget);
    expect(find.text('Hotel - 06/26'), findsNothing);

    await tester.tap(find.text('Svi'));
    await tester.pumpAndSettle();

    expect(find.text('Zara - 05/26'), findsOneWidget);
    expect(find.text('Hotel - 06/26'), findsOneWidget);
  });

  testWidgets('sorts invoice list by creation date newest first', (
    tester,
  ) async {
    await initializeDateFormatting('bs_BA');
    final store = await _loadedStore(
      invoices: [
        _invoice(
          id: 'older-created',
          invoiceNumber: '08/26',
          recipientName: 'Stariji unos',
          issueDate: DateTime(2026, 8, 5),
          createdAt: DateTime(2026, 5, 10),
        ),
        _invoice(
          id: 'newer-created',
          invoiceNumber: '05/26',
          recipientName: 'Noviji unos',
          issueDate: DateTime(2026, 5, 5),
          createdAt: DateTime(2026, 5, 20),
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

    final newerTop = tester.getTopLeft(find.text('Noviji unos - 05/26')).dy;
    final olderTop = tester.getTopLeft(find.text('Stariji unos - 08/26')).dy;

    expect(newerTop, lessThan(olderTop));
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

  testWidgets('marks local-only invoice with online save action', (
    tester,
  ) async {
    await initializeDateFormatting('bs_BA');
    final store = await _loadedStore(
      invoices: [],
      localOnlyInvoices: [
        _invoice(
          id: 'offline',
          invoiceNumber: '05/26',
          recipientName: 'Offline firma',
          issueDate: DateTime(2026, 5, 5),
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

    expect(find.text('Nije online'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Online'), findsOneWidget);
  });

  testWidgets(
    'uses assistant as floating action and manual invoice as header action',
    (tester) async {
      await initializeDateFormatting('bs_BA');
      final store = await _loadedStore(invoices: []);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            store: store,
            settings: AppSettingsController(),
            auth: AppAuthController.notConfigured(),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('assistant-fab-expanded')),
        findsOneWidget,
      );
      expect(find.byTooltip('Napredno: novi račun ručno'), findsOneWidget);
    },
  );

  testWidgets('collapses assistant action while scrolling down', (
    tester,
  ) async {
    await initializeDateFormatting('bs_BA');
    final store = await _loadedStore(
      invoices: [
        for (var i = 0; i < 8; i++)
          _invoice(
            id: 'invoice-$i',
            invoiceNumber: '0$i/26',
            recipientName: 'Firma $i',
            issueDate: DateTime(2026, 5, i + 1),
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('assistant-fab-collapsed')),
      findsOneWidget,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('assistant-fab-expanded')),
      findsOneWidget,
    );
  });

  testWidgets('shows help requested drafts on home screen', (tester) async {
    await initializeDateFormatting('bs_BA');
    final store = await _loadedStore(
      invoices: [],
      invoiceChatDrafts: [
        InvoiceChatDraft(
          id: 'draft-1',
          createdAt: DateTime(2026, 5, 1, 8),
          updatedAt: DateTime(2026, 5, 1, 9),
          helpRequested: true,
          step: 'route',
          recipientName: 'Zara',
          issueDate: DateTime(2026, 5, 1),
          lines: const [],
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

    expect(find.text('Pomoć potrebna'), findsOneWidget);
    expect(find.text('Zara'), findsOneWidget);
  });

  testWidgets('deletes help requested draft from home screen', (tester) async {
    await initializeDateFormatting('bs_BA');
    final store = await _loadedStore(
      invoices: [],
      invoiceChatDrafts: [_draft()],
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

    await tester.tap(find.byTooltip('Obriši nacrt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Obriši'));
    await tester.pumpAndSettle();

    expect(find.text('Pomoć potrebna'), findsNothing);
  });
}

Future<InvoiceStoreController> _loadedStore({
  required List<StoredInvoice> invoices,
  List<StoredInvoice> localOnlyInvoices = const [],
  List<InvoiceChatDraft> invoiceChatDrafts = const [],
}) async {
  final storage = _MemoryInvoiceStoreTextStorage(
    storeSnapshotToJsonString(
      StoreSnapshot.empty().copyWith(
        invoices: invoices,
        invoiceChatDrafts: invoiceChatDrafts,
      ),
    ),
  );
  final controller = InvoiceStoreController(
    repository: InvoiceStoreRepository(storage: storage),
    localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(
      StoreSnapshot.empty().copyWith(invoices: localOnlyInvoices),
    ),
  );
  await controller.load();
  return controller;
}

StoredInvoice _invoice({
  required String id,
  required String invoiceNumber,
  required String recipientName,
  required DateTime issueDate,
  DateTime? createdAt,
}) {
  return StoredInvoice(
    id: id,
    invoiceNumber: invoiceNumber,
    recipientName: recipientName,
    issueDate: issueDate,
    createdAt: createdAt ?? issueDate,
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

InvoiceChatDraft _draft() {
  return InvoiceChatDraft(
    id: 'draft-1',
    createdAt: DateTime(2026, 5, 1, 8),
    updatedAt: DateTime(2026, 5, 1, 9),
    helpRequested: true,
    step: 'route',
    recipientName: 'Zara',
    issueDate: DateTime(2026, 5, 1),
    lines: const [],
  );
}

final class _MemoryInvoiceStoreTextStorage implements InvoiceStoreTextStorage {
  _MemoryInvoiceStoreTextStorage(this.text);

  String text;

  @override
  Future<InvoiceStoreTextRead> read() async {
    return InvoiceStoreTextRead(
      text: text,
      syncStatus: InvoiceStoreSyncStatus.online,
    );
  }

  @override
  Future<InvoiceStoreTextWrite> write(String text) async {
    this.text = text;
    return const InvoiceStoreTextWrite(
      syncStatus: InvoiceStoreSyncStatus.online,
    );
  }
}

final class _MemoryLocalOnlyInvoiceStorage implements LocalOnlyInvoiceStorage {
  const _MemoryLocalOnlyInvoiceStorage(this.snapshot);

  final StoreSnapshot snapshot;

  @override
  Future<StoreSnapshot> read() async => snapshot;

  @override
  Future<void> write(StoreSnapshot snapshot) async {}
}
