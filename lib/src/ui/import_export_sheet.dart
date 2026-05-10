import 'dart:io';

import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> showImportExportSheet(
  BuildContext context,
  InvoiceStoreController store,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Izvoz JSON (cijeli store)'),
              subtitle: const Text(
                'Računi, naručioci usluga, gradovi i imena narudžbi.',
              ),
              leading: const Icon(Icons.ios_share),
              onTap: () async {
                final json = await store.exportJsonString();
                if (!ctx.mounted) {
                  return;
                }
                await SharePlus.instance.share(
                  ShareParams(text: json, subject: 'taxi_invoice_store.json'),
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
            ),
            ListTile(
              title: const Text('Uvoz JSON (spajanje po ID)'),
              subtitle: const Text(
                'Gradovi, imena i računi se spajaju; isti ID se zamijeni.',
              ),
              leading: const Icon(Icons.merge_type),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );
                if (result == null || result.files.isEmpty) {
                  return;
                }
                final path = result.files.single.path;
                if (path == null) {
                  return;
                }
                final raw = await File(path).readAsString();
                final snap = storeSnapshotFromJsonString(raw);
                await store.importMerge(snap);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Uvoz završen (merge).')),
                  );
                }
              },
            ),
            ListTile(
              title: const Text('Uvoz JSON (zamijeni sve)'),
              subtitle: const Text('Briše postojeći store u aplikaciji.'),
              leading: const Icon(Icons.warning_amber),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (dctx) => AlertDialog(
                    title: const Text('Zamijeniti sav lokalni store?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: const Text('Odustani'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text('Zamijeni'),
                      ),
                    ],
                  ),
                );
                if (ok != true) {
                  return;
                }
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );
                if (result == null || result.files.isEmpty) {
                  return;
                }
                final path = result.files.single.path;
                if (path == null) {
                  return;
                }
                final raw = await File(path).readAsString();
                await store.importRawReplace(raw);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store zamijenjen.')),
                  );
                }
              },
            ),
          ],
        ),
      );
    },
  );
}
