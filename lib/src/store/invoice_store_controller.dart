import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_repository.dart';
import 'package:flutter/foundation.dart';

/// In-memory store + persistence for invoices and suggestion dictionaries.
final class InvoiceStoreController extends ChangeNotifier {
  InvoiceStoreController({InvoiceStoreRepository? repository})
    : _repository = repository ?? InvoiceStoreRepository();

  final InvoiceStoreRepository _repository;

  StoreSnapshot _snapshot = StoreSnapshot.empty();
  bool _loaded = false;

  StoreSnapshot get snapshot => _snapshot;
  bool get isLoaded => _loaded;

  List<StoredInvoice> get invoicesSortedByIssueDate {
    final list = List<StoredInvoice>.from(_snapshot.invoices);
    list.sort((a, b) {
      final c = b.issueDate.compareTo(a.issueDate);
      if (c != 0) {
        return c;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<String> get cities => _snapshot.cities;
  List<String> get orderNames => _snapshot.orderNames;
  List<ServiceRecipient> get serviceRecipientsSorted {
    final list = List<ServiceRecipient>.from(_snapshot.serviceRecipients);
    list.sort((a, b) {
      final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (c != 0) {
        return c;
      }
      return a.id.compareTo(b.id);
    });
    return list;
  }

  ServiceRecipient? recipientById(String id) {
    for (final r in _snapshot.serviceRecipients) {
      if (r.id == id) {
        return r;
      }
    }
    return null;
  }

  Future<void> load() async {
    _snapshot = await _repository.loadOrCreate();
    if (_snapshot.version < StoreSnapshot.currentVersion) {
      _snapshot = _snapshot.copyWith(version: StoreSnapshot.currentVersion);
      await _persist();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() => _repository.save(_snapshot);

  Future<void> upsertInvoice(StoredInvoice invoice) async {
    final others = _snapshot.invoices.where((e) => e.id != invoice.id).toList();
    _snapshot = _snapshot.copyWith(invoices: [...others, invoice]);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteInvoice(String id) async {
    _snapshot = _snapshot.copyWith(
      invoices: _snapshot.invoices.where((e) => e.id != id).toList(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> rememberCity(String city) async {
    final t = city.trim();
    if (t.isEmpty) {
      return;
    }
    if (_snapshot.cities.any((e) => e.toLowerCase() == t.toLowerCase())) {
      return;
    }
    _snapshot = StoreSnapshot(
      version: _snapshot.version,
      cities: [..._snapshot.cities, t],
      orderNames: _snapshot.orderNames,
      serviceRecipients: _snapshot.serviceRecipients,
      invoices: _snapshot.invoices,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> rememberOrderName(String name) async {
    final t = name.trim();
    if (t.isEmpty) {
      return;
    }
    if (_snapshot.orderNames.any((e) => e.toLowerCase() == t.toLowerCase())) {
      return;
    }
    _snapshot = StoreSnapshot(
      version: _snapshot.version,
      cities: _snapshot.cities,
      orderNames: [..._snapshot.orderNames, t],
      serviceRecipients: _snapshot.serviceRecipients,
      invoices: _snapshot.invoices,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> upsertServiceRecipient(ServiceRecipient recipient) async {
    final others = _snapshot.serviceRecipients
        .where((e) => e.id != recipient.id)
        .toList();
    _snapshot = _snapshot.copyWith(serviceRecipients: [...others, recipient]);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteServiceRecipient(String id) async {
    _snapshot = _snapshot.copyWith(
      serviceRecipients: _snapshot.serviceRecipients
          .where((e) => e.id != id)
          .toList(),
    );
    await _persist();
    notifyListeners();
  }

  /// Merges imported snapshot: union cities/names, invoices by id (import wins on conflict).
  Future<void> importMerge(StoreSnapshot incoming) async {
    final citySet = {..._snapshot.cities, ...incoming.cities};
    final nameSet = {..._snapshot.orderNames, ...incoming.orderNames};
    final recipById = {for (final r in _snapshot.serviceRecipients) r.id: r};
    for (final r in incoming.serviceRecipients) {
      recipById[r.id] = r;
    }
    final byId = {for (final inv in _snapshot.invoices) inv.id: inv};
    for (final inv in incoming.invoices) {
      byId[inv.id] = inv;
    }
    _snapshot = StoreSnapshot(
      version: StoreSnapshot.currentVersion,
      cities: citySet.toList(),
      orderNames: nameSet.toList(),
      serviceRecipients: recipById.values.toList(),
      invoices: byId.values.toList(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> replaceAllFromExport(StoreSnapshot incoming) async {
    _snapshot = StoreSnapshot(
      version: StoreSnapshot.currentVersion,
      cities: incoming.cities,
      orderNames: incoming.orderNames,
      serviceRecipients: incoming.serviceRecipients,
      invoices: incoming.invoices,
    );
    await _persist();
    notifyListeners();
  }

  Future<String> exportJsonString() async =>
      storeSnapshotToJsonString(_snapshot);

  Future<void> importRawReplace(String json) async {
    final parsed = storeSnapshotFromJsonString(json);
    await replaceAllFromExport(parsed);
  }

  /// Sprema apsolutnu putanju zadnjeg uspješnog PDF čuvanja za račun.
  Future<void> setInvoiceSavedPdfPath(String invoiceId, String path) async {
    final list = _snapshot.invoices;
    final idx = list.indexWhere((e) => e.id == invoiceId);
    if (idx < 0) {
      return;
    }
    final updated = list[idx].copyWith(savedPdfPath: path);
    final others = list.where((e) => e.id != invoiceId).toList();
    _snapshot = _snapshot.copyWith(invoices: [...others, updated]);
    await _persist();
    notifyListeners();
  }
}
