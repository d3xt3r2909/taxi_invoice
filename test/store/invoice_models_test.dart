import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored invoice defaults to normal pdf layout when missing', () {
    final invoice = StoredInvoice.fromJson(_invoiceJson());

    expect(invoice.pdfLayoutPreset, InvoicePdfLayoutPreset.normal);
  });

  test('stored invoice round trips a compact pdf layout', () {
    final invoice = StoredInvoice.fromJson({
      ..._invoiceJson(),
      'pdfLayoutPreset': 'compact',
    });

    expect(
      StoredInvoice.fromJson(invoice.toJson()).pdfLayoutPreset,
      InvoicePdfLayoutPreset.compact,
    );
  });

  test('stored invoice round trips custom pdf font settings', () {
    final invoice = StoredInvoice.fromJson({
      ..._invoiceJson(),
      'pdfFontSettings': {
        'providerFontSize': 9,
        'recipientFontSize': 10,
        'titleFontSize': 17,
        'tableFontSize': 8.5,
        'totalFontSize': 12,
        'noteFontSize': 8,
        'footerFontSize': 7.5,
      },
    });

    expect(
      StoredInvoice.fromJson(invoice.toJson()).pdfFontSettings?.tableFontSize,
      8.5,
    );
  });

  test('pdf font settings clamp sizes to supported range', () {
    final settings = InvoicePdfFontSettings.defaultsForPreset(
      InvoicePdfLayoutPreset.normal,
    ).copyWith(tableFontSize: 2);

    expect(settings.tableFontSize, InvoicePdfFontSettings.minFontSize);
  });

  test('store snapshot round trips invoice chat drafts', () {
    final snapshot = StoreSnapshot.empty().copyWith(
      invoiceChatDrafts: [
        InvoiceChatDraft(
          id: 'draft-1',
          createdAt: DateTime(2026, 5, 1, 8),
          updatedAt: DateTime(2026, 5, 1, 9),
          helpRequested: true,
          step: 'route',
          recipientName: 'Zara',
          invoiceNumber: '07/26',
          issueDate: DateTime(2026, 5, 1),
          lines: [
            InvoiceLine(
              datumRacuna: DateTime(2026, 5, 1),
              putnaRelacija: 'Sarajevo - Mostar',
              brojNarudzbe: 'Vožnja',
              iznosKm: 42,
            ),
          ],
        ),
      ],
    );

    final parsed = storeSnapshotFromJsonString(
      storeSnapshotToJsonString(snapshot),
    );

    expect(parsed.invoiceChatDrafts.single.helpRequested, isTrue);
  });
}

Map<String, dynamic> _invoiceJson() {
  return {
    'id': 'invoice-1',
    'invoiceNumber': '7/26',
    'issueDate': DateTime(2026, 2, 3).toIso8601String(),
    'createdAt': DateTime(2026, 2, 3).toIso8601String(),
    'lines': [
      {
        'datumRacuna': DateTime(2026, 2, 3).toIso8601String(),
        'putnaRelacija': 'Sarajevo - Mostar',
        'brojNarudzbe': 'Vožnja',
        'iznosKm': 42,
      },
    ],
  };
}
