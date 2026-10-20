import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Dernières réponses GET réussies, relues quand le réseau est coupé (lecture seule).
abstract class ResponseCache {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> json);
  Future<void> clear();
}

/// Cache en mémoire (tests, web).
class MemoryCache implements ResponseCache {
  final _m = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, Map<String, dynamic> json) async => _m[key] = json;
  @override
  Future<void> clear() async => _m.clear();
}

/// Cache persistant : un fichier JSON par requête dans le dossier privé de l'application.
class FileCache implements ResponseCache {
  Directory? _dir;

  Future<Directory> _d() async {
    final base = await getApplicationSupportDirectory();
    return _dir ??= await Directory(p.join(base.path, 'cache')).create(recursive: true);
  }

  static String _name(String key) {
    var h = 5381;
    for (final c in key.codeUnits) {
      h = ((h << 5) + h + c) & 0x7fffffff;
    }
    return 'r_${h.toRadixString(36)}_${key.length}.json';
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final f = File(p.join((await _d()).path, _name(key)));
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map;
      return j['key'] == key ? Map<String, dynamic>.from(j['json'] as Map) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    try {
      await File(p.join((await _d()).path, _name(key))).writeAsString(jsonEncode({'key': key, 'json': json}));
    } catch (_) {/* le cache est facultatif */}
  }

  @override
  Future<void> clear() async {
    try {
      final d = await _d();
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}

ResponseCache defaultCache() => kIsWeb ? MemoryCache() : FileCache();
