import 'dart:io' show File, Platform, Process;

import 'package:open_file/open_file.dart';

/// Desktop: označi fajl u Finderu / Exploreru; Linux otvara roditeljski folder.
/// Android/iOS: otvara PDF u podrazumijevanoj aplikaciji (nema pouzdanog
/// API-ja da se otvori samo folder u sistemu Datoteke kao na računaru).
Future<void> revealSavedPdfInSystemUi(String filePath) async {
  if (Platform.isMacOS) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw StateError('Fajl više ne postoji: $filePath');
    }
    final r = await Process.run('open', ['-R', filePath]);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      throw StateError(err.isEmpty ? 'open -R nije uspio.' : err);
    }
    return;
  }

  if (Platform.isWindows) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw StateError('Fajl više ne postoji: $filePath');
    }
    await Process.run('explorer', ['/select,', filePath]);
    return;
  }

  if (Platform.isLinux) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw StateError('Fajl više ne postoji: $filePath');
    }
    final parent = file.parent.path;
    final r = await Process.run('xdg-open', [parent]);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      throw StateError(err.isEmpty ? 'xdg-open nije uspio.' : err);
    }
    return;
  }

  final result = await OpenFile.open(filePath);
  if (result.type != ResultType.done) {
    final msg = result.message.trim();
    throw StateError(msg.isEmpty ? 'Otvaranje nije uspjelo.' : msg);
  }
}
