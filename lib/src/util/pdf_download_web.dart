import 'dart:typed_data';

import 'package:app_taxi_invoice/src/util/file_download_web.dart';

Future<void> downloadPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  await downloadFileBytes(
    bytes: bytes,
    fileName: fileName,
    mimeType: 'application/pdf',
    description: 'PDF',
    extensions: const ['.pdf'],
  );
}
