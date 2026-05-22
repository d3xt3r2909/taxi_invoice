import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_repository.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_text_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class InvoiceStoreMutationException implements Exception {
  const InvoiceStoreMutationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// In-memory store + persistence for invoices and suggestion dictionaries.
final class InvoiceStoreController extends ChangeNotifier {
  InvoiceStoreController({
    InvoiceStoreRepository? repository,
    LocalOnlyInvoiceStorage? localOnlyStorage,
  }) : _repository = repository ?? InvoiceStoreRepository(),
       _localOnlyStorage =
           localOnlyStorage ?? const SharedPreferencesLocalOnlyInvoiceStorage();

  final InvoiceStoreRepository _repository;
  final LocalOnlyInvoiceStorage _localOnlyStorage;

  StoreSnapshot _snapshot = StoreSnapshot.empty();
  StoreSnapshot _localOnlySnapshot = StoreSnapshot.empty();
  bool _loaded = false;
  bool _saving = false;

  StoreSnapshot get snapshot => _snapshot;
  StoreSnapshot get localOnlySnapshot => _localOnlySnapshot;
  bool get isLoaded => _loaded;
  bool get isSaving => _saving;
  InvoiceStoreSyncStatus get syncStatus => _repository.syncStatus;
  String? get syncMessage => _repository.syncMessage;
  bool get canWrite => _loaded && _repository.canWrite;
  bool get isReadOnly => _loaded && !canWrite;

  String get readOnlyMessage {
    return _repository.syncMessage ??
        'Podaci su otvoreni samo za pregled dok cloud sync nije dostupan.';
  }

  List<StoredInvoice> get invoicesSortedByIssueDate {
    final byId = {
      for (final invoice in _snapshot.invoices) invoice.id: invoice,
      for (final invoice in _localOnlySnapshot.invoices) invoice.id: invoice,
    };
    final list = byId.values.toList();
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

  bool hasInvoiceNumber(String invoiceNumber, {String? exceptInvoiceId}) {
    return _hasInvoiceNumberIn(
      [..._snapshot.invoices, ..._localOnlySnapshot.invoices],
      invoiceNumber,
      exceptInvoiceId: exceptInvoiceId,
    );
  }

  bool hasOnlineInvoiceNumber(String invoiceNumber, {String? exceptInvoiceId}) {
    return _hasInvoiceNumberIn(
      _snapshot.invoices,
      invoiceNumber,
      exceptInvoiceId: exceptInvoiceId,
    );
  }

  bool hasInvoiceNumberForRecipient(
    String invoiceNumber, {
    required String recipientName,
    String? exceptInvoiceId,
  }) {
    return _hasInvoiceNumberForRecipientIn(
      [..._snapshot.invoices, ..._localOnlySnapshot.invoices],
      invoiceNumber,
      recipientName: recipientName,
      exceptInvoiceId: exceptInvoiceId,
    );
  }

  bool hasOnlineInvoiceNumberForRecipient(
    String invoiceNumber, {
    required String recipientName,
    String? exceptInvoiceId,
  }) {
    return _hasInvoiceNumberForRecipientIn(
      _snapshot.invoices,
      invoiceNumber,
      recipientName: recipientName,
      exceptInvoiceId: exceptInvoiceId,
    );
  }

  bool isInvoiceStoredOnline(String id) {
    return !_localOnlySnapshot.invoices.any((invoice) => invoice.id == id);
  }

  StoredInvoice? invoiceById(String id) {
    for (final invoice in _snapshot.invoices) {
      if (invoice.id == id) {
        return invoice;
      }
    }
    for (final invoice in _localOnlySnapshot.invoices) {
      if (invoice.id == id) {
        return invoice;
      }
    }
    return null;
  }

  bool _hasInvoiceNumberIn(
    List<StoredInvoice> invoices,
    String invoiceNumber, {
    String? exceptInvoiceId,
  }) {
    final normalized = invoiceNumber.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return invoices.any((invoice) {
      return invoice.id != exceptInvoiceId &&
          invoice.invoiceNumber.trim().toLowerCase() == normalized;
    });
  }

  bool _hasInvoiceNumberForRecipientIn(
    List<StoredInvoice> invoices,
    String invoiceNumber, {
    required String recipientName,
    String? exceptInvoiceId,
  }) {
    final normalizedNumber = invoiceNumber.trim().toLowerCase();
    final normalizedRecipient = _normalizeRecipientField(recipientName);
    if (normalizedNumber.isEmpty || normalizedRecipient.isEmpty) {
      return false;
    }
    return invoices.any((invoice) {
      return invoice.id != exceptInvoiceId &&
          invoice.invoiceNumber.trim().toLowerCase() == normalizedNumber &&
          _normalizeRecipientField(invoice.recipientName) ==
              normalizedRecipient;
    });
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
    _localOnlySnapshot = await _localOnlyStorage.read();
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
    _localOnlySnapshot = StoreSnapshot.empty();
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
    _saving = true;
    notifyListeners();
    try {
      await _persist();
    } on InvoiceStoreTextStorageException catch (e) {
      _snapshot = previous;
      throw InvoiceStoreMutationException(e.message);
    } catch (_) {
      _snapshot = previous;
      throw const InvoiceStoreMutationException(
        'Podaci nisu sačuvani. Pokušajte ponovo.',
      );
    } finally {
      _saving = false;
      notifyListeners();
    }
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

  Future<void> upsertLocalOnlyInvoice(StoredInvoice invoice) async {
    final others = _localOnlySnapshot.invoices
        .where((e) => e.id != invoice.id)
        .toList();
    _localOnlySnapshot = _localOnlySnapshot.copyWith(
      invoices: [...others, invoice],
    );
    await _persistLocalOnly();
    notifyListeners();
  }

  Future<void> publishLocalOnlyInvoice(String id) async {
    StoredInvoice? invoice;
    for (final candidate in _localOnlySnapshot.invoices) {
      if (candidate.id == id) {
        invoice = candidate;
        break;
      }
    }
    if (invoice == null) {
      return;
    }
    final cities = invoice.lines.expand((line) {
      return line.putnaRelacija
          .split(RegExp(r'[-,;/]+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty);
    });
    final recipientToRemember = _recipientForPublishedInvoice(invoice);
    await upsertInvoiceWithSuggestions(
      invoice,
      cities: cities,
      orderNames: invoice.lines.map((line) => line.brojNarudzbe),
      serviceRecipient: recipientToRemember,
    );
    _localOnlySnapshot = _localOnlySnapshot.copyWith(
      invoices: _localOnlySnapshot.invoices
          .where((candidate) => candidate.id != id)
          .toList(),
    );
    await _persistLocalOnly();
    notifyListeners();
  }

  Future<void> deleteInvoice(String id) async {
    if (!isInvoiceStoredOnline(id)) {
      _localOnlySnapshot = _localOnlySnapshot.copyWith(
        invoices: _localOnlySnapshot.invoices.where((e) => e.id != id).toList(),
      );
      await _persistLocalOnly();
      notifyListeners();
      return;
    }
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

  Future<void> clearAllData() async {
    await _replaceSnapshot(StoreSnapshot.empty());
    _localOnlySnapshot = StoreSnapshot.empty();
    await _persistLocalOnly();
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
    if (!isInvoiceStoredOnline(invoiceId)) {
      final idx = _localOnlySnapshot.invoices.indexWhere(
        (e) => e.id == invoiceId,
      );
      if (idx < 0) {
        return;
      }
      final updated = _localOnlySnapshot.invoices[idx].copyWith(
        savedPdfPath: path,
      );
      final others = _localOnlySnapshot.invoices
          .where((e) => e.id != invoiceId)
          .toList();
      _localOnlySnapshot = _localOnlySnapshot.copyWith(
        invoices: [...others, updated],
      );
      await _persistLocalOnly();
      notifyListeners();
      return;
    }
    final list = _snapshot.invoices;
    final idx = list.indexWhere((e) => e.id == invoiceId);
    if (idx < 0) {
      return;
    }
    final updated = list[idx].copyWith(savedPdfPath: path);
    final others = list.where((e) => e.id != invoiceId).toList();
    await _replaceSnapshot(_snapshot.copyWith(invoices: [...others, updated]));
  }

  Future<void> _persistLocalOnly() {
    return _localOnlyStorage.write(_localOnlySnapshot);
  }

  ServiceRecipient? _recipientForPublishedInvoice(StoredInvoice invoice) {
    final name = invoice.recipientName.trim();
    if (name.isEmpty) {
      return null;
    }
    return matchingServiceRecipient(
          name: name,
          address: invoice.recipientAddress,
          jib: invoice.recipientJib,
        ) ??
        ServiceRecipient(
          id: invoice.recipientId ?? 'recipient-${invoice.id}',
          name: name,
          address: invoice.recipientAddress.trim(),
          jib: invoice.recipientJib.trim(),
        );
  }
}

String _normalizeRecipientField(String value) {
  return value.trim().toLowerCase();
}

abstract interface class LocalOnlyInvoiceStorage {
  Future<StoreSnapshot> read();

  Future<void> write(StoreSnapshot snapshot);
}

final class SharedPreferencesLocalOnlyInvoiceStorage
    implements LocalOnlyInvoiceStorage {
  const SharedPreferencesLocalOnlyInvoiceStorage();

  static const _key = 'taxi_invoice_store:local_only_invoices';

  @override
  Future<StoreSnapshot> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return StoreSnapshot.empty();
    }
    try {
      return storeSnapshotFromJsonString(raw);
    } catch (_) {
      await prefs.remove(_key);
      return StoreSnapshot.empty();
    }
  }

  @override
  Future<void> write(StoreSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, storeSnapshotToJsonString(snapshot));
  }
}
