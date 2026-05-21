const String invoiceRouteSeparator = ' - ';

List<String> parseInvoiceRoute(String route) {
  return route
      .split(RegExp(r'\s*(?:[–—\-]|[,;/])\s*'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String formatInvoiceRoute(Iterable<String> parts) {
  return parts
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(invoiceRouteSeparator);
}

String appendCityToInvoiceRoute(String route, String city) {
  final trimmedCity = city.trim();
  final parts = parseInvoiceRoute(route);
  if (trimmedCity.isEmpty) {
    return formatInvoiceRoute(parts);
  }
  final normalizedCity = trimmedCity.toLowerCase();
  final normalizedLast = parts.isEmpty ? null : parts.last.toLowerCase();
  if (normalizedLast != normalizedCity) {
    parts.add(trimmedCity);
  }
  return formatInvoiceRoute(parts);
}

String normalizeInvoiceRoute(String route) {
  final parts = parseInvoiceRoute(
    route,
  ).map((e) => e.toLowerCase()).where((e) => e.isNotEmpty);
  return parts.join('|');
}
