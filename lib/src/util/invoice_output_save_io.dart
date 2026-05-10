import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Writes [bytes] as [fileName] inside [directoryPath].
///
/// If the file already exists, asks whether to replace it. Returns the full
/// path on success, or `null` if the user cancelled or an error occurred.
Future<String?> saveInvoicePdfToOutputDirectory({
  required BuildContext context,
  required String directoryPath,
  required Uint8List bytes,
  required String fileName,
}) async {
  final trimmed = directoryPath.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final fullPath = p.join(trimmed, fileName);
  final file = File(fullPath);

  try {
    if (await file.exists()) {
      if (!context.mounted) {
        return null;
      }
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PDF već postoji'),
          content: Text(
            'Datoteka „$fileName” već postoji u folderu za račune. '
            'Zamijeniti je novom verzijom? Postojeća datoteka će biti '
            'prepisana.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Da, zamijeni'),
            ),
          ],
        ),
      );
      if (replace != true) {
        return null;
      }
    }

    await file.writeAsBytes(bytes);
    return fullPath;
  } catch (e) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Greška pri čuvanju'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('U redu'),
            ),
          ],
        ),
      );
    }
    return null;
  }
}
