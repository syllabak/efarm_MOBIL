import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/modules/module_pages.dart';
import 'package:efarm360/features/vet/vet_docs_pages.dart';
import 'package:efarm360/features/vet/vet_manage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

class _Vet extends SessionNotifier {
  @override
  Future<Profile?> build() async => Profile({'type': 'veterinaire', 'id': 5, 'titulaire': true, 'droits': {}});
}

Future<void> _pump(WidgetTester t, Widget w, Map<String, Handler> routes) async {
  final (api, _, _) = await makeClient(routes);
  await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api), sessionProvider.overrideWith(_Vet.new)], child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('facture : client choisi par recherche, ligne du catalogue pré-remplie, corps envoyé typé', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, DynamicFormPage(title: 'Nouvelle facture', fields: documentFields('facture'), submit: (b) async {
      sent = {...b, 'type': 'facture'};
      return null;
    }), {
      'GET /vet/clients': (o) => ok([
            {'id': 4, 'nom': 'Ferme Ba'},
            {'id': 5, 'nom': 'Élevage Diop'},
          ], meta: {'page': 1, 'pages': 1}),
      'GET /vet/articles': (_) => ok([
            {'id': 9, 'nom': 'Vaccin Newcastle', 'unite': 'dose', 'prix_vente': 150, 'tva_pct': 0}
          ], meta: {'page': 1, 'pages': 1}),
    });
    await t.ensureVisible(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'));
    await t.pump();
    expect(find.text('Requis'), findsWidgets);
    expect(sent, isNull);

    await t.ensureVisible(find.text('Choisir…').first);
    await t.tap(find.text('Choisir…').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Ferme Ba'));
    await t.pumpAndSettle();

    await t.ensureVisible(find.byType(DropdownButtonFormField<String>).first);
    await t.tap(find.byType(DropdownButtonFormField<String>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Vaccin Newcastle').last);
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Désignation *'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'Quantité *'), '200');
    await t.ensureVisible(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(sent!['client_id'], 4);
    final l = (sent!['lignes'] as List).single as Map;
    expect(l['article_id'], 9);
    expect(l['designation'], 'Vaccin Newcastle');
    expect(l['prix_unitaire'], 150);
    expect(l['quantite'], 200);
    expect(l['unite'], 'dose');
  });

  testWidgets('réception de commande : seules les lignes reçues sont envoyées, avec lot et dépense', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, const ReceiveOrderPage(orderId: 3), {
      'GET /vet/orders/3': (_) => ok({'lignes': [
            {'id': 11, 'article_id': 9, 'designation': 'Vaccin', 'quantite': 100, 'quantite_recue': 0},
            {'id': 12, 'article_id': 8, 'designation': 'Seringues', 'quantite': 50, 'quantite_recue': 20},
          ]}),
      'POST /vet/orders/3/receive': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'message': '1 ligne(s) réceptionnée(s)'});
      },
    });
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), '60');      // ligne 1 reçue
    await t.enterText(fields.at(1), 'LOT-A1');
    await t.enterText(fields.at(2), '');         // ligne 2 : on efface le reste proposé
    await t.ensureVisible(find.text('Enregistrer la réception'));
    await t.tap(find.text('Enregistrer la réception'));
    await t.pumpAndSettle();
    final recu = sent!['recu'] as Map;
    expect(recu.keys, ['11']);
    expect(recu['11']['quantite'], 60);
    expect(recu['11']['numero_lot'], 'LOT-A1');
    expect(sent!['creer_depense'], true);
  });

  testWidgets('pharmacie : niveaux, filtre « ruptures »', (t) async {
    await _pump(t, const PharmacyPage(), {
      'GET /vet/pharmacy': (_) => ok({'valeur_totale': 250000, 'peremptions': [], 'stock': [
            {'id': 1, 'nom': 'Ivermectine', 'unite': 'flacon', 'stock': 0, 'stock_perime': 0, 'niveau': 'rupture', 'prochaine_peremption': null},
            {'id': 2, 'nom': 'Amoxicilline', 'unite': 'boîte', 'stock': 12, 'stock_perime': 0, 'niveau': 'ok', 'prochaine_peremption': '2027-03-01'},
          ]}),
    });
    expect(find.text('Ivermectine'), findsOneWidget);
    expect(find.text('Amoxicilline'), findsOneWidget);
    await t.tap(find.text('Ruptures'));
    await t.pumpAndSettle();
    expect(find.text('Amoxicilline'), findsNothing);
    expect(find.text('Ivermectine'), findsOneWidget);
  });
}
