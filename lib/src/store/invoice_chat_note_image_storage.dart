import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

final class InvoiceChatNoteImage {
  const InvoiceChatNoteImage({
    required this.id,
    required this.base64,
    required this.mimeType,
    required this.name,
  });

  final String id;
  final String base64;
  final String mimeType;
  final String name;

  factory InvoiceChatNoteImage.fromJson(Map<String, dynamic> json) {
    return InvoiceChatNoteImage(
      id: json['id'] as String? ?? '',
      base64: json['base64'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'base64': base64,
    'mimeType': mimeType,
    'name': name,
  };
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
