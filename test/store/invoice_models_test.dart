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
