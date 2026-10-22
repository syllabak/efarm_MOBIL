import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/vet/vet_docs_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('factures : liste, détail, encaissement borné au reste', (t) async {
    Map<String, dynamic>? sent;
    final (api, _, _) = await makeClient({
      'GET /vet/documents': (_) => ok([
            {'id': 7, 'type': 'facture', 'numero': 'F-0007', 'client': 'Ferme Ba', 'date_emission': '2026-10-18', 'statut': 'emise', 'total_ttc': 50000, 'paiement': 'partielle'}
          ], meta: {'page': 1, 'pages': 1}),
      'GET /vet/documents/7': (_) => ok({
            'id': 7, 'type': 'facture', 'numero': 'F-0007', 'statut': 'emise', 'paiement': 'partielle', 'date_emission': '2026-10-18', 'client': {'nom': 'Ferme Ba'},
            'total_ht': 50000, 'tva_total': 0, 'total_ttc': 50000, 'paye': 20000, 'reste': 30000,
            'lignes': [{'designation': 'Vaccin Newcastle', 'unite': 'dose', 'quantite': 500, 'prix_unitaire': 100, 'remise_pct': 0, 'total_ttc': 50000}],
            'paiements': [{'id': 1, 'date_paiement': '2026-10-19', 'montant': 20000, 'mode': 'wave'}],
          }),
      'POST /vet/documents/7/payments': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'message': 'Paiement enregistré'});
      },
    });
    await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api)], child: const MaterialApp(home: DocumentsPage())));
    await t.pumpAndSettle();
    expect(find.text('Partielle'), findsOneWidget);
    await t.tap(find.textContaining('F-0007 ·'));
    await t.pumpAndSettle();
    expect(find.text('Vaccin Newcastle'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Encaisser un paiement'), 300, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(find.text('Encaisser un paiement'));
    await t.pumpAndSettle();
    await t.tap(find.text('Encaisser un paiement'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, '40000');
    await t.tap(find.text('Valider'));
    await t.pump();
    expect(find.text('Dépasse le reste à payer'), findsOneWidget);
    expect(sent, isNull);
    await t.enterText(find.byType(TextFormField).first, '30000');
    await t.tap(find.text('Valider'));
    await t.pumpAndSettle();
    expect(sent!['montant'], 30000);
    expect(sent!['mode'], 'especes');
  });

  testWidgets('facture : suppression d\'un paiement avec confirmation', (t) async {
    var deletes = 0;
    final (api, _, _) = await makeClient({
      'GET /vet/documents/7': (_) => ok({
            'id': 7, 'type': 'facture', 'numero': 'F-0007', 'statut': 'emise', 'paiement': 'partielle', 'date_emission': '2026-10-18', 'client': {'nom': 'Ferme Ba'},
            'total_ht': 50000, 'tva_total': 0, 'total_ttc': 50000, 'paye': 20000, 'reste': 30000, 'lignes': [],
            'paiements': deletes == 0 ? [{'id': 1, 'date_paiement': '2026-10-19', 'montant': 20000, 'mode': 'wave'}] : [],
          }),
      'POST /vet/payments/1/delete': (_) {
        deletes++;
        return ok({'supprime': true});
      },
    });
    await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api)], child: const MaterialApp(home: DocumentDetailPage(id: 7))));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byTooltip('Supprimer ce paiement'), 300, scrollable: find.byType(Scrollable).last);
    await t.tap(find.byTooltip('Supprimer ce paiement'));
    await t.pumpAndSettle();
    await t.tap(find.text('Confirmer'));
    await t.pumpAndSettle();
    expect(deletes, 1);
    expect(find.byTooltip('Supprimer ce paiement'), findsNothing);
  });
}
