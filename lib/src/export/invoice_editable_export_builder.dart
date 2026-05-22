import 'dart:typed_data';

import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/template/invoice_static_content.dart';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

final _editableDateFmt = DateFormat('dd.MM.yyyy.');

String invoiceEditableExportFileName(StoredInvoice invoice) {
  return invoicePdfFileName(
    invoice,
  ).replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '.docx');
}

Uint8List buildInvoiceEditableDocxBytes(StoredInvoice invoice) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypesXml))
    ..addFile(ArchiveFile.string('_rels/.rels', _packageRelationshipsXml))
    ..addFile(ArchiveFile.string('docProps/app.xml', _appPropertiesXml))
    ..addFile(ArchiveFile.string('docProps/core.xml', _corePropertiesXml))
    ..addFile(
      ArchiveFile.string(
        'word/_rels/document.xml.rels',
        _documentRelationshipsXml,
      ),
    )
    ..addFile(ArchiveFile.string('word/styles.xml', _stylesXml))
    ..addFile(ArchiveFile.string('word/document.xml', _documentXml(invoice)));
  return ZipEncoder().encodeBytes(archive);
}

String _documentXml(StoredInvoice invoice) {
  final rows = [
    _tableRow(const [
      'R.B.',
      'Datum računa',
      'Putna relacija',
      'Br. Narudžbe',
      'Iznos',
    ], bold: true),
    for (var i = 0; i < invoice.lines.length; i++)
      _tableRow([
        '${i + 1}.',
        _editableDateFmt.format(invoice.lines[i].datumRacuna),
        invoice.lines[i].putnaRelacija,
        invoice.lines[i].brojNarudzbe,
        _formatKm(invoice.lines[i].iznosKm),
      ]),
  ].join();

  final clientLines = [
    _displayRecipientName(invoice),
    ..._recipientAddressLines(invoice),
    _recipientJibLine(invoice),
  ];

  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${_paragraph(InvoiceStaticContent.providerTitle)}
    ${_paragraph(InvoiceStaticContent.providerName)}
    ${_paragraph(InvoiceStaticContent.providerAddressLine)}
    ${_paragraph(InvoiceStaticContent.providerTaxId)}
    ${_paragraph(InvoiceStaticContent.providerBankAccount)}
    ${_paragraph(InvoiceStaticContent.providerBankName)}
    ${_paragraph('', spacingAfter: 160)}
    ${_paragraph('NARUČILAC USLUGA', bold: true)}
    ${clientLines.map(_paragraph).join()}
    ${_paragraph('', spacingAfter: 220)}
    ${_paragraph('RAČUN BR. ${invoice.invoiceNumber}', bold: true, centered: true, fontSizeHalfPoints: 32, spacingAfter: 260)}
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="6" w:space="0" w:color="000000"/>
          <w:left w:val="single" w:sz="6" w:space="0" w:color="000000"/>
          <w:bottom w:val="single" w:sz="6" w:space="0" w:color="000000"/>
          <w:right w:val="single" w:sz="6" w:space="0" w:color="000000"/>
          <w:insideH w:val="single" w:sz="6" w:space="0" w:color="000000"/>
          <w:insideV w:val="single" w:sz="6" w:space="0" w:color="000000"/>
        </w:tblBorders>
        <w:tblCellMar>
          <w:top w:w="80" w:type="dxa"/>
          <w:left w:w="80" w:type="dxa"/>
          <w:bottom w:w="80" w:type="dxa"/>
          <w:right w:w="80" w:type="dxa"/>
        </w:tblCellMar>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="650"/>
        <w:gridCol w:w="1450"/>
        <w:gridCol w:w="3300"/>
        <w:gridCol w:w="1500"/>
        <w:gridCol w:w="1300"/>
      </w:tblGrid>
      $rows
    </w:tbl>
    ${_paragraph('', spacingAfter: 260)}
    ${_paragraph('UKUPNO ZA PLATITI: ${_formatKm(invoice.totalKm)}', bold: true, right: true, fontSizeHalfPoints: 26)}
    ${_paragraph(InvoiceStaticContent.vatNote, right: true)}
    ${_paragraph('', spacingAfter: 220)}
    ${_paragraph('Datum izdavanja računa:', bold: true)}
    ${_paragraph(_editableDateFmt.format(invoice.issueDate))}
    ${_paragraph('', spacingAfter: 180)}
    ${_paragraph(InvoiceStaticContent.stampPlaceholder, centered: true, bold: true)}
    ${_paragraph(InvoiceStaticContent.footerName, right: true)}
    ${_paragraph(InvoiceStaticContent.footerPhone, right: true)}
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1152" w:right="1152" w:bottom="1152" w:left="1152" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
''';
}

String _displayRecipientName(StoredInvoice invoice) {
  final name = invoice.recipientName.trim();
  return name.isNotEmpty ? name : InvoiceStaticContent.clientName;
}

List<String> _recipientAddressLines(StoredInvoice invoice) {
  final address = invoice.recipientAddress.trim();
  if (address.isEmpty) {
    return [
      InvoiceStaticContent.clientCityLine,
      InvoiceStaticContent.clientStreet,
    ];
  }
  return address
      .split(RegExp(r'\r?\n'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _recipientJibLine(StoredInvoice invoice) {
  final jib = invoice.recipientJib.trim();
  if (jib.isEmpty) {
    return InvoiceStaticContent.clientTaxId;
  }
  if (jib.toLowerCase().contains('jib')) {
    return jib;
  }
  return 'JIB: $jib';
}

String _formatKm(double amount) {
  final fixed = amount.toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed.substring(0, dot);
  final frac = fixed.substring(dot + 1);
  return '$whole,$frac KM';
}

String _tableRow(List<String> cells, {bool bold = false}) {
  return '<w:tr>${cells.map((cell) => _tableCell(cell, bold: bold)).join()}</w:tr>';
}

String _tableCell(String text, {bool bold = false}) {
  return '''
<w:tc>
  <w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>
  ${_paragraph(text, bold: bold)}
</w:tc>
''';
}

String _paragraph(
  String text, {
  bool bold = false,
  bool centered = false,
  bool right = false,
  int fontSizeHalfPoints = 22,
  int spacingAfter = 0,
}) {
  final alignment = centered
      ? '<w:jc w:val="center"/>'
      : right
      ? '<w:jc w:val="right"/>'
      : '';
  final spacing = spacingAfter > 0
      ? '<w:spacing w:after="$spacingAfter"/>'
      : '<w:spacing w:after="0"/>';
  final runProps = [
    if (bold) '<w:b/>',
    '<w:sz w:val="$fontSizeHalfPoints"/>',
  ].join();
  final escaped = _xmlEscape(text);
  final preserveSpace = text.trim() != text ? ' xml:space="preserve"' : '';
  return '''
<w:p>
  <w:pPr>$alignment$spacing</w:pPr>
  <w:r>
    <w:rPr>$runProps</w:rPr>
    <w:t$preserveSpace>$escaped</w:t>
  </w:r>
</w:p>
''';
}

String _xmlEscape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

const _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>
''';

const _packageRelationshipsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

const _documentRelationshipsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
''';

const _appPropertiesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>App Taxi Invoice</Application>
</Properties>
''';

const _corePropertiesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Taxi invoice editable export</dc:title>
  <dc:creator>App Taxi Invoice</dc:creator>
</cp:coreProperties>
''';

const _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
  </w:style>
</w:styles>
''';
