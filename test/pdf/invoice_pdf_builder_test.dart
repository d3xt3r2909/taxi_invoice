import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invoicePdfFileName uses recipient and invoice number only', () {
    final invoice = StoredInvoice(
      id: 'invoice-1',
      invoiceNumber: '6/26',
      issueDate: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      recipientName: 'Naručilac',
      lines: [
        InvoiceLine(
          datumRacuna: DateTime(2026, 1, 1),
          putnaRelacija: 'Sarajevo - Mostar',
          brojNarudzbe: 'Narudžba',
          iznosKm: 10,
        ),
      ],
    );

    expect(invoicePdfFileName(invoice), 'Naručilac - 6_26.pdf');
  });

  test('buildInvoicePdfBytes supports dense layout', () async {
    final invoice = _invoice(
      pdfLayoutPreset: InvoicePdfLayoutPreset.dense,
      lineCount: 8,
    );

    final bytes = await buildInvoicePdfBytes(invoice);

    expect(bytes, isNotEmpty);
  });

  test('buildInvoicePdfBytes supports custom font settings', () async {
    final invoice = _invoice(
      pdfFontSettings: const InvoicePdfFontSettings(
        providerFontSize: 8,
        recipientFontSize: 8,
        titleFontSize: 14,
        tableFontSize: 7,
        totalFontSize: 10,
        noteFontSize: 7,
        footerFontSize: 7,
      ),
      lineCount: 8,
    );

    final bytes = await buildInvoicePdfBytes(invoice);

    expect(bytes, isNotEmpty);
  });
}

StoredInvoice _invoice({
  InvoicePdfLayoutPreset pdfLayoutPreset = InvoicePdfLayoutPreset.normal,
  InvoicePdfFontSettings? pdfFontSettings,
  int lineCount = 1,
}) {
  return StoredInvoice(
    id: 'invoice-1',
    invoiceNumber: '6/26',
    issueDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    recipientName: 'Naručilac',
    pdfLayoutPreset: pdfLayoutPreset,
    pdfFontSettings: pdfFontSettings,
    lines: [
      for (var i = 0; i < lineCount; i++)
        InvoiceLine(
          datumRacuna: DateTime(2026, 1, 1 + i),
          putnaRelacija: 'Sarajevo - Mostar',
          brojNarudzbe: 'Narudžba',
          iznosKm: 10,
        ),
    ],
  );
}
