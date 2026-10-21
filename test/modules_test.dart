import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/modules/module_pages.dart';
import 'package:efarm360/features/modules/cattle_extra.dart';
import 'package:efarm360/features/modules/registry_elevage.dart';
import 'package:efarm360/features/modules/elevage_extra.dart';
import 'package:efarm360/features/modules/registry_gestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:efarm360/core/server_support.dart';
import 'package:efarm360/features/modules/compare_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

class _Admin extends SessionNotifier {
  @override
  Future<Profile?> build() async => Profile({'type': 'ferme', 'id': 1, 'role': 'admin', 'tous_les_sites': true, 'fonctions': {'bande_intelligence': true, 'previsions': false}});
}

Future<void> _pump(WidgetTester t, Widget w, Map<String, Handler> routes) async {
  final (api, _, _) = await makeClient(routes);
  await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api), sessionProvider.overrideWith(_Admin.new)], child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('employés : liste, formulaire de création typé (site, rémunération, date)', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, ModuleListPage(employeesModule), {
      'GET /employees': (_) => ok([
            {'id': 1, 'prenom': 'Awa', 'nom': 'Diop', 'poste': 'Ouvrière', 'site': 'Nord', 'salaire': 90000, 'actif': 1}
          ], meta: {'page': 1, 'pages': 1}),
      'GET /farm/sites': (_) => ok([{'id': 2, 'nom': 'Nord'}]),
      'POST /employees': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'id': 5});
      },
    });
    expect(find.text('Awa Diop'), findsOneWidget);
    expect(find.text('Ouvrière · Nord'), findsOneWidget);
    await t.tap(find.text('Employé'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'));
    await t.pump();
    await t.ensureVisible(find.text('Requis').first);
    expect(find.text('Requis'), findsWidgets);
    expect(sent, isNull);

    await t.ensureVisible(find.byType(DropdownButtonFormField<String>).first);
    await t.tap(find.byType(DropdownButtonFormField<String>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Nord').last);
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Prénom *'), 'Moussa');
    await t.enterText(find.widgetWithText(TextFormField, 'Nom *'), 'Ba');
    await t.enterText(find.widgetWithText(TextFormField, 'Salaire mensuel'), '85000');
    await t.ensureVisible(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(sent!['site_id'], 2);
    expect(sent!['prenom'], 'Moussa');
    expect(sent!['mode_calcul'], 'fixe');
    expect(sent!['salaire'], 85000);
    expect(sent!['date_embauche'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(sent!.containsKey('taux_horaire'), isFalse);
  });

  testWidgets('paie : détail, actions selon le statut, confirmation avant paiement', (t) async {
    var paid = false;
    await _pump(t, ModuleDetailPage(payslipsModule, 3), {
      'GET /payslips/3': (_) => ok({'id': 3, 'prenom': 'Awa', 'nom': 'Diop', 'periode_debut': '2026-09-01', 'periode_fin': '2026-09-30', 'salaire_base': 90000, 'primes': 0, 'deductions': 0, 'salaire_net': 90000, 'statut': 'brouillon'}),
      'POST /payslips/3/pay': (_) {
        paid = true;
        return ok({'statut': 'paye'});
      },
    });
    expect(find.text('Net à payer'), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);
    await t.tap(find.text('Marquer payé'));
    await t.pumpAndSettle();
    expect(find.textContaining('dépense « Salaires »'), findsOneWidget);
    expect(paid, isFalse);
    await t.tap(find.text('Confirmer'));
    await t.pumpAndSettle();
    expect(paid, isTrue);
  });

  testWidgets('bovin : fiche, historique, action « sortie » avec formulaire et corps typé', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, ModuleDetailPage(cattleModule, 12), {
      'GET /cattle/12': (_) => ok({
            'id': 12, 'numero': 'SN-0012', 'nom': 'Bella', 'sexe': 'F', 'categorie': 'Vache', 'race_nom': 'Zébu Gobra', 'statut': 'present', 'poids': 310, 'etat': 'Gestante confirmée',
            'evenements': [{'id': 1, 'type': 'pesee', 'type_nom': 'Pesée', 'date_event': '2026-10-01', 'valeur': 310, 'detail': null}],
            'descendants': [],
          }),
      'POST /cattle/12/exit': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'message': 'Sortie enregistrée'});
      },
    });
    expect(find.text('Gestante confirmée'), findsOneWidget);
    expect(find.text('Pesée'), findsOneWidget);
    expect(find.text('310 kg'), findsWidgets);
    expect(find.text('Réintégrer'), findsNothing);
    await t.ensureVisible(find.text('Sortie du troupeau'));
    await t.tap(find.text('Sortie du troupeau'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(DropdownButtonFormField<String>).first);
    await t.tap(find.byType(DropdownButtonFormField<String>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Vente').last);
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Prix de vente'), '450000');
    await t.ensureVisible(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(sent!['type'], 'vente');
    expect(sent!['prix_vente'], 450000);
    expect(sent!['date_sortie'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  testWidgets('traite : seules les quantités saisies sont envoyées', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, const CattleMilkPage(), {
      'GET /cattle/milk': (_) => ok({'jour': '2026-10-20', 'prix_litre': 400, 'serie': [], 'vaches': [
            {'id': 1, 'numero': 'V1', 'nom': 'Bella', 'matin': null, 'soir': null, 'jours_lactation': 40},
            {'id': 2, 'numero': 'V2', 'nom': null, 'matin': 5, 'soir': null, 'jours_lactation': 80},
          ]}),
      'POST /cattle/milk': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'message': 'ok'});
      },
    });
    await t.enterText(find.widgetWithText(TextField, 'Matin').first, '6,5');
    await t.pump();
    expect(find.textContaining('Total : '), findsOneWidget);
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    final l = sent!['lignes'] as Map;
    expect(l.keys, containsAll(['1', '2']));
    expect(l['1']['matin'], 6.5);
    expect(l['2']['matin'], 5);
  });

  testWidgets('couvoir : valeurs imbriquées affichées, actions selon le statut, éclosion typée', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, ModuleDetailPage(hatcheryModule, 4), {
      'GET /hatchery/4': (_) => ok({
            'id': 4, 'code': 'INC-2026-001', 'race': 'Cobb', 'statut': 'en_incubation', 'nb_oeufs_mis': 1000, 'site_nom': 'Nord',
            'indicateurs': {'jours_restants': 6, 'taux_fertilite': 91.5, 'taux_eclosion': null}, 'mirages': [],
          }),
      'POST /hatchery/4/hatch': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'statut': 'eclos'});
      },
    });
    expect(find.text('91,5 %'), findsOneWidget);
    expect(find.text('Convertir en lot d\'élevage'), findsNothing);
    await t.ensureVisible(find.text('Enregistrer l\'éclosion'));
    await t.tap(find.text('Enregistrer l\'éclosion'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Poussins éclos *'), '870');
    await t.ensureVisible(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(sent!['nb_poussins_eclos'], 870);
    expect(sent!['date_eclosion_reelle'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  testWidgets('pesée du lot d\'embouche : envoie seulement les poids saisis', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, const FatteningWeighingPage(lotId: 7), {
      'GET /fattening/7': (_) => ok({'animaux': [
            {'id': 1, 'numero': 'B1', 'nom': null, 'statut': 'present', 'poids': 250},
            {'id': 2, 'numero': 'B2', 'nom': 'Rex', 'statut': 'present', 'poids': null},
            {'id': 3, 'numero': 'B3', 'nom': null, 'statut': 'vendu', 'poids': 400},
          ]}),
      'POST /fattening/7/weighing': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'message': 'ok'});
      },
    });
    expect(find.text('B3'), findsNothing);
    await t.enterText(find.byType(TextField).first, '262,5');
    await t.tap(find.text('Enregistrer les pesées'));
    await t.pumpAndSettle();
    expect(sent!['poids'], {'1': 262.5});
  });

  testWidgets('lot : détail imbriqué, actions selon l\'offre', (t) async {
    await _pump(t, ModuleDetailPage(lotsModule, 9), {
      'GET /lots/9/performance': (_) => ok({
            'lot': {'id': 9, 'code': 'FARM-2026-0009', 'race': 'Cobb', 'statut': 'actif', 'site_nom': 'Nord'},
            'performance': {'age_jours': 31, 'chiffre_affaires': 0, 'total_depenses': 450000},
            'mortalite': {'nb_initial': 1000, 'nb_actuel': 960, 'total_pertes': 40, 'taux_pct': 4, 'statut': 'normale'},
            'causes': [{'cause': 'maladie', 'total': 25}], 'rapports': [],
          }),
    });
    expect(find.text('FARM-2026-0009 · Cobb'), findsOneWidget);
    expect(find.text('Normale'), findsOneWidget);
    expect(find.text('Saisir le rapport du jour'), findsOneWidget);
    expect(find.text('Clôturer le lot'), findsOneWidget);
    expect(find.text('Tableau de bande'), findsOneWidget);
    expect(find.text('Prévision d\'aliment'), findsNothing);
  });

  testWidgets('lot : détail du serveur actuel (ligne brute, sans actions)', (t) async {
    hideUnsupported = true;
    addTearDown(() => hideUnsupported = false);
    expect(lotsSpec, same(lotsModuleBase));
    await _pump(t, ModuleDetailPage(lotsModuleBase, 9), {
      'GET /farm/lots/9': (_) => ok({'id': 9, 'code': 'FARM-2026-0009', 'race': 'Cobb', 'statut': 'actif', 'nb_initial': 1000, 'nb_actuel': 960}),
    });
    expect(find.text('FARM-2026-0009 · Cobb'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.text('Clôturer le lot'), findsNothing);
    expect(find.text('Saisir le rapport du jour'), findsNothing);
  });

  testWidgets('comparer les bandes : choix du site puis bandes côte à côte', (t) async {
    Map<String, dynamic>? query;
    await _pump(t, const CompareBandsPage(), {
      'GET /farm/sites': (_) => ok([{'id': 1, 'nom': 'Nord'}, {'id': 2, 'nom': 'Sud'}]),
      'GET /lots/compare': (o) {
        query = o.queryParameters;
        return ok([
          {'lot_id': 7, 'code': 'FARM-7', 'taux_mortalite_pct': 4.2, 'total_aliment_kg': 1500, 'marge_beneficiaire_pct': 12.5},
        ]);
      },
    });
    expect(find.text('Choisissez un site pour comparer ses dernières bandes.'), findsOneWidget);
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pumpAndSettle();
    await t.tap(find.text('Sud').last);
    await t.pumpAndSettle();
    expect(query!['site_id'], 2);
    expect(find.text('FARM-7'), findsOneWidget);
    expect(find.textContaining('Mortalité : 4,2 %'), findsOneWidget);
  });

  testWidgets('employé : désactiver demande confirmation puis envoie actif=false ; inactif propose la réactivation', (t) async {
    Map<String, dynamic>? sent;
    var actif = 1;
    await _pump(t, ModuleDetailPage(employeesModule, 5), {
      'GET /employees/5': (_) => ok({'id': 5, 'prenom': 'Awa', 'nom': 'Diop', 'actif': actif}),
      'POST /employees/5/active': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        actif = 0;
        return ok({'actif': false});
      },
    });
    expect(find.text('Réactiver'), findsNothing);
    await t.ensureVisible(find.text('Désactiver'));
    await t.tap(find.text('Désactiver'));
    await t.pumpAndSettle();
    expect(find.text('Désactiver cet employé ? Il n\'apparaîtra plus dans la paie.'), findsOneWidget);
    await t.tap(find.text('Confirmer'));
    await t.pumpAndSettle();
    expect(sent, {'actif': false});
    await t.ensureVisible(find.text('Réactiver'));
    expect(find.text('Réactiver'), findsOneWidget);
  });
}
