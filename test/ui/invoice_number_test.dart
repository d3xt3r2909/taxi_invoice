import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/ui/invoice_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleanInvoiceNumberInput keeps digits and one slash', () {
    final cases = {
      '101/26': '101/26',
      '101/260': '101/26',
      ' 10126 ': '10126',
      'AB101/26CD': '101/26',
    };

    expect(
      cases.map((input, _) => MapEntry(input, cleanInvoiceNumberInput(input))),
      cases,
    );
  });

  test('normalizeInvoiceNumberForSave inserts slash before two digit year', () {
    expect(normalizeInvoiceNumberForSave('10126'), '101/26');
  });

  test('normalizeInvoiceNumberForSave pads one digit sequence', () {
    expect(normalizeInvoiceNumberForSave('726'), '07/26');
  });

  test('normalizeInvoiceNumberForSave keeps partial slash input invalid', () {
    expect(normalizeInvoiceNumberForSave('101/2'), '101/2');
  });

  test('isValidInvoiceNumberFormat requires sequence and two digit year', () {
    final cases = {
      '101/26': true,
      '1/26': true,
      '07/26': true,
      '0/26': false,
      '10126': false,
      '101/2026': false,
    };

    expect(
      cases.map(
        (input, _) => MapEntry(input, isValidInvoiceNumberFormat(input)),
      ),
      cases,
    );
  });

  test(
    'suggestInvoiceNumberForRecipient increments latest number per recipient',
    () {
      final invoices = [
        _invoice(
          id: 'zara-101',
          invoiceNumber: '101/26',
          recipientName: 'Zara',
        ),
        _invoice(
          id: 'zrak-101',
          invoiceNumber: '101/26',
          recipientName: 'Zrak',
        ),
        _invoice(
          id: 'zara-old',
          invoiceNumber: '300/25',
          recipientName: 'Zara',
        ),
      ];

      expect(
        suggestInvoiceNumberForRecipient(
          invoices: invoices,
          recipientName: 'Zara',
          date: DateTime(2026, 5, 21),
        ),
        '102/26',
      );
      expect(
        suggestInvoiceNumberForRecipient(
          invoices: invoices,
          recipientName: 'Zrak',
          date: DateTime(2026, 5, 21),
        ),
        '102/26',
      );
    },
  );

  test('suggestInvoiceNumberForRecipient starts padded for new recipient', () {
    expect(
      suggestInvoiceNumberForRecipient(
        invoices: [
          _invoice(
            id: 'zara-101',
            invoiceNumber: '101/26',
            recipientName: 'Zara',
          ),
        ],
        recipientName: 'Novi',
        date: DateTime(2026, 5, 21),
      ),
      '01/26',
    );
  });

  test('isInvoiceNumberLowerThanLatestForRecipient detects lower sequence', () {
    final invoices = [
      _invoice(id: 'zara-101', invoiceNumber: '101/26', recipientName: 'Zara'),
    ];

    expect(
      isInvoiceNumberLowerThanLatestForRecipient(
        invoices: invoices,
        invoiceNumber: '100/26',
        recipientName: 'Zara',
      ),
      isTrue,
    );
    expect(
      isInvoiceNumberLowerThanLatestForRecipient(
        invoices: invoices,
        invoiceNumber: '102/26',
        recipientName: 'Zara',
      ),
      isFalse,
    );
  });
}

StoredInvoice _invoice({
  required String id,
  required String invoiceNumber,
  required String recipientName,
}) {
  return StoredInvoice(
    id: id,
    invoiceNumber: invoiceNumber,
    recipientName: recipientName,
    issueDate: DateTime(2026, 5, 21),
    createdAt: DateTime(2026, 5, 21),
    lines: [
      InvoiceLine(
        datumRacuna: DateTime(2026, 5, 21),
        putnaRelacija: 'Sarajevo - Mostar',
        brojNarudzbe: 'Narudžba',
        iznosKm: 10,
      ),
    ],
  );
}
