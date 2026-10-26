import 'dart:convert';
import 'dart:io';

import 'package:efarm360/core/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _load(String f) => (jsonDecode(File(f).readAsStringSync()) as Map).map((k, v) => MapEntry('$k', '$v'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('français : le texte source est rendu tel quel', () {
    I18n.instance.loadDictionary('fr', {});
    expect(tr('Aucune vente.'), 'Aucune vente.');
    expect(I18n.instance.isRtl, isFalse);
  });

  test('dictionnaires du site et du mobile : phrase exacte, nombre, partie variable, symbole en tête', () {
    for (final c in ['en', 'pt', 'es', 'ar']) {
      I18n.instance.loadDictionary(c, {..._load('assets/lang/$c.json'), ..._load('assets/lang/mobile_$c.json')});
      expect(tr('Aucune vente.'), isNot('Aucune vente.'), reason: c);
      expect(tr('Montant *'), isNot('Montant *'), reason: c);
      expect(tr('📅 Aujourd\'hui').startsWith('📅'), isTrue, reason: c);
    }
    expect(I18n.instance.isRtl, isTrue);
    I18n.instance.loadDictionary('en', {..._load('assets/lang/en.json'), ..._load('assets/lang/mobile_en.json')});
    expect(tr('Aucune vente.'), 'No sale.');
    expect(tr('Nom du lot (facultatif)'), 'Flock name (optional)');
    expect(tr('Ferme Ndiaye'), 'Ferme Ndiaye'); // inconnu : inchangé
    I18n.instance.loadDictionary('fr', {});
  });
}
