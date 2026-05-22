import 'package:app_taxi_invoice/src/store/invoice_models.dart';
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
    return _digitsOnly(trimmed);
  }
  final prefix = _digitsOnly(trimmed.substring(0, slashIndex));
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
  if (digits.length < 3) {
    return cleaned;
  }
  final sequence = _formatInvoiceNumberSequence(
    int.parse(digits.substring(0, digits.length - 2)),
  );
  return '$sequence/${digits.substring(digits.length - 2)}';
}

bool isValidInvoiceNumberFormat(String input) {
  final parts = parseInvoiceNumber(input);
  return parts != null && parts.sequence > 0;
}

InvoiceNumberParts? parseInvoiceNumber(String input) {
  final match = RegExp(r'^(\d+)/(\d{2})$').firstMatch(input.trim());
  if (match == null) {
    return null;
  }
  final sequence = int.tryParse(match.group(1) ?? '');
  final year = int.tryParse(match.group(2) ?? '');
  if (sequence == null || year == null) {
    return null;
  }
  return InvoiceNumberParts(sequence: sequence, year: year);
}

String suggestInvoiceNumber({
  required InvoiceStoreController store,
  required String recipientName,
  required DateTime date,
  String? existingInvoiceId,
  bool onlineOnly = false,
}) {
  return suggestInvoiceNumberForRecipient(
    invoices: onlineOnly
        ? store.snapshot.invoices
        : store.invoicesSortedByIssueDate,
    recipientName: recipientName,
    date: date,
    existingInvoiceId: existingInvoiceId,
  );
}

String suggestInvoiceNumberForRecipient({
  required Iterable<StoredInvoice> invoices,
  required String recipientName,
  required DateTime date,
  String? existingInvoiceId,
}) {
  final year = _twoDigitYear(date);
  final last = latestInvoiceNumberForRecipient(
    invoices: invoices,
    recipientName: recipientName,
    year: year,
    existingInvoiceId: existingInvoiceId,
  );
  return '${_formatInvoiceNumberSequence((last?.sequence ?? 0) + 1)}/${year.toString().padLeft(2, '0')}';
}

InvoiceNumberParts? latestInvoiceNumberForRecipient({
  required Iterable<StoredInvoice> invoices,
  required String recipientName,
  required int year,
  String? existingInvoiceId,
}) {
  final normalizedRecipient = _normalizeRecipient(recipientName);
  if (normalizedRecipient.isEmpty) {
    return null;
  }
  InvoiceNumberParts? latest;
  for (final invoice in invoices) {
    if (invoice.id == existingInvoiceId ||
        _normalizeRecipient(invoice.recipientName) != normalizedRecipient) {
      continue;
    }
    final parts = parseInvoiceNumber(invoice.invoiceNumber);
    if (parts == null || parts.year != year) {
      continue;
    }
    if (latest == null || parts.sequence > latest.sequence) {
      latest = parts;
    }
  }
  return latest;
}

bool isInvoiceNumberLowerThanLatestForRecipient({
  required Iterable<StoredInvoice> invoices,
  required String invoiceNumber,
  required String recipientName,
  String? existingInvoiceId,
}) {
  final parts = parseInvoiceNumber(invoiceNumber);
  if (parts == null) {
    return false;
  }
  final latest = latestInvoiceNumberForRecipient(
    invoices: invoices,
    recipientName: recipientName,
    year: parts.year,
    existingInvoiceId: existingInvoiceId,
  );
  return latest != null && parts.sequence < latest.sequence;
}

Future<bool> confirmDuplicateInvoiceNumberIfNeeded({
  required BuildContext context,
  required InvoiceStoreController store,
  required String invoiceNumber,
  required String recipientName,
  String? existingInvoiceId,
  bool onlineOnly = false,
}) async {
  final invoices = onlineOnly
      ? store.snapshot.invoices
      : store.invoicesSortedByIssueDate;
  final duplicate = onlineOnly
      ? store.hasOnlineInvoiceNumberForRecipient(
          invoiceNumber,
          recipientName: recipientName,
          exceptInvoiceId: existingInvoiceId,
        )
      : store.hasInvoiceNumberForRecipient(
          invoiceNumber,
          recipientName: recipientName,
          exceptInvoiceId: existingInvoiceId,
        );
  if (duplicate) {
    return _confirmInvoiceNumberWarning(
      context: context,
      title: 'Broj računa već postoji',
      message:
          'Već postoji račun za naručioca ${recipientName.trim()} sa brojem '
          '$invoiceNumber.\n\n'
          'Provjerite redni broj, godinu i naručioca prije čuvanja. Dva takva '
          'računa mogu napraviti zabunu kasnije.',
      confirmLabel: 'Sačuvaj isti broj',
    );
  }

  final lowerThanLatest = isInvoiceNumberLowerThanLatestForRecipient(
    invoices: invoices,
    invoiceNumber: invoiceNumber,
    recipientName: recipientName,
    existingInvoiceId: existingInvoiceId,
  );
  if (!lowerThanLatest) {
    return true;
  }
  return _confirmInvoiceNumberWarning(
    context: context,
    title: 'Broj računa je manji od zadnjeg',
    message: _lowerThanLatestMessage(
      invoices: invoices,
      invoiceNumber: invoiceNumber,
      recipientName: recipientName,
      existingInvoiceId: existingInvoiceId,
    ),
    confirmLabel: 'Sačuvaj ipak',
  );
}

Future<bool> _confirmInvoiceNumberWarning({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vrati se i provjeri'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

String _lowerThanLatestMessage({
  required Iterable<StoredInvoice> invoices,
  required String invoiceNumber,
  required String recipientName,
  String? existingInvoiceId,
}) {
  final parts = parseInvoiceNumber(invoiceNumber);
  final latest = parts == null
      ? null
      : latestInvoiceNumberForRecipient(
          invoices: invoices,
          recipientName: recipientName,
          year: parts.year,
          existingInvoiceId: existingInvoiceId,
        );
  if (latest == null) {
    return 'Uneseni broj računa je manji od zadnjeg broja za ovog naručioca.';
  }
  final latestLabel =
      '${_formatInvoiceNumberSequence(latest.sequence)}/${latest.year.toString().padLeft(2, '0')}';
  return 'Za naručioca ${recipientName.trim()} zadnji broj za ovu godinu je '
      '$latestLabel, a unijeli ste $invoiceNumber.\n\n'
      'Provjerite redni broj prije čuvanja.';
}

final class InvoiceNumberParts {
  const InvoiceNumberParts({required this.sequence, required this.year});

  final int sequence;
  final int year;
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String _formatInvoiceNumberSequence(int sequence) {
  return sequence.toString().padLeft(2, '0');
}

String _normalizeRecipient(String value) {
  return value.trim().toLowerCase();
}

int _twoDigitYear(DateTime date) {
  return date.year % 100;
}

extension on String {
  String take(int count) {
    if (length <= count) {
      return this;
    }
    return substring(0, count);
  }
}
