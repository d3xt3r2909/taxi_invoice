import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/template/invoice_static_content.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final _issueDateFmt = DateFormat('dd.MM.yyyy.');

String _displayRecipientName(StoredInvoice invoice) {
  final t = invoice.recipientName.trim();
  if (t.isNotEmpty) {
    return t;
  }
  return InvoiceStaticContent.clientName;
}

String _sanitizePdfFileNameSegment(String raw) {
  var s = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  while (s.endsWith('.')) {
    s = s.substring(0, s.length - 1).trim();
  }
  if (s.isEmpty) {
    return 'Račun';
  }
  return s;
}

/// Prikaz u aplikaciji, npr. „ITX BH d.o.o. - 6/26”.
String invoiceDocumentTitle(StoredInvoice invoice) {
  final name = _displayRecipientName(invoice);
  final no = invoice.invoiceNumber.trim();
  if (no.isEmpty) {
    return name;
  }
  return '$name - $no';
}

/// Ime PDF datoteke: „[naručioc] - broj_računa.pdf” (npr. „ITX - 6_26.pdf”).
String invoicePdfFileName(StoredInvoice invoice) {
  final name = _sanitizePdfFileNameSegment(_displayRecipientName(invoice));
  final noPart = _sanitizePdfFileNameSegment(
    invoice.invoiceNumber.trim().replaceAll('/', '_'),
  );
  return '$name - $noPart.pdf';
}

String _pdfClientName(StoredInvoice invoice) => _displayRecipientName(invoice);

List<String> _pdfClientAddressLines(StoredInvoice invoice) {
  final a = invoice.recipientAddress.trim();
  if (a.isNotEmpty) {
    return a
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return [
    InvoiceStaticContent.clientCityLine,
    InvoiceStaticContent.clientStreet,
  ];
}

String _pdfClientJibLine(StoredInvoice invoice) {
  final j = invoice.recipientJib.trim();
  if (j.isNotEmpty) {
    final lower = j.toLowerCase();
    if (lower.contains('jib')) {
      return j;
    }
    return 'JIB: $j';
  }
  return InvoiceStaticContent.clientTaxId;
}

String _formatKm(double amount) {
  final fixed = amount.toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed.substring(0, dot);
  final frac = fixed.substring(dot + 1);
  return '$whole,$frac KM';
}

Future<pw.Font> _loadSerifRegular() async {
  final data = await rootBundle.load('assets/fonts/NotoSerif-Regular.ttf');
  return pw.Font.ttf(data);
}

Future<pw.Font> _loadSerifBold() async {
  final data = await rootBundle.load('assets/fonts/NotoSerif-Bold.ttf');
  return pw.Font.ttf(data);
}

/// Builds the invoice PDF with embedded Noto Serif (full Latin/BCS coverage).
Future<Uint8List> buildInvoicePdfBytes(StoredInvoice invoice) async {
  final regular = await _loadSerifRegular();
  final bold = await _loadSerifBold();

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  pw.TextStyle ts({double size = 10, bool boldFont = false}) =>
      pw.TextStyle(font: boldFont ? bold : regular, fontSize: size);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      textDirection: pw.TextDirection.ltr,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.DefaultTextStyle(
                    style: ts(),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(InvoiceStaticContent.providerTitle),
                        pw.SizedBox(height: 4),
                        pw.Text(InvoiceStaticContent.providerName),
                        pw.Text(InvoiceStaticContent.providerAddressLine),
                        pw.Text(InvoiceStaticContent.providerTaxId),
                        pw.Text(InvoiceStaticContent.providerBankAccount),
                        pw.Text(InvoiceStaticContent.providerBankName),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.DefaultTextStyle(
                    style: ts(),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          InvoiceStaticContent.clientLabel,
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Table(
                          tableWidth: pw.TableWidth.min,
                          border: const pw.TableBorder(
                            left: pw.BorderSide(width: 0.8),
                            right: pw.BorderSide(width: 0.8),
                          ),
                          columnWidths: const {
                            0: pw.IntrinsicColumnWidth(),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: pw.Column(
                                    mainAxisSize: pw.MainAxisSize.min,
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.center,
                                    children: [
                                      pw.Text(
                                        _pdfClientName(invoice),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                      ..._pdfClientAddressLines(invoice).map(
                                        (line) => pw.Text(
                                          line,
                                          textAlign: pw.TextAlign.center,
                                        ),
                                      ),
                                      pw.Text(
                                        _pdfClientJibLine(invoice),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.SizedBox(
              width: double.infinity,
              child: pw.Text(
                'RAČUN BR. ${invoice.invoiceNumber}',
                textAlign: pw.TextAlign.center,
                style: ts(size: 18, boldFont: true),
              ),
            ),
            pw.SizedBox(height: 48),
            pw.Table(
              border: pw.TableBorder.all(width: 0.6),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(2.2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.1),
              },
              children: [
                pw.TableRow(
                  verticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: [
                    _cell('R.B.', ts, boldFont: true),
                    _cell('Datum računa', ts, boldFont: true),
                    _cell('Putna relacija', ts, boldFont: true),
                    _cell('Br. Narudžbe', ts, boldFont: true),
                    _cell('Iznos', ts, boldFont: true),
                  ],
                ),
                for (var i = 0; i < invoice.lines.length; i++)
                  pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      _cell('${i + 1}.', ts),
                      _cell(
                        _issueDateFmt.format(invoice.lines[i].datumRacuna),
                        ts,
                      ),
                      _cell(
                        invoice.lines[i].putnaRelacija,
                        ts,
                        align: pw.TextAlign.left,
                      ),
                      _cell(invoice.lines[i].brojNarudzbe, ts),
                      _cell(_formatKm(invoice.lines[i].iznosKm), ts),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 48),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'UKUPNO ZA PLATITI: ${_formatKm(invoice.totalKm)}',
                style: ts(size: 14, boldFont: true),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(InvoiceStaticContent.vatNote, style: ts()),
            ),
            // Fill remaining page height so the footer sits at the bottom of the sheet.
            pw.Spacer(),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Datum izdavanja računa:',
                        style: ts(boldFont: true),
                      ),
                      pw.Text(
                        _issueDateFmt.format(invoice.issueDate),
                        style: ts(),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Text(
                      InvoiceStaticContent.stampPlaceholder,
                      style: ts(boldFont: true),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(InvoiceStaticContent.footerName, style: ts()),
                      pw.Text(InvoiceStaticContent.footerPhone, style: ts()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _cell(
  String text,
  pw.TextStyle Function({double size, bool boldFont}) ts, {
  bool boldFont = false,
  pw.TextAlign align = pw.TextAlign.center,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: pw.Text(
      text,
      textAlign: align,
      style: ts(boldFont: boldFont),
    ),
  );
}
