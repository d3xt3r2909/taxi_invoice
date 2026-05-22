import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

final class InvoiceChatNoteImage {
  InvoiceChatNoteImage({
    required this.id,
    required this.base64,
    required this.mimeType,
    required this.name,
    List<InvoiceChatNoteStroke> strokes = const [],
    List<Map<String, dynamic>> drawingJson = const [],
  }) : strokes = List.unmodifiable(strokes),
       drawingJson = List.unmodifiable(drawingJson.map(_copyDrawingJsonEntry));

  final String id;
  final String base64;
  final String mimeType;
  final String name;
  final List<InvoiceChatNoteStroke> strokes;
  final List<Map<String, dynamic>> drawingJson;

  factory InvoiceChatNoteImage.fromJson(Map<String, dynamic> json) {
    return InvoiceChatNoteImage(
      id: json['id'] as String? ?? '',
      base64: json['base64'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      name: json['name'] as String? ?? '',
      strokes: (json['strokes'] as List<dynamic>? ?? [])
          .map(InvoiceChatNoteStroke.fromJson)
          .where((stroke) => stroke.points.isNotEmpty)
          .toList(),
      drawingJson: _drawingJsonFromJson(json['drawingJson']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'base64': base64,
    'mimeType': mimeType,
    'name': name,
    if (strokes.isNotEmpty)
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    if (drawingJson.isNotEmpty) 'drawingJson': drawingJson,
  };

  InvoiceChatNoteImage copyWith({
    String? id,
    String? base64,
    String? mimeType,
    String? name,
    List<InvoiceChatNoteStroke>? strokes,
    List<Map<String, dynamic>>? drawingJson,
  }) {
    return InvoiceChatNoteImage(
      id: id ?? this.id,
      base64: base64 ?? this.base64,
      mimeType: mimeType ?? this.mimeType,
      name: name ?? this.name,
      strokes: strokes ?? this.strokes,
      drawingJson: drawingJson ?? this.drawingJson,
    );
  }
}

List<Map<String, dynamic>> _drawingJsonFromJson(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((entry) => _copyDrawingJsonEntry(Map<String, dynamic>.from(entry)))
      .toList();
}

Map<String, dynamic> _copyDrawingJsonEntry(Map<String, dynamic> entry) {
  return Map<String, dynamic>.unmodifiable(
    jsonDecode(jsonEncode(entry)) as Map<String, dynamic>,
  );
}

final class InvoiceChatNoteStroke {
  InvoiceChatNoteStroke({
    required this.colorValue,
    required this.width,
    required List<InvoiceChatNotePoint> points,
  }) : points = List.unmodifiable(points);

  final int colorValue;
  final double width;
  final List<InvoiceChatNotePoint> points;

  factory InvoiceChatNoteStroke.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return InvoiceChatNoteStroke(colorValue: 0, width: 0, points: const []);
    }
    return InvoiceChatNoteStroke(
      colorValue: raw['colorValue'] as int? ?? 0xCCFFB300,
      width: _strokeWidthFromJson(raw['width']),
      points: (raw['points'] as List<dynamic>? ?? [])
          .map(InvoiceChatNotePoint.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'colorValue': colorValue,
    'width': width,
    'points': points.map((point) => point.toJson()).toList(),
  };
}

final class InvoiceChatNotePoint {
  const InvoiceChatNotePoint({required this.x, required this.y});

  final double x;
  final double y;

  factory InvoiceChatNotePoint.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return const InvoiceChatNotePoint(x: 0, y: 0);
    }
    return InvoiceChatNotePoint(
      x: _normalizedPointValue(raw['x']),
      y: _normalizedPointValue(raw['y']),
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

double _strokeWidthFromJson(Object? raw) {
  if (raw is! num) {
    return 8;
  }
  return raw.toDouble().clamp(1, 36).toDouble();
}

double _normalizedPointValue(Object? raw) {
  if (raw is! num) {
    return 0;
  }
  return raw.toDouble().clamp(0, 1).toDouble();
}

abstract interface class InvoiceChatNoteImageStorage {
  Future<InvoiceChatNoteImage?> read(String id);

  Future<void> write(InvoiceChatNoteImage image);

  Future<void> delete(String id);
}

final class SharedPreferencesInvoiceChatNoteImageStorage
    implements InvoiceChatNoteImageStorage {
  const SharedPreferencesInvoiceChatNoteImageStorage();

  static const _keyPrefix = 'invoice_chat_note_image_v1_';

  @override
  Future<InvoiceChatNoteImage?> read(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$trimmedId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final image = InvoiceChatNoteImage.fromJson(json);
      return image.base64.isEmpty ? null : image;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(InvoiceChatNoteImage image) async {
    if (image.id.trim().isEmpty || image.base64.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${image.id}', jsonEncode(image.toJson()));
  }

  @override
  Future<void> delete(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$trimmedId');
  }
}
