import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

@JS('showSaveFilePicker')
external JSPromise<web.FileSystemFileHandle> _showSaveFilePicker(JSAny options);

Future<void> downloadPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final nativeSaveResult = await _savePdfWithNativePicker(
    bytes: bytes,
    fileName: fileName,
  );
  if (nativeSaveResult == _NativeSaveResult.saved ||
      nativeSaveResult == _NativeSaveResult.cancelled) {
    return;
  }

  _downloadPdfWithAnchor(bytes: bytes, fileName: fileName);
}

Future<_NativeSaveResult> _savePdfWithNativePicker({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (web.window.hasProperty('showSaveFilePicker'.toJS) != true.toJS) {
    return _NativeSaveResult.unavailable;
  }

  final options = {
    'suggestedName': fileName,
    'types': [
      {
        'description': 'PDF',
        'accept': {
          'application/pdf': ['.pdf'],
        },
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

void _downloadPdfWithAnchor({
  required Uint8List bytes,
  required String fileName,
}) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
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
