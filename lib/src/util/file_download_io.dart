import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> downloadFileBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required String description,
  required List<String> extensions,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
      subject: fileName,
    ),
  );
}
