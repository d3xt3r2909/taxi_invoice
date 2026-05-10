import 'package:intl/intl.dart';

/// Latinica, format datuma kao u aplikaciji (npr. petak, 8. maj 2026.).
const String invoiceUiDateLocale = 'bs_BA';

/// Puni datum: dan u sedmici, dan, mjesec, godina.
String formatInvoiceDateFull(DateTime date) =>
    DateFormat.yMMMMEEEEd(invoiceUiDateLocale).format(date);

/// Kraći datum za pickere / podnaslove (npr. 8. maj 2026.).
String formatInvoiceDateMedium(DateTime date) =>
    DateFormat.yMMMd(invoiceUiDateLocale).format(date);
