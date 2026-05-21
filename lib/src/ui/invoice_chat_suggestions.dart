import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/ui/invoice_route_helpers.dart';

List<String> suggestRoutes(StoreSnapshot snapshot, {int limit = 6}) {
  final stats = <String, _SuggestionStats>{};
  for (final invoice in snapshot.invoices) {
    for (final line in invoice.lines) {
      final route = line.putnaRelacija.trim();
      if (route.isEmpty) {
        continue;
      }
      final key = normalizeInvoiceRoute(route);
      if (key.isEmpty) {
        continue;
      }
      stats.update(
        key,
        (value) => value.add(invoice.createdAt),
        ifAbsent: () => _SuggestionStats(route, invoice.createdAt),
      );
    }
  }
  return _ranked(stats.values, limit).map((e) => e.label).toList();
}

List<double> suggestAmounts(
  StoreSnapshot snapshot, {
  String? route,
  int limit = 6,
}) {
  final routeKey = route == null ? '' : normalizeInvoiceRoute(route);
  final routeStats = <String, _SuggestionStats>{};
  final globalStats = <String, _SuggestionStats>{};
  for (final invoice in snapshot.invoices) {
    for (final line in invoice.lines) {
      final amount = line.iznosKm;
      if (amount <= 0) {
        continue;
      }
      final key = amount.toStringAsFixed(2);
      globalStats.update(
        key,
        (value) => value.add(invoice.createdAt),
        ifAbsent: () => _SuggestionStats(key, invoice.createdAt),
      );
      if (routeKey.isNotEmpty &&
          normalizeInvoiceRoute(line.putnaRelacija) == routeKey) {
        routeStats.update(
          key,
          (value) => value.add(invoice.createdAt),
          ifAbsent: () => _SuggestionStats(key, invoice.createdAt),
        );
      }
    }
  }
  final source = routeStats.isNotEmpty ? routeStats : globalStats;
  return _ranked(
    source.values,
    limit,
  ).map((e) => double.parse(e.label)).toList();
}

List<_SuggestionStats> _ranked(Iterable<_SuggestionStats> values, int limit) {
  final list = values.toList()
    ..sort((a, b) {
      final count = b.count.compareTo(a.count);
      if (count != 0) {
        return count;
      }
      final recent = b.latest.compareTo(a.latest);
      if (recent != 0) {
        return recent;
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  return list.take(limit).toList();
}

final class _SuggestionStats {
  _SuggestionStats(this.label, this.latest) : count = 1;

  final String label;
  DateTime latest;
  int count;

  _SuggestionStats add(DateTime createdAt) {
    count += 1;
    if (createdAt.isAfter(latest)) {
      latest = createdAt;
    }
    return this;
  }
}
