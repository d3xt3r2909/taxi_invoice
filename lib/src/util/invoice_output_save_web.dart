import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Web: no fixed folder; return null (PDF se dijeli iz pregleda).
Future<String?> saveInvoicePdfToOutputDirectory({
  required BuildContext context,
  required String directoryPath,
  required Uint8List bytes,
  required String fileName,
}) async => null;
