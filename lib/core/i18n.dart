import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Locale;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Traduction de l'interface, même principe que `core/I18n.php` du site web : les textes sont écrits en français (langue source),
/// les dictionnaires `{ "texte français": "traduction" }` sont ceux du site (`assets/lang/{code}.json`) complétés par `assets/lang/mobile_{code}.json`.
/// Un texte absent reste en français. « {0} » = nombre, « {*} » = partie variable reprise dans la traduction.
class I18n extends ChangeNotifier {
  I18n._();
  static final I18n instance = I18n._();

  /// code => (nom dans sa langue, écriture de droite à gauche)
  static const languages = <String, (String, bool)>{
    'fr': ('Français', false),
    'en': ('English', false),
    'ar': ('العربية', true),
    'pt': ('Português', false),
    'es': ('Español', false),
  };

  static const _prefKey = 'efarm_lang';

  String _code = 'fr';
  Map<String, String> _dict = const {};
  List<(RegExp, String, String)> _patterns = const [];
  final Map<String, String> _cache = {};

  String get code => _code;
  bool get isRtl => languages[_code]?.$2 ?? false;
  Locale get locale => Locale(_code);

  /// Langue mémorisée (au démarrage).
  Future<void> init() async {
    String? c;
    try {
      c = (await SharedPreferences.getInstance()).getString(_prefKey);
    } catch (_) {}
    if (c != null && languages.containsKey(c)) await _load(c);
  }

  Future<void> setLanguage(String c) async {
    if (!languages.containsKey(c) || c == _code) return;
    await _load(c);
    try {
      await (await SharedPreferences.getInstance()).setString(_prefKey, c);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _load(String c) async {
    final d = <String, String>{};
    if (c != 'fr') {
      for (final f in ['assets/lang/$c.json', 'assets/lang/mobile_$c.json']) {
        try {
          final j = jsonDecode(await rootBundle.loadString(f));
          if (j is Map) j.forEach((k, v) => d['$k'] = '$v');
        } catch (_) {}
      }
    }
    loadDictionary(c, d);
  }

  /// Installe un dictionnaire (aussi utilisé par les tests).
  @visibleForTesting
  void loadDictionary(String c, Map<String, String> d) {
    _code = c;
    _dict = d;
    _cache.clear();
    final m = <(RegExp, String, String)>[];
    d.forEach((src, tr) {
      if (!src.contains('{')) return;
      final re = StringBuffer();
      var last = 0;
      for (final x in RegExp(r'\{\*\}|\{\d+\}').allMatches(src)) {
        re.write(RegExp.escape(src.substring(last, x.start)));
        re.write(x.group(0) == '{*}' ? '(.+?)' : r'(\d+(?:[.,]\d+)?)');
        last = x.end;
      }
      re.write(RegExp.escape(src.substring(last)));
      try {
        final prefix = src.split('{').first;
        m.add((RegExp('^$re\$', dotAll: true), tr, prefix.length > 4 ? prefix.substring(0, 4) : prefix));
      } catch (_) {}
    });
    _patterns = m;
  }

  static final _nums = RegExp(r'(?<![A-Za-z0-9])\d+(?:[.,]\d+)?(?![A-Za-z])');
  static final _ws = RegExp(r'[\s ]+');

  String t(String source) {
    if (_code == 'fr' || source.isEmpty) return source;
    final hit = _cache[source];
    if (hit != null) return hit;
    final out = _find(source.replaceAll(_ws, ' ').trim()) ?? source;
    if (_cache.length > 4000) _cache.clear();
    return _cache[source] = out;
  }

  String? _find(String key) {
    final d = _dict[key];
    if (d != null) return d;
    var n = 0;
    final numbers = <String>[];
    final gen = key.replaceAllMapped(_nums, (m) {
      numbers.add(m.group(0)!);
      return '{${n++}}';
    });
    if (numbers.isNotEmpty && _dict[gen] != null) return _fill(_dict[gen]!, numbers);
    for (final (re, tr, pref) in _patterns) {
      if (pref.isNotEmpty && !key.startsWith(pref) && !gen.startsWith(pref)) continue;
      for (final tryKey in [key, gen]) {
        final m = re.firstMatch(tryKey);
        if (m != null) {
          var i = 0;
          return tr.replaceAllMapped(RegExp(r'\{\*\}|\{\d+\}'), (x) {
            final v = i < m.groupCount ? (m.group(++i) ?? '') : '';
            if (x.group(0) != '{*}') return tryKey == key ? v : (numbers.length >= i ? numbers[i - 1] : v);
            return _find(v.trim()) ?? v;
          });
        }
      }
    }
    // Symboles en tête (emoji, flèches) : on traduit le texte qui suit
    final mm = RegExp(r'^([^\p{L}\p{N}{(«"“]+)(\p{L}.+)$', unicode: true, dotAll: true).firstMatch(key);
    if (mm != null && mm.group(1)!.trim().isNotEmpty) {
      final t = _find(mm.group(2)!);
      if (t != null) return mm.group(1)! + t;
    }
    // Textes composés : chaque morceau est traduit à part
    for (final sep in [' — ', ', ']) {
      if (!key.contains(sep) || key.length > 160 || (sep == ', ' && RegExp(r'[.:;!?]').hasMatch(key))) continue;
      final parts = key.split(sep);
      if (sep == ', ' && parts.map((p) => p.length).reduce((a, b) => a > b ? a : b) > 32) continue;
      var found = false;
      final out = [
        for (final p in parts)
          () {
            final t = _find(p);
            if (t != null) found = true;
            return t ?? p;
          }(),
      ];
      if (found) return out.join(sep);
    }
    return null;
  }

  String _fill(String tr, List<String> numbers) => tr.replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) => numbers[int.parse(m.group(1)!)]);
}

/// Traduit un texte source français dans la langue courante.
String tr(String source) => I18n.instance.t(source);
