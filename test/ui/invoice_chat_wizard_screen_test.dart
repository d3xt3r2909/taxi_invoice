import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_chat_note_image_storage.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_repository.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
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

  testWidgets('keeps answered system questions in chat', (tester) async {
    await tester.pumpInvoiceChatWizard();

    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv naručioca'),
      'Zara',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();

    expect(find.text('Za koga je račun?'), findsOneWidget);
    expect(find.text('Naručilac: Zara'), findsOneWidget);
    expect(find.text('Koji je broj računa?'), findsOneWidget);
  });

  testWidgets('edits a previous recipient answer from chat', (tester) async {
    await tester.pumpInvoiceChatWizard();
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv naručioca'),
      'Zara',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Naručilac: Zara'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv naručioca'),
      'Zara Sarajevo',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();

    expect(find.text('Naručilac: Zara Sarajevo'), findsOneWidget);
  });

  testWidgets('edits a completed line route from chat', (tester) async {
    await tester.pumpInvoiceChatWizard();
    await tester.completeOneLine();

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarajevo - Mostar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Relacija'),
      'Sarajevo - Zenica',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Gotovo'));
    await tester.pumpAndSettle();

    expect(find.text('Sarajevo - Zenica'), findsOneWidget);
  });

  testWidgets('shows final review inside chat before saving', (tester) async {
    await tester.pumpInvoiceChatWizard();
    await tester.completeOneLine();
    await tester.tap(find.widgetWithText(FilledButton, 'Gotovo'));
    await tester.pumpAndSettle();

    expect(find.text('Sačuvati online ili samo offline?'), findsOneWidget);
  });

  testWidgets('defaults final save choice to online', (tester) async {
    await tester.pumpInvoiceChatWizard();
    await tester.completeOneLine();
    await tester.tap(find.widgetWithText(FilledButton, 'Gotovo'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SegmentedButton<bool> && widget.selected.contains(true),
      ),
      findsOneWidget,
    );
  });

  testWidgets('warns before saving only offline', (tester) async {
    await tester.pumpInvoiceChatWizard();
    await tester.completeOneLine();
    await tester.tap(find.widgetWithText(FilledButton, 'Gotovo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Samo offline'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Offline račun nije u zajedničkoj bazi'),
      findsOneWidget,
    );
  });

  testWidgets('request help saves the current draft', (tester) async {
    final store = await _loadedStore();
    await tester.pumpInvoiceChatWizard(store: store);
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv naručioca'),
      'Zara',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Pomoć'));
    await tester.pumpAndSettle();

    expect(store.helpRequestedInvoiceChatDrafts.single.recipientName, 'Zara');
  });

  testWidgets('restores an existing draft', (tester) async {
    final draft = InvoiceChatDraft(
      id: 'draft-1',
      createdAt: DateTime(2026, 5, 1, 8),
      updatedAt: DateTime(2026, 5, 1, 9),
      helpRequested: true,
      step: 'invoiceNumber',
      recipientName: 'Zara',
      invoiceNumber: '07/26',
      issueDate: DateTime(2026, 5, 1),
      lines: const [],
    );

    await tester.pumpInvoiceChatWizard(draft: draft);
    await tester.pumpAndSettle();

    expect(find.text('Naručilac: Zara'), findsOneWidget);
    expect(find.text('Koji je broj računa?'), findsOneWidget);
  });

  testWidgets('restores a draft note image as a floating thumbnail', (
    tester,
  ) async {
    final draft = InvoiceChatDraft(
      id: 'draft-1',
      createdAt: DateTime(2026, 5, 1, 8),
      updatedAt: DateTime(2026, 5, 1, 9),
      step: 'recipient',
      noteImageId: 'note-1',
      noteImageMimeType: 'image/png',
      noteImageName: 'biljeska.png',
      lines: const [],
    );
    final noteImageStorage = _MemoryInvoiceChatNoteImageStorage({
      'note-1': InvoiceChatNoteImage(
        id: 'note-1',
        base64: _transparentPngBase64,
        mimeType: 'image/png',
        name: 'biljeska.png',
      ),
    });

    await tester.pumpInvoiceChatWizard(
      draft: draft,
      noteImageStorage: noteImageStorage,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Otvori sliku bilješke'), findsOneWidget);
  });

  testWidgets('opens note image markup tools from the thumbnail', (
    tester,
  ) async {
    final draft = InvoiceChatDraft(
      id: 'draft-1',
      createdAt: DateTime(2026, 5, 1, 8),
      updatedAt: DateTime(2026, 5, 1, 9),
      step: 'recipient',
      noteImageId: 'note-1',
      noteImageMimeType: 'image/png',
      noteImageName: 'biljeska.png',
      lines: const [],
    );
    final noteImageStorage = _MemoryInvoiceChatNoteImageStorage({
      'note-1': InvoiceChatNoteImage(
        id: 'note-1',
        base64: _transparentPngBase64,
        mimeType: 'image/png',
        name: 'biljeska.png',
      ),
    });

    await tester.pumpInvoiceChatWizard(
      draft: draft,
      noteImageStorage: noteImageStorage,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Otvori sliku bilješke'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Crtaj'));
    await tester.pump();
    await tester.dragFrom(
      tester.getCenter(find.byType(Dialog)),
      const Offset(40, 40),
    );
    await tester.pumpAndSettle();

    expect(noteImageStorage.images['note-1']?.drawingJson, hasLength(1));
  });

  testWidgets('draws directly on the desktop note preview', (tester) async {
    tester.view.physicalSize = const Size(1728, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final draft = InvoiceChatDraft(
      id: 'draft-1',
      createdAt: DateTime(2026, 5, 1, 8),
      updatedAt: DateTime(2026, 5, 1, 9),
      step: 'recipient',
      noteImageId: 'note-1',
      noteImageMimeType: 'image/png',
      noteImageName: 'biljeska.png',
      lines: const [],
    );
    final noteImageStorage = _MemoryInvoiceChatNoteImageStorage({
      'note-1': InvoiceChatNoteImage(
        id: 'note-1',
        base64: _transparentPngBase64,
        mimeType: 'image/png',
        name: 'biljeska.png',
      ),
    });

    await tester.pumpInvoiceChatWizard(
      draft: draft,
      noteImageStorage: noteImageStorage,
      theme: ThemeData(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crtaj'));
    await tester.pump();
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('note-image-panel-viewer'))),
      const Offset(40, 40),
    );
    await tester.pumpAndSettle();

    expect(noteImageStorage.images['note-1']?.drawingJson, hasLength(1));
  });
}

