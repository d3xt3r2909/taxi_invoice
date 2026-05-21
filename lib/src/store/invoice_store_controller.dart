import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_repository.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter/foundation.dart';

final class InvoiceStoreMutationException implements Exception {
  const InvoiceStoreMutationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// In-memory store + persistence for invoices and suggestion dictionaries.
final class InvoiceStoreController extends ChangeNotifier {
  InvoiceStoreController({InvoiceStoreRepository? repository})
    : _repository = repository ?? InvoiceStoreRepository();

  final InvoiceStoreRepository _repository;

  StoreSnapshot _snapshot = StoreSnapshot.empty();
  bool _loaded = false;

  StoreSnapshot get snapshot => _snapshot;
  bool get isLoaded => _loaded;
  InvoiceStoreSyncStatus get syncStatus => _repository.syncStatus;
  String? get syncMessage => _repository.syncMessage;
  bool get canWrite => _loaded && _repository.canWrite;
  bool get isReadOnly => _loaded && !canWrite;

  String get readOnlyMessage {
    return _repository.syncMessage ??
        'Podaci su otvoreni samo za pregled dok cloud sync nije dostupan.';
  }

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

  ServiceRecipient? matchingServiceRecipient({
    required String name,
    String address = '',
    String jib = '',
  }) {
    final normalizedName = _normalizeRecipientField(name);
    final normalizedAddress = _normalizeRecipientField(address);
    final normalizedJib = _normalizeRecipientField(jib);
    for (final recipient in _snapshot.serviceRecipients) {
      if (_normalizeRecipientField(recipient.name) == normalizedName &&
          _normalizeRecipientField(recipient.address) == normalizedAddress &&
          _normalizeRecipientField(recipient.jib) == normalizedJib) {
        return recipient;
      }
    }
    return null;
  }

  Future<void> load() async {
    _snapshot = await _repository.loadOrCreate();
    if (_snapshot.version < StoreSnapshot.currentVersion) {
      _snapshot = _snapshot.copyWith(version: StoreSnapshot.currentVersion);
      if (_repository.canWrite) {
        await _persist();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() => _repository.save(_snapshot);

  void reset() {
    _snapshot = StoreSnapshot.empty();
    _loaded = false;
    notifyListeners();
  }

  void _ensureWritable() {
    if (!canWrite) {
      throw InvoiceStoreMutationException(readOnlyMessage);
    }
  }

  Future<void> _replaceSnapshot(StoreSnapshot next) async {
    _ensureWritable();
    final previous = _snapshot;
    _snapshot = next;
    try {
      await _persist();
    } on InvoiceStoreTextStorageException catch (e) {
      _snapshot = previous;
      notifyListeners();
      throw InvoiceStoreMutationException(e.message);
    } catch (_) {
      _snapshot = previous;
      notifyListeners();
      throw const InvoiceStoreMutationException(
        'Podaci nisu sačuvani. Pokušajte ponovo.',
      );
    }
    notifyListeners();
  }

  Future<void> upsertInvoice(StoredInvoice invoice) async {
    final others = _snapshot.invoices.where((e) => e.id != invoice.id).toList();
    await _replaceSnapshot(_snapshot.copyWith(invoices: [...others, invoice]));
  }

  Future<void> upsertInvoiceWithSuggestions(
    StoredInvoice invoice, {
    Iterable<String> cities = const [],
    Iterable<String> orderNames = const [],
    ServiceRecipient? serviceRecipient,
  }) async {
    final citySet = {..._snapshot.cities};
    for (final city in cities) {
      final t = city.trim();
      if (t.isNotEmpty &&
          !citySet.any((e) => e.toLowerCase() == t.toLowerCase())) {
        citySet.add(t);
      }
    }
    final nameSet = {..._snapshot.orderNames};
    for (final name in orderNames) {
      final t = name.trim();
      if (t.isNotEmpty &&
          !nameSet.any((e) => e.toLowerCase() == t.toLowerCase())) {
        nameSet.add(t);
      }
    }
    final others = _snapshot.invoices.where((e) => e.id != invoice.id).toList();
    final serviceRecipients = serviceRecipient == null
        ? _snapshot.serviceRecipients
        : [
            ..._snapshot.serviceRecipients.where(
              (e) => e.id != serviceRecipient.id,
            ),
            serviceRecipient,
          ];
    await _replaceSnapshot(
      StoreSnapshot(
        version: _snapshot.version,
        cities: citySet.toList(),
        orderNames: nameSet.toList(),
        serviceRecipients: serviceRecipients,
        invoices: [...others, invoice],
      ),
    );
  }

  Future<void> deleteInvoice(String id) async {
    await _replaceSnapshot(
      _snapshot.copyWith(
        invoices: _snapshot.invoices.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<void> rememberCity(String city) async {
    final t = city.trim();
    if (t.isEmpty) {
      return;
    }
    if (_snapshot.cities.any((e) => e.toLowerCase() == t.toLowerCase())) {
      return;
    }
    await _replaceSnapshot(
      StoreSnapshot(
        version: _snapshot.version,
        cities: [..._snapshot.cities, t],
        orderNames: _snapshot.orderNames,
        serviceRecipients: _snapshot.serviceRecipients,
        invoices: _snapshot.invoices,
      ),
    );
  }

  Future<void> rememberOrderName(String name) async {
    final t = name.trim();
    if (t.isEmpty) {
      return;
    }
    if (_snapshot.orderNames.any((e) => e.toLowerCase() == t.toLowerCase())) {
      return;
    }
    await _replaceSnapshot(
      StoreSnapshot(
        version: _snapshot.version,
        cities: _snapshot.cities,
        orderNames: [..._snapshot.orderNames, t],
        serviceRecipients: _snapshot.serviceRecipients,
        invoices: _snapshot.invoices,
      ),
    );
  }

  Future<void> upsertServiceRecipient(ServiceRecipient recipient) async {
    final others = _snapshot.serviceRecipients
        .where((e) => e.id != recipient.id)
        .toList();
    await _replaceSnapshot(
      _snapshot.copyWith(serviceRecipients: [...others, recipient]),
    );
  }

  Future<void> deleteServiceRecipient(String id) async {
    await _replaceSnapshot(
      _snapshot.copyWith(
        serviceRecipients: _snapshot.serviceRecipients
            .where((e) => e.id != id)
            .toList(),
      ),
    );
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
    await _replaceSnapshot(
      StoreSnapshot(
        version: StoreSnapshot.currentVersion,
        cities: citySet.toList(),
        orderNames: nameSet.toList(),
        serviceRecipients: recipById.values.toList(),
        invoices: byId.values.toList(),
      ),
    );
  }

  Future<void> replaceAllFromExport(StoreSnapshot incoming) async {
    await _replaceSnapshot(
      StoreSnapshot(
        version: StoreSnapshot.currentVersion,
        cities: incoming.cities,
        orderNames: incoming.orderNames,
        serviceRecipients: incoming.serviceRecipients,
        invoices: incoming.invoices,
      ),
    );
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
    await _replaceSnapshot(_snapshot.copyWith(invoices: [...others, updated]));
  }
}

String _normalizeRecipientField(String value) {
  return value.trim().toLowerCase();
}
