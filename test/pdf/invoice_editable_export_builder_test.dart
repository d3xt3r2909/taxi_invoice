import 'dart:convert';

import 'package:app_taxi_invoice/src/export/invoice_editable_export_builder.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invoiceEditableExportFileName uses docx extension', () {
    final invoice = _invoice();

    expect(invoiceEditableExportFileName(invoice), 'Naručilac - 7_26.docx');
  });

  test('editable export creates a docx document table', () {
    final invoice = _invoice();

    final documentXml = _docxTextFile(
      buildInvoiceEditableDocxBytes(invoice),
      'word/document.xml',
    );

    expect(documentXml, contains('<w:tbl>'));
  });

  test('editable export escapes xml control characters', () {
    final invoice = _invoice(route: 'Sarajevo <Centar> & Mostar');

    final documentXml = _docxTextFile(
      buildInvoiceEditableDocxBytes(invoice),
      'word/document.xml',
    );

    expect(documentXml, contains('Sarajevo &lt;Centar&gt; &amp; Mostar'));
  });
}

String _docxTextFile(List<int> bytes, String path) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.findFile(path);
  expect(file, isNotNull);
  final content = file!.readBytes();
  expect(content, isNotNull);
  return utf8.decode(content!);
}

StoredInvoice _invoice({String route = 'Sarajevo - Mostar'}) {
  return StoredInvoice(
    id: 'invoice-1',
    invoiceNumber: '7/26',
    issueDate: DateTime(2026, 2, 3),
    createdAt: DateTime(2026, 2, 3),
    recipientName: 'Naručilac',
    recipientAddress: 'Adresa 1',
    recipientJib: '123',
    lines: [
      InvoiceLine(
        datumRacuna: DateTime(2026, 2, 3),
        putnaRelacija: route,
        brojNarudzbe: 'Vožnja',
        iznosKm: 42,
      ),
    ],
  );
}
