import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class InvoiceNumberInputFormatter extends TextInputFormatter {
  const InvoiceNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = cleanInvoiceNumberInput(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String cleanInvoiceNumberInput(String input) {
  final trimmed = input.trim();
  final slashIndex = trimmed.indexOf('/');
  if (slashIndex < 0) {
    final digits = _digitsOnly(trimmed).take(4);
    if (digits.length <= 2) {
      return digits;
    }
    return '${digits.substring(0, 2)}/${digits.substring(2)}';
  }
  final prefix = _digitsOnly(trimmed.substring(0, slashIndex)).take(2);
  final suffix = _digitsOnly(trimmed.substring(slashIndex + 1));
  if (prefix.isEmpty) {
    return suffix.take(2);
  }
  return suffix.isEmpty ? '$prefix/' : '$prefix/${suffix.take(2)}';
}

String normalizeInvoiceNumberForSave(String input) {
  final cleaned = cleanInvoiceNumberInput(input);
  if (isValidInvoiceNumberFormat(cleaned)) {
    return cleaned;
  }
  if (cleaned.contains('/')) {
    return cleaned;
  }
  final digits = _digitsOnly(input);
  if (digits.length != 4) {
    return cleaned;
  }
  return '${digits.substring(0, 2)}/${digits.substring(2)}';
}

bool isValidInvoiceNumberFormat(String input) {
  final match = RegExp(r'^(\d{2})/\d{2}$').firstMatch(input.trim());
  if (match == null) {
    return false;
  }
  final month = int.tryParse(match.group(1) ?? '');
  return month != null && month >= 1 && month <= 12;
}

List<String> suggestInvoiceNumbers(DateTime date) {
  return [
    _formatMonthYearInvoiceNumber(DateTime(date.year, date.month - 1)),
    _formatMonthYearInvoiceNumber(DateTime(date.year, date.month)),
    _formatMonthYearInvoiceNumber(DateTime(date.year, date.month + 1)),
  ];
}

Future<bool> confirmDuplicateInvoiceNumberIfNeeded({
  required BuildContext context,
  required InvoiceStoreController store,
  required String invoiceNumber,
  String? existingInvoiceId,
}) async {
  if (!store.hasInvoiceNumber(
    invoiceNumber,
    exceptInvoiceId: existingInvoiceId,
  )) {
    return true;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Broj računa već postoji'),
        content: Text(
          'Već postoji račun sa brojem $invoiceNumber.\n\n'
          'Provjerite mjesec i godinu prije čuvanja. Dva računa sa istim '
          'brojem mogu napraviti zabunu kasnije.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vrati se i provjeri'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sačuvaj isti broj'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String _formatMonthYearInvoiceNumber(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final year = (date.year % 100).toString().padLeft(2, '0');
  return '$month/$year';
}

extension on String {
  String take(int count) {
    if (length <= count) {
      return this;
    }
    return substring(0, count);
  }
}
