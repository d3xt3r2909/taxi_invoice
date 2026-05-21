import 'package:app_taxi_invoice/src/ui/invoice_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleanInvoiceNumberInput keeps only digits and one slash', () {
    final cases = {
      '05/26': '05/26',
      '05/260': '05/26',
      ' 0526 ': '05/26',
      'AB05/26CD': '05/26',
    };

    expect(
      cases.map((input, _) => MapEntry(input, cleanInvoiceNumberInput(input))),
      cases,
    );
  });

  test(
    'normalizeInvoiceNumberForSave inserts slash between month and year',
    () {
      expect(normalizeInvoiceNumberForSave('0526'), '05/26');
    },
  );

  test('normalizeInvoiceNumberForSave keeps partial slash input invalid', () {
    expect(normalizeInvoiceNumberForSave('05/2'), '05/2');
  });

  test(
    'isValidInvoiceNumberFormat requires valid month and two digit year',
    () {
      final cases = {
        '05/26': true,
        '01/26': true,
        '12/26': true,
        '00/26': false,
        '13/26': false,
        '0526': false,
        '5/26': false,
        '05/2026': false,
      };

      expect(
        cases.map(
          (input, _) => MapEntry(input, isValidInvoiceNumberFormat(input)),
        ),
        cases,
      );
    },
  );

  test('suggestInvoiceNumbers returns previous current and next month', () {
    expect(suggestInvoiceNumbers(DateTime(2026, 5, 21)), [
      '04/26',
      '05/26',
      '06/26',
    ]);
  });

  test('suggestInvoiceNumbers handles year boundaries', () {
    expect(suggestInvoiceNumbers(DateTime(2026, 1, 2)), [
      '12/25',
      '01/26',
      '02/26',
    ]);
  });
}
