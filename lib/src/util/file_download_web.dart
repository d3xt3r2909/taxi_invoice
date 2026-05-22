import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

@JS('showSaveFilePicker')
external JSPromise<web.FileSystemFileHandle> _showSaveFilePicker(JSAny options);

Future<void> downloadFileBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required String description,
  required List<String> extensions,
}) async {
  final nativeSaveResult = await _saveFileWithNativePicker(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
    description: description,
    extensions: extensions,
  );
  if (nativeSaveResult == _NativeSaveResult.saved ||
      nativeSaveResult == _NativeSaveResult.cancelled) {
    return;
  }

  _downloadFileWithAnchor(bytes: bytes, fileName: fileName, mimeType: mimeType);
}

Future<_NativeSaveResult> _saveFileWithNativePicker({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required String description,
  required List<String> extensions,
}) async {
  if (web.window.hasProperty('showSaveFilePicker'.toJS) != true.toJS) {
    return _NativeSaveResult.unavailable;
  }

  final options = {
    'suggestedName': fileName,
    'types': [
      {
        'description': description,
        'accept': {mimeType: extensions},
      },
    ],
  }.jsify();
  if (options == null) {
    return _NativeSaveResult.unavailable;
  }

  try {
    final handle = await _showSaveFilePicker(options).toDart;
    final writable = await handle.createWritable().toDart;
    await writable.write(bytes.toJS).toDart;
    await writable.close().toDart;
    return _NativeSaveResult.saved;
  } catch (error) {
    if (_isPickerCancel(error)) {
      return _NativeSaveResult.cancelled;
    }
    return _NativeSaveResult.unavailable;
  }
}

bool _isPickerCancel(Object error) {
  return error.toString().contains('AbortError');
}

void _downloadFileWithAnchor({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;

  web.window.document.body?.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
}

enum _NativeSaveResult { saved, cancelled, unavailable }
