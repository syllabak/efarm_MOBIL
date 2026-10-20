import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/modules/module_pages.dart';
import 'package:efarm360/features/vet/relation_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

class _Farm extends SessionNotifier {
  @override
  Future<Profile?> build() async => Profile({'type': 'ferme', 'id': 1, 'role': 'responsable', 'tous_les_sites': false, 'site_id': 1});
}

Future<void> _pump(WidgetTester t, Widget w, Map<String, Handler> routes) async {
  final (api, _, _) = await makeClient(routes);
  await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api), sessionProvider.overrideWith(_Farm.new)], child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('messages ferme↔vétérinaire : sens, envoi', (t) async {
    var posted = 0;
    await _pump(t, const RelationThreadPage(path: '/vets/messages/7', title: 'Dr Sow', mySens: 'ferme'), {
      'GET /vets/messages/7': (_) => ok([
            {'id': 1, 'sens': 'veto', 'auteur': 'Dr Sow', 'corps': 'Isolez le lot 3', 'created_at': '2026-10-20 09:00:00'},
            {'id': 2, 'sens': 'ferme', 'auteur': 'Moi', 'corps': 'Bien reçu', 'created_at': '2026-10-20 09:05:00'},
          ]),
      'POST /vets/messages/7': (o) {
        posted++;
        expect((o.data as Map)['corps'], 'Merci docteur');
        return ok({'message': 'ok'});
      },
    });
    expect(find.text('Isolez le lot 3'), findsOneWidget);
    expect(find.text('Dr Sow'), findsWidgets);
    await t.enterText(find.byType(TextField), 'Merci docteur');
    await t.tap(find.byIcon(Icons.send));
    await t.pumpAndSettle();
    expect(posted, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('document du vétérinaire côté ferme : traitement affiché, « appliqué » proposé', (t) async {
    var applied = false;
    await _pump(t, ModuleDetailPage(farmVetDocsModule, 4), {
      'GET /vets/documents/4': (_) => ok({
            'id': 4, 'titre': 'Newcastle suspecté', 'type': 'ordonnance', 'gravite': 'urgent', 'statut': 'lu', 'veto_nom': 'Dr Sow', 'lot_code': 'FARM-2026-0003',
            'medicaments': [{'nom': 'Tylosine', 'dosage': '1 g/L', 'voie': 'eau de boisson', 'duree': '5 jours'}],
          }),
      'POST /vets/documents/4/applied': (_) {
        applied = true;
        return ok({'statut': 'applique'});
      },
    });
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Tylosine'), findsOneWidget);
    await t.ensureVisible(find.text('Marquer comme appliqué'));
    await t.tap(find.text('Marquer comme appliqué'));
    await t.pumpAndSettle();
    await t.tap(find.text('Confirmer'));
    await t.pumpAndSettle();
    expect(applied, isTrue);
  });
}
