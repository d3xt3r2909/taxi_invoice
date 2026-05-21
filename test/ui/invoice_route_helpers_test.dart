import 'package:app_taxi_invoice/src/ui/invoice_route_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseInvoiceRoute accepts common route separators', () {
    final cases = {
      'Sarajevo - Mostar': ['Sarajevo', 'Mostar'],
      'Sarajevo, Mostar': ['Sarajevo', 'Mostar'],
      'Sarajevo; Mostar': ['Sarajevo', 'Mostar'],
      'Sarajevo / Mostar': ['Sarajevo', 'Mostar'],
      'Sarajevo, Mostar / Tuzla; Zenica': [
        'Sarajevo',
        'Mostar',
        'Tuzla',
        'Zenica',
      ],
    };

    expect(
      cases.map((input, _) => MapEntry(input, parseInvoiceRoute(input))),
      cases,
    );
  });

  test('appendCityToInvoiceRoute adds city using standard separator', () {
    expect(
      appendCityToInvoiceRoute('Sarajevo, Mostar', 'Tuzla'),
      'Sarajevo - Mostar - Tuzla',
    );
  });

  test('appendCityToInvoiceRoute allows returning to an earlier city', () {
    expect(
      appendCityToInvoiceRoute('Sarajevo - Zara', 'Sarajevo'),
      'Sarajevo - Zara - Sarajevo',
    );
  });

  test('appendCityToInvoiceRoute does not duplicate the last city', () {
    expect(
      appendCityToInvoiceRoute('Sarajevo / Mostar', 'mostar'),
      'Sarajevo - Mostar',
    );
  });
}
