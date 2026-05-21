import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
