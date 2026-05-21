import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/ui/invoice_chat_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suggestRoutes returns frequent routes first', () {
    final snapshot = StoreSnapshot.empty().copyWith(
      invoices: [
        _invoice(route: 'Sarajevo - Mostar', createdAt: DateTime(2026, 5, 1)),
        _invoice(route: 'Zenica - Tuzla', createdAt: DateTime(2026, 5, 2)),
        _invoice(route: 'Sarajevo - Mostar', createdAt: DateTime(2026, 5, 3)),
      ],
    );

    final suggestions = suggestRoutes(snapshot);

    expect(suggestions.first, 'Sarajevo - Mostar');
  });

  test('suggestAmounts prefers amounts from matching route', () {
    final snapshot = StoreSnapshot.empty().copyWith(
      invoices: [
        _invoice(
          route: 'Sarajevo - Mostar',
          amount: 45,
          createdAt: DateTime(2026, 5, 1),
        ),
        _invoice(
          route: 'Sarajevo - Mostar',
          amount: 45,
          createdAt: DateTime(2026, 5, 2),
        ),
        _invoice(
          route: 'Zenica - Tuzla',
          amount: 80,
          createdAt: DateTime(2026, 5, 3),
        ),
      ],
    );

    final suggestions = suggestAmounts(snapshot, route: 'Sarajevo - Mostar');

    expect(suggestions.first, 45);
  });
}

StoredInvoice _invoice({
  String invoiceNumber = '1/26',
  String route = 'Sarajevo - Mostar',
  double amount = 20,
  DateTime? createdAt,
}) {
  final date = createdAt ?? DateTime(2026, 1, 1);
  return StoredInvoice(
    id: '$invoiceNumber-$route-$amount',
    invoiceNumber: invoiceNumber,
    issueDate: date,
    createdAt: date,
    recipientName: 'Test',
    lines: [
      InvoiceLine(
        datumRacuna: date,
        putnaRelacija: route,
        brojNarudzbe: 'Narudžba',
        iznosKm: amount,
      ),
    ],
  );
}
