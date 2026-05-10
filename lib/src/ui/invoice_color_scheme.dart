import 'package:flutter/material.dart';

/// Brend zelena kao naglasak; u **tamnoj** temi [ColorScheme.primary] je neutralan
/// (siva), pa UI koristi ove gettere za ikone, iznose i fokus.
extension InvoiceColorScheme on ColorScheme {
  Color get invoiceAccent =>
      brightness == Brightness.dark ? secondary : primary;

  Color get invoiceAccentContainer =>
      brightness == Brightness.dark ? secondaryContainer : primaryContainer;

  Color get invoiceOnAccentContainer =>
      brightness == Brightness.dark ? onSecondaryContainer : onPrimaryContainer;

  /// Tekst / ikone na [invoiceAccent] pozadini (npr. ukupni iznos).
  Color get invoiceOnAccent =>
      brightness == Brightness.dark ? onSecondary : onPrimary;
}
