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
    List<InvoiceChatDraft> invoiceChatDrafts = const [],
  }) : cities = List.unmodifiable(_dedupeSorted(cities)),
       orderNames = List.unmodifiable(_dedupeSorted(orderNames)),
       serviceRecipients = List.unmodifiable(serviceRecipients),
       invoices = List.unmodifiable(invoices),
       invoiceChatDrafts = List.unmodifiable(invoiceChatDrafts);

  static const int currentVersion = 2;

  final int version;
  final List<String> cities;
  final List<String> orderNames;
  final List<ServiceRecipient> serviceRecipients;
  final List<StoredInvoice> invoices;
  final List<InvoiceChatDraft> invoiceChatDrafts;

  factory StoreSnapshot.empty() => StoreSnapshot(
    version: currentVersion,
    cities: [],
    orderNames: [],
    serviceRecipients: [],
    invoices: [],
    invoiceChatDrafts: [],
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
    final invoiceChatDrafts =
        (json['invoiceChatDrafts'] as List<dynamic>? ?? [])
            .map((e) => InvoiceChatDraft.fromJson(e as Map<String, dynamic>))
            .toList();
    return StoreSnapshot(
      version: version,
      cities: cities,
      orderNames: orderNames,
      serviceRecipients: serviceRecipients,
      invoices: invoices,
      invoiceChatDrafts: invoiceChatDrafts,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'cities': cities,
    'orderNames': orderNames,
    'serviceRecipients': serviceRecipients.map((e) => e.toJson()).toList(),
    'invoices': invoices.map((e) => e.toJson()).toList(),
    if (invoiceChatDrafts.isNotEmpty)
      'invoiceChatDrafts': invoiceChatDrafts.map((e) => e.toJson()).toList(),
  };

  StoreSnapshot copyWith({
    int? version,
    List<String>? cities,
    List<String>? orderNames,
    List<ServiceRecipient>? serviceRecipients,
    List<StoredInvoice>? invoices,
    List<InvoiceChatDraft>? invoiceChatDrafts,
  }) => StoreSnapshot(
    version: version ?? this.version,
    cities: cities ?? this.cities,
    orderNames: orderNames ?? this.orderNames,
    serviceRecipients: serviceRecipients ?? this.serviceRecipients,
    invoices: invoices ?? this.invoices,
    invoiceChatDrafts: invoiceChatDrafts ?? this.invoiceChatDrafts,
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

enum InvoicePdfLayoutPreset {
  normal,
  compact,
  dense;

  static InvoicePdfLayoutPreset fromJson(Object? raw) {
    final value = raw?.toString().trim();
    for (final preset in InvoicePdfLayoutPreset.values) {
      if (preset.name == value) {
        return preset;
      }
    }
    return InvoicePdfLayoutPreset.normal;
  }
}

final class InvoicePdfFontSettings {
  const InvoicePdfFontSettings({
    required this.providerFontSize,
    required this.recipientFontSize,
    required this.titleFontSize,
    required this.tableFontSize,
    required this.totalFontSize,
    required this.noteFontSize,
    required this.footerFontSize,
  });

  static const double minFontSize = 6;
  static const double maxFontSize = 24;

  final double providerFontSize;
  final double recipientFontSize;
  final double titleFontSize;
  final double tableFontSize;
  final double totalFontSize;
  final double noteFontSize;
  final double footerFontSize;

  factory InvoicePdfFontSettings.defaultsForPreset(
    InvoicePdfLayoutPreset preset,
  ) {
    return switch (preset) {
      InvoicePdfLayoutPreset.normal => const InvoicePdfFontSettings(
        providerFontSize: 10,
        recipientFontSize: 10,
        titleFontSize: 18,
        tableFontSize: 10,
        totalFontSize: 14,
        noteFontSize: 10,
        footerFontSize: 10,
      ),
      InvoicePdfLayoutPreset.compact => const InvoicePdfFontSettings(
        providerFontSize: 9.2,
        recipientFontSize: 9.2,
        titleFontSize: 16.5,
        tableFontSize: 9.2,
        totalFontSize: 12.5,
        noteFontSize: 9.2,
        footerFontSize: 9.2,
      ),
      InvoicePdfLayoutPreset.dense => const InvoicePdfFontSettings(
        providerFontSize: 8.5,
        recipientFontSize: 8.5,
        titleFontSize: 15,
        tableFontSize: 8.5,
        totalFontSize: 11.5,
        noteFontSize: 8.5,
        footerFontSize: 8.5,
      ),
    };
  }

  static InvoicePdfFontSettings? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    const fallback = InvoicePdfFontSettings(
      providerFontSize: 10,
      recipientFontSize: 10,
      titleFontSize: 18,
      tableFontSize: 10,
      totalFontSize: 14,
      noteFontSize: 10,
      footerFontSize: 10,
    );
    return InvoicePdfFontSettings(
      providerFontSize: _fontSizeFromJson(
        raw['providerFontSize'],
        fallback.providerFontSize,
      ),
      recipientFontSize: _fontSizeFromJson(
        raw['recipientFontSize'],
        fallback.recipientFontSize,
      ),
      titleFontSize: _fontSizeFromJson(
        raw['titleFontSize'],
        fallback.titleFontSize,
      ),
      tableFontSize: _fontSizeFromJson(
        raw['tableFontSize'],
        fallback.tableFontSize,
      ),
      totalFontSize: _fontSizeFromJson(
        raw['totalFontSize'],
        fallback.totalFontSize,
      ),
      noteFontSize: _fontSizeFromJson(
        raw['noteFontSize'],
        fallback.noteFontSize,
      ),
      footerFontSize: _fontSizeFromJson(
        raw['footerFontSize'],
        fallback.footerFontSize,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'providerFontSize': providerFontSize,
    'recipientFontSize': recipientFontSize,
    'titleFontSize': titleFontSize,
    'tableFontSize': tableFontSize,
    'totalFontSize': totalFontSize,
    'noteFontSize': noteFontSize,
    'footerFontSize': footerFontSize,
  };

  InvoicePdfFontSettings copyWith({
    double? providerFontSize,
    double? recipientFontSize,
    double? titleFontSize,
    double? tableFontSize,
    double? totalFontSize,
    double? noteFontSize,
    double? footerFontSize,
  }) {
    return InvoicePdfFontSettings(
      providerFontSize: _clampFontSize(
        providerFontSize ?? this.providerFontSize,
      ),
      recipientFontSize: _clampFontSize(
        recipientFontSize ?? this.recipientFontSize,
      ),
      titleFontSize: _clampFontSize(titleFontSize ?? this.titleFontSize),
      tableFontSize: _clampFontSize(tableFontSize ?? this.tableFontSize),
      totalFontSize: _clampFontSize(totalFontSize ?? this.totalFontSize),
      noteFontSize: _clampFontSize(noteFontSize ?? this.noteFontSize),
      footerFontSize: _clampFontSize(footerFontSize ?? this.footerFontSize),
    );
  }

  static double _fontSizeFromJson(Object? raw, double fallback) {
    if (raw is! num) {
      return fallback;
    }
    return _clampFontSize(raw.toDouble());
  }

  static double _clampFontSize(double size) {
    return size.clamp(minFontSize, maxFontSize).toDouble();
  }

  @override
  bool operator ==(Object other) {
    return other is InvoicePdfFontSettings &&
        other.providerFontSize == providerFontSize &&
        other.recipientFontSize == recipientFontSize &&
        other.titleFontSize == titleFontSize &&
        other.tableFontSize == tableFontSize &&
        other.totalFontSize == totalFontSize &&
        other.noteFontSize == noteFontSize &&
        other.footerFontSize == footerFontSize;
  }

  @override
  int get hashCode => Object.hash(
    providerFontSize,
    recipientFontSize,
    titleFontSize,
    tableFontSize,
    totalFontSize,
    noteFontSize,
    footerFontSize,
  );
}

final class InvoiceChatDraft {
  InvoiceChatDraft({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.step,
    required List<InvoiceLine> lines,
    this.helpRequested = false,
    this.selectedRecipientId,
    this.manualRecipient = false,
    this.recipientName = '',
    this.recipientAddress = '',
    this.recipientJib = '',
    this.invoiceNumber = '',
    DateTime? issueDate,
    DateTime? currentLineDate,
    this.route = '',
    this.orderName = '',
    this.amount = '',
    this.storeOnline = true,
  }) : issueDate = issueDate ?? _dateOnly(DateTime.now()),
       currentLineDate =
           currentLineDate ?? issueDate ?? _dateOnly(DateTime.now()),
       lines = List.unmodifiable(lines);

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool helpRequested;
  final String step;
  final String? selectedRecipientId;
  final bool manualRecipient;
  final String recipientName;
  final String recipientAddress;
  final String recipientJib;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime currentLineDate;
  final String route;
  final String orderName;
  final String amount;
  final List<InvoiceLine> lines;
  final bool storeOnline;

  factory InvoiceChatDraft.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final issueDate = _dateFromJson(json['issueDate'], fallback: now);
    return InvoiceChatDraft(
      id: json['id'] as String,
      createdAt: _dateTimeFromJson(json['createdAt'], fallback: now),
      updatedAt: _dateTimeFromJson(json['updatedAt'], fallback: now),
      helpRequested: json['helpRequested'] as bool? ?? false,
      step: json['step'] as String? ?? 'recipient',
      selectedRecipientId: json['selectedRecipientId'] as String?,
      manualRecipient: json['manualRecipient'] as bool? ?? false,
      recipientName: json['recipientName'] as String? ?? '',
      recipientAddress: json['recipientAddress'] as String? ?? '',
      recipientJib: json['recipientJib'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      issueDate: issueDate,
      currentLineDate: _dateFromJson(
        json['currentLineDate'],
        fallback: issueDate,
      ),
      route: json['route'] as String? ?? '',
      orderName: json['orderName'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      storeOnline: json['storeOnline'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'helpRequested': helpRequested,
    'step': step,
    if (selectedRecipientId != null) 'selectedRecipientId': selectedRecipientId,
    'manualRecipient': manualRecipient,
    if (recipientName.isNotEmpty) 'recipientName': recipientName,
    if (recipientAddress.isNotEmpty) 'recipientAddress': recipientAddress,
    if (recipientJib.isNotEmpty) 'recipientJib': recipientJib,
    if (invoiceNumber.isNotEmpty) 'invoiceNumber': invoiceNumber,
    'issueDate': issueDate.toIso8601String(),
    'currentLineDate': currentLineDate.toIso8601String(),
    if (route.isNotEmpty) 'route': route,
    if (orderName.isNotEmpty) 'orderName': orderName,
    if (amount.isNotEmpty) 'amount': amount,
    'lines': lines.map((e) => e.toJson()).toList(),
    'storeOnline': storeOnline,
  };

  InvoiceChatDraft copyWith({
    DateTime? updatedAt,
    bool? helpRequested,
    String? step,
    String? selectedRecipientId,
    bool? manualRecipient,
    String? recipientName,
    String? recipientAddress,
    String? recipientJib,
    String? invoiceNumber,
    DateTime? issueDate,
    DateTime? currentLineDate,
    String? route,
    String? orderName,
    String? amount,
    List<InvoiceLine>? lines,
    bool? storeOnline,
    bool clearSelectedRecipientId = false,
  }) {
    return InvoiceChatDraft(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      helpRequested: helpRequested ?? this.helpRequested,
      step: step ?? this.step,
      selectedRecipientId: clearSelectedRecipientId
          ? null
          : (selectedRecipientId ?? this.selectedRecipientId),
      manualRecipient: manualRecipient ?? this.manualRecipient,
      recipientName: recipientName ?? this.recipientName,
      recipientAddress: recipientAddress ?? this.recipientAddress,
      recipientJib: recipientJib ?? this.recipientJib,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      issueDate: issueDate ?? this.issueDate,
      currentLineDate: currentLineDate ?? this.currentLineDate,
      route: route ?? this.route,
      orderName: orderName ?? this.orderName,
      amount: amount ?? this.amount,
      lines: lines ?? this.lines,
      storeOnline: storeOnline ?? this.storeOnline,
    );
  }
}

DateTime _dateFromJson(Object? raw, {required DateTime fallback}) {
  final parsed = raw is String ? DateTime.tryParse(raw) : null;
  if (parsed == null) {
    return _dateOnly(fallback);
  }
  return _dateOnly(parsed);
}

DateTime _dateTimeFromJson(Object? raw, {required DateTime fallback}) {
  return raw is String ? DateTime.tryParse(raw) ?? fallback : fallback;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

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
    this.pdfLayoutPreset = InvoicePdfLayoutPreset.normal,
    this.pdfFontSettings,
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

  /// Saved PDF spacing/font preset for invoices that need to fit more content.
  final InvoicePdfLayoutPreset pdfLayoutPreset;

  /// Optional section-level font sizes for manual PDF fit adjustments.
  final InvoicePdfFontSettings? pdfFontSettings;

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
      pdfLayoutPreset: InvoicePdfLayoutPreset.fromJson(json['pdfLayoutPreset']),
      pdfFontSettings: InvoicePdfFontSettings.fromJson(json['pdfFontSettings']),
    );
  }

  Map<String, dynamic> toJson() {
    final fontSettings = pdfFontSettings;
    return {
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
      if (pdfLayoutPreset != InvoicePdfLayoutPreset.normal)
        'pdfLayoutPreset': pdfLayoutPreset.name,
      if (fontSettings != null) 'pdfFontSettings': fontSettings.toJson(),
    };
  }

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
    InvoicePdfLayoutPreset? pdfLayoutPreset,
    InvoicePdfFontSettings? pdfFontSettings,
    bool clearSavedPdfPath = false,
    bool clearRecipientId = false,
    bool clearPdfFontSettings = false,
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
      pdfLayoutPreset: pdfLayoutPreset ?? this.pdfLayoutPreset,
      pdfFontSettings: clearPdfFontSettings
          ? null
          : (pdfFontSettings ?? this.pdfFontSettings),
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
