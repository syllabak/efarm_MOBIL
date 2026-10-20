import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/commerce/commerce_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

class _FakeSession extends SessionNotifier {
  @override
  Future<Profile?> build() async => Profile({'type': 'ferme', 'id': 1, 'role': 'responsable', 'tous_les_sites': false, 'site_id': 1});
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('ventes : résumé, liste, statut de paiement, encaissement refusé au-delà du reste', (t) async {
    Map<String, dynamic>? payment;
    final (api, _, _) = await makeClient({
      'GET /sales/summary': (_) => ok({'ca_jour': 1000, 'ca_mois': 250000, 'ca_annee': 3000000, 'creances': 50000, 'nb_ventes_non_soldees': 2, 'evolution': []}),
      'GET /sales': (_) => ok([
            {'id': 5, 'numero': 'V-0005', 'date_vente': '2026-10-19', 'montant_total': 80000, 'encaisse': 30000, 'paiement': 'partiel', 'client': 'Awa Diop', 'statut': 'confirmee'}
          ], meta: {'page': 1, 'pages': 1, 'total': 1, 'per_page': 50}),
      'GET /sales/5': (_) => ok({
            'id': 5, 'numero': 'V-0005', 'date_vente': '2026-10-19', 'client': 'Awa Diop', 'mode_paiement': 'credit', 'montant_total': 80000,
            'lignes': [{'designation': 'Poulets', 'unite': 'tête', 'quantite': 40, 'prix_unitaire': 2000, 'montant_ligne': 80000}],
            'encaissements': [{'id': 1, 'montant': 30000, 'date_encaissement': '2026-10-19', 'mode': 'especes'}],
            'situation': {'total': 80000, 'encaisse': 30000, 'reste': 50000, 'statut': 'partiel'},
          }),
      'POST /sales/5/payments': (o) {
        payment = Map<String, dynamic>.from(o.data as Map);
        return ok({'encaissement_id': 2});
      },
    });
    await t.pumpWidget(ProviderScope(
      overrides: [apiProvider.overrideWithValue(api), sessionProvider.overrideWith(_FakeSession.new)],
      child: const MaterialApp(home: VentesPage()),
    ));
    await t.pumpAndSettle();
    expect(find.text('V-0005 · ${money(80000)}'), findsOneWidget);
    expect(find.text('Partielle'), findsOneWidget);
    expect(find.text(money(250000)), findsOneWidget);

    await t.tap(find.text('V-0005 · ${money(80000)}'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Reste à payer'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Reste à payer'), findsOneWidget);
    await t.dragUntilVisible(find.text('Encaisser un paiement'), find.byType(ListView), const Offset(0, -200));
    await t.tap(find.text('Encaisser un paiement'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextFormField).first, '60000');
    await t.tap(find.text('Valider'));
    await t.pump();
    expect(find.text('Dépasse le reste à payer'), findsOneWidget);
    expect(payment, isNull);

    await t.enterText(find.byType(TextFormField).first, '50000');
    await t.tap(find.text('Valider'));
    await t.pumpAndSettle();
    expect(payment!['montant'], 50000);
    expect(payment!['mode'], 'especes');
  });
}
