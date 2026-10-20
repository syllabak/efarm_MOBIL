import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/commerce/sale_form.dart';
import 'package:efarm360/features/farm/ops_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

class _Resp extends SessionNotifier {
  @override
  Future<Profile?> build() async => Profile({'type': 'ferme', 'id': 1, 'role': 'responsable', 'tous_les_sites': false, 'site_id': 1});
}

Future<void> _pump(WidgetTester t, Widget w, Map<String, Handler> routes) async {
  final (api, _, _) = await makeClient(routes);
  await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api), sessionProvider.overrideWith(_Resp.new)], child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('vente : validation, lot obligatoire, corps envoyé au serveur', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, const SaleForm(), {
      'GET /farm/sites': (_) => ok([{'id': 1, 'nom': 'Nord'}]),
      'GET /farm/lots': (_) => ok([{'id': 9, 'code': 'L-9', 'nb_actuel': 100}], meta: {'page': 1, 'pages': 1}),
      'POST /sales': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'vente_id': 3, 'numero': 'VTE-2026-0003', 'montant_total': 90000});
      },
    });
    await t.scrollUntilVisible(find.text('Enregistrer la vente'), 300, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('Enregistrer la vente'));
    await t.pump();
    expect(find.text('Choisissez un lot ou cochez « sans lot »'), findsOneWidget);
    expect(find.text('Requis'), findsWidgets);
    expect(sent, isNull);

    await t.ensureVisible(find.text('Lot concerné *'));
    await t.tap(find.text('Lot concerné *'));
    await t.pumpAndSettle();
    await t.tap(find.text('L-9 · 100 têtes').last);
    await t.pumpAndSettle();
    // champs : [nom client libre, désignation, qté, unité, prix, remise, notes]
    await t.enterText(find.widgetWithText(TextFormField, 'Désignation *'), 'Poulets de chair');
    await t.enterText(find.widgetWithText(TextFormField, 'Prix unitaire'), '2000');
    await t.enterText(find.widgetWithText(TextFormField, 'Qté'), '50');
    await t.pump();
    expect(find.textContaining(RegExp(r'^100\D000 F$')), findsWidgets);
    await t.enterText(find.widgetWithText(TextFormField, 'Remise globale'), '10');
    await t.pump();
    await t.scrollUntilVisible(find.text('Enregistrer la vente'), 300, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('Enregistrer la vente'));
    await t.pumpAndSettle();
    expect(sent!['lot_id'], 9);
    expect(sent!['mode_paiement'], 'especes');
    expect(sent!['remise_pct'], 10);
    expect(sent!['lignes'], [
      {'designation': 'Poulets de chair', 'unite': 'tête', 'quantite': 50, 'prix_unitaire': 2000}
    ]);
  });

  testWidgets('sortie de stock : erreur serveur affichée, rien ne se ferme', (t) async {
    await _pump(t, const StockMovementForm(entry: false), {
      'GET /stock/products': (_) => ok([{'id': 4, 'nom': 'Aliment démarrage', 'unite': 'sac'}]),
      'GET /farm/sites': (_) => ok([{'id': 1, 'nom': 'Nord'}]),
      'POST /stock/exits': (_) => ko(422, 'stock_insuffisant', 'Stock insuffisant (disponible : 3 sac)'),
    });
    await t.tap(find.text('Produit *'));
    await t.pumpAndSettle();
    await t.tap(find.text('Aliment démarrage (sac)').last);
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Quantité *'), '10');
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(find.text('Stock insuffisant (disponible : 3 sac)'), findsOneWidget);
    expect(find.byType(StockMovementForm), findsOneWidget);
  });

  testWidgets('alertes : non lues en tête, bouton « Tout lire » actif', (t) async {
    var lu = false;
    await _pump(t, const AlertsPage(), {
      'GET /alerts': (_) => ok([
            {'id': 1, 'type': 'mortalite', 'message': 'Mortalité élevée', 'lue': 0, 'created_at': '2026-10-20 08:00:00', 'lot_code': 'L-9'},
            {'id': 2, 'type': 'stock', 'message': 'Stock bas', 'lue': 1, 'created_at': '2026-10-19 08:00:00'},
          ], meta: {'page': 1, 'pages': 1, 'non_lues': 1}),
      'POST /alerts/read': (_) {
        lu = true;
        return ok({'marquees': 1});
      },
    });
    expect(find.text('Mortalité élevée'), findsOneWidget);
    await t.tap(find.text('Tout lire'));
    await t.pumpAndSettle();
    expect(lu, isTrue);
  });
}
