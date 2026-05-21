import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;

  web.window.document.body?.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
}
