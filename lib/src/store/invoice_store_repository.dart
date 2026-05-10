import 'dart:io';

import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:path_provider/path_provider.dart';

/// File-backed persistence for [StoreSnapshot].
final class InvoiceStoreRepository {
  static const String fileName = 'taxi_invoice_store.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<StoreSnapshot> loadOrCreate() async {
    final file = await _file();
    if (!file.existsSync()) {
      return StoreSnapshot.empty();
    }
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return StoreSnapshot.empty();
      }
      return storeSnapshotFromJsonString(raw);
    } on FormatException {
      return StoreSnapshot.empty();
    }
  }

  Future<void> save(StoreSnapshot snapshot) async {
    final file = await _file();
    await file.writeAsString(storeSnapshotToJsonString(snapshot));
  }

  /// Full store JSON string (for export).
  Future<String> readRaw() async {
    final file = await _file();
    if (!file.existsSync()) {
      return storeSnapshotToJsonString(StoreSnapshot.empty());
    }
    return file.readAsString();
  }

  /// Replace store from exported JSON.
  Future<void> writeRaw(String json) async {
    storeSnapshotFromJsonString(json);
    final file = await _file();
    await file.writeAsString(json);
  }
}
