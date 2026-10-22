import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// CSV lisible directement par Excel en français : séparateur « ; », guillemets doublés, BOM UTF-8.
String toCsv(List<String> headers, List<List<Object?>> rows) {
  String cell(Object? v) {
    final s = v == null ? '' : '$v';
    return s.contains(RegExp(r'[;"\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  return '\u{FEFF}${[headers, ...rows].map((r) => r.map(cell).join(';')).join('\r\n')}\r\n';
}

/// Écrit le CSV puis ouvre la feuille de partage du système (enregistrer, envoyer par WhatsApp, e-mail…).
Future<void> shareCsv(String filename, List<String> headers, List<List<Object?>> rows) async {
  final bytes = utf8.encode(toCsv(headers, rows));
  final XFile file;
  if (kIsWeb) {
    file = XFile.fromData(bytes, mimeType: 'text/csv', name: filename);
  } else {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$filename');
    await f.writeAsBytes(bytes);
    file = XFile(f.path, mimeType: 'text/csv');
  }
  await SharePlus.instance.share(ShareParams(files: [file], subject: filename, fileNameOverrides: [filename]));
}
