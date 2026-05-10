import 'dart:convert';

/// One saved „naručilac usluga” entry (name, address, JIB).
final class ServiceRecipient {
  const ServiceRecipient({
    required this.id,
    required this.name,
    required this.address,
    required this.jib,
  });

  final String id;
  final String name;
  final String address;
  final String jib;

  factory ServiceRecipient.fromJson(Map<String, dynamic> json) {
    return ServiceRecipient(
      id: json['id'] as String,
      name: (json['name'] as String? ?? '').trim(),
      address: (json['address'] as String? ?? '').trim(),
      jib: (json['jib'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'jib': jib,
  };

  ServiceRecipient copyWith({
    String? id,
    String? name,
    String? address,
    String? jib,
  }) => ServiceRecipient(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    jib: jib ?? this.jib,
  );
}

/// Persisted JSON root (`taxi_invoice_store.json`).
final class StoreSnapshot {
  StoreSnapshot({
    required this.version,
    required List<String> cities,
    required List<String> orderNames,
    required List<ServiceRecipient> serviceRecipients,
    required List<StoredInvoice> invoices,
  }) : cities = List.unmodifiable(_dedupeSorted(cities)),
       orderNames = List.unmodifiable(_dedupeSorted(orderNames)),
       serviceRecipients = List.unmodifiable(serviceRecipients),
       invoices = List.unmodifiable(invoices);

  static const int currentVersion = 2;

  final int version;
  final List<String> cities;
  final List<String> orderNames;
  final List<ServiceRecipient> serviceRecipients;
  final List<StoredInvoice> invoices;

  factory StoreSnapshot.empty() => StoreSnapshot(
    version: currentVersion,
    cities: [],
    orderNames: [],
    serviceRecipients: [],
    invoices: [],
  );

  factory StoreSnapshot.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    final cities = (json['cities'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final orderNames = (json['orderNames'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final serviceRecipients =
        (json['serviceRecipients'] as List<dynamic>? ?? [])
            .map((e) => ServiceRecipient.fromJson(e as Map<String, dynamic>))
            .toList();
    final invoices = (json['invoices'] as List<dynamic>? ?? [])
        .map((e) => StoredInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
    return StoreSnapshot(
      version: version,
      cities: cities,
      orderNames: orderNames,
      serviceRecipients: serviceRecipients,
      invoices: invoices,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'cities': cities,
    'orderNames': orderNames,
    'serviceRecipients': serviceRecipients.map((e) => e.toJson()).toList(),
    'invoices': invoices.map((e) => e.toJson()).toList(),
  };

  StoreSnapshot copyWith({
    int? version,
    List<String>? cities,
    List<String>? orderNames,
    List<ServiceRecipient>? serviceRecipients,
    List<StoredInvoice>? invoices,
  }) => StoreSnapshot(
    version: version ?? this.version,
    cities: cities ?? this.cities,
    orderNames: orderNames ?? this.orderNames,
    serviceRecipients: serviceRecipients ?? this.serviceRecipients,
    invoices: invoices ?? this.invoices,
  );

  static List<String> _dedupeSorted(List<String> input) {
    final set = <String>{};
    for (final s in input) {
      final t = s.trim();
      if (t.isEmpty) {
        continue;
      }
      set.add(t);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}

String storeSnapshotToJsonString(StoreSnapshot snapshot) =>
    const JsonEncoder.withIndent('  ').convert(snapshot.toJson());

StoreSnapshot storeSnapshotFromJsonString(String raw) =>
    StoreSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);

final class StoredInvoice {
  StoredInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.createdAt,
    required List<InvoiceLine> lines,
    this.recipientId,
    this.recipientName = '',
    this.recipientAddress = '',
    this.recipientJib = '',
    this.savedPdfPath,
  }) : lines = List.unmodifiable(lines);

  final String id;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime createdAt;
  final List<InvoiceLine> lines;

  /// Optional link to [ServiceRecipient.id] used when filling the form; PDF uses
  /// denormalized [recipientName] / [recipientAddress] / [recipientJib].
  final String? recipientId;
  final String recipientName;
  final String recipientAddress;
  final String recipientJib;

  /// Absolute path from the last successful „Sačuvaj PDF kao…” (platform-specific).
  final String? savedPdfPath;

  factory StoredInvoice.fromJson(Map<String, dynamic> json) {
    return StoredInvoice(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      issueDate: DateTime.parse(json['issueDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lines: (json['lines'] as List<dynamic>)
          .map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      recipientId: json['recipientId'] as String?,
      recipientName: json['recipientName'] as String? ?? '',
      recipientAddress: json['recipientAddress'] as String? ?? '',
      recipientJib: json['recipientJib'] as String? ?? '',
      savedPdfPath: json['savedPdfPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNumber': invoiceNumber,
    'issueDate': issueDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'lines': lines.map((e) => e.toJson()).toList(),
    if (recipientId != null) 'recipientId': recipientId,
    if (recipientName.isNotEmpty) 'recipientName': recipientName,
    if (recipientAddress.isNotEmpty) 'recipientAddress': recipientAddress,
    if (recipientJib.isNotEmpty) 'recipientJib': recipientJib,
    if (savedPdfPath != null) 'savedPdfPath': savedPdfPath,
  };

  StoredInvoice copyWith({
    String? id,
    String? invoiceNumber,
    DateTime? issueDate,
    DateTime? createdAt,
    List<InvoiceLine>? lines,
    String? recipientId,
    String? recipientName,
    String? recipientAddress,
    String? recipientJib,
    String? savedPdfPath,
    bool clearSavedPdfPath = false,
    bool clearRecipientId = false,
  }) {
    return StoredInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      issueDate: issueDate ?? this.issueDate,
      createdAt: createdAt ?? this.createdAt,
      lines: lines ?? this.lines,
      recipientId: clearRecipientId ? null : (recipientId ?? this.recipientId),
      recipientName: recipientName ?? this.recipientName,
      recipientAddress: recipientAddress ?? this.recipientAddress,
      recipientJib: recipientJib ?? this.recipientJib,
      savedPdfPath: clearSavedPdfPath
          ? null
          : (savedPdfPath ?? this.savedPdfPath),
    );
  }

  double get totalKm =>
      lines.fold<double>(0, (sum, line) => sum + line.iznosKm);
}

final class InvoiceLine {
  InvoiceLine({
    required this.datumRacuna,
    required this.putnaRelacija,
    required this.brojNarudzbe,
    required this.iznosKm,
  });

  final DateTime datumRacuna;
  final String putnaRelacija;
  final String brojNarudzbe;
  final double iznosKm;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    return InvoiceLine(
      datumRacuna: DateTime.parse(json['datumRacuna'] as String),
      putnaRelacija: json['putnaRelacija'] as String,
      brojNarudzbe: json['brojNarudzbe'] as String,
      iznosKm: (json['iznosKm'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'datumRacuna': datumRacuna.toIso8601String(),
    'putnaRelacija': putnaRelacija,
    'brojNarudzbe': brojNarudzbe,
    'iznosKm': iznosKm,
  };
}
