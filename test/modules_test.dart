import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/modules/module_pages.dart';
import 'package:efarm360/features/modules/registry_gestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

class _Admin extends SessionNotifier {
  @override
  Future<Profile?> build() async => Profile({'type': 'ferme', 'id': 1, 'role': 'admin', 'tous_les_sites': true});
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
}