const _transparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

extension on WidgetTester {
  Future<void> pumpInvoiceChatWizard({
    InvoiceStoreController? store,
    InvoiceChatDraft? draft,
    InvoiceChatNoteImageStorage? noteImageStorage,
    ThemeData? theme,
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: theme,
        home: InvoiceChatWizardScreen(
          store:
              store ??
              InvoiceStoreController(
                localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
              ),
          settings: AppSettingsController(),
          draft: draft,
          noteImageStorage:
              noteImageStorage ?? _MemoryInvoiceChatNoteImageStorage(),
        ),
      ),
    );
  }

  Future<void> completeOneLine() async {
    await enterText(find.widgetWithText(TextField, 'Naziv naručioca'), 'Zara');
    await tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await pumpAndSettle();
    await tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await pumpAndSettle();
    await tap(find.text('Danas'));
    await pumpAndSettle();
    await tap(find.text('Isto kao račun'));
    await pumpAndSettle();
    await enterText(
      find.widgetWithText(TextField, 'Relacija'),
      'Sarajevo - Mostar',
    );
    await tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await pumpAndSettle();
    await enterText(
      find.widgetWithText(TextField, 'Broj narudžbe ili ime'),
      'Narudžba',
    );
    await tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await pumpAndSettle();
    await enterText(find.widgetWithText(TextField, 'Iznos (KM)'), '45');
    await tap(find.widgetWithText(FilledButton, 'Nastavi'));
    await pumpAndSettle();
  }
}

Future<InvoiceStoreController> _loadedStore() async {
  final controller = InvoiceStoreController(
    repository: InvoiceStoreRepository(
      storage: _MemoryInvoiceStoreTextStorage(
        storeSnapshotToJsonString(StoreSnapshot.empty()),
      ),
    ),
    localOnlyStorage: _MemoryLocalOnlyInvoiceStorage(),
  );
  await controller.load();
  return controller;
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
  StoreSnapshot snapshot = StoreSnapshot.empty();

  @override
  Future<StoreSnapshot> read() async => snapshot;

  @override
  Future<void> write(StoreSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

final class _MemoryInvoiceChatNoteImageStorage
    implements InvoiceChatNoteImageStorage {
  _MemoryInvoiceChatNoteImageStorage([Map<String, InvoiceChatNoteImage>? seed])
    : images = {...?seed};

  final Map<String, InvoiceChatNoteImage> images;

  @override
  Future<InvoiceChatNoteImage?> read(String id) async => images[id];

  @override
  Future<void> write(InvoiceChatNoteImage image) async {
    images[image.id] = image;
  }

  @override
  Future<void> delete(String id) async {
    images.remove(id);
  }
}
