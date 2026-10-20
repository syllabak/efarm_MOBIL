import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/comm/account_pages.dart';
import 'package:efarm360/features/comm/chat_pages.dart';
import 'package:efarm360/features/comm/support_pages.dart';
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

  testWidgets('messagerie : fil, envoi, nouveau message ajouté une seule fois', (t) async {
    var sent = 0;
    await _pump(t, const ChatThreadPage(roomId: 3, title: 'Toute l\'équipe'), {
      'GET /chat/rooms/3/messages': (o) => ok(o.queryParameters['depuis'] == null
          ? [
              {'id': 1, 'user_id': 2, 'auteur': 'Awa', 'moi': false, 'corps': 'Bonjour', 'supprime': false, 'created_at': '2026-10-20 08:00:00'},
            ]
          : [
              {'id': 1, 'user_id': 2, 'auteur': 'Awa', 'moi': false, 'corps': 'Bonjour', 'supprime': false, 'created_at': '2026-10-20 08:00:00'},
              {'id': 2, 'user_id': 1, 'auteur': 'Moi', 'moi': true, 'corps': 'Salut', 'supprime': false, 'created_at': '2026-10-20 08:01:00'},
            ]),
      'POST /chat/rooms/3/messages': (o) {
        sent++;
        expect((o.data as Map)['corps'], 'Salut');
        return ok({'message_id': 2});
      },
    });
    expect(find.text('Bonjour'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Salut');
    await t.tap(find.byIcon(Icons.send));
    await t.pumpAndSettle();
    expect(sent, 1);
    expect(find.text('Salut'), findsOneWidget);
    expect(find.text('Bonjour'), findsOneWidget);
    await t.pumpWidget(const SizedBox());   // arrête le minuteur de relève
  });

  testWidgets('support : l\'assistant répond, la proposition d\'agent apparaît', (t) async {
    await _pump(t, const SupportThreadPage(title: 'Assistant'), {
      'POST /support/chat': (_) => ok({'ticket_id': 8, 'statut': 'bot', 'proposer_agent': true, 'messages': [
            {'id': 20, 'auteur': 'bot', 'message': 'Je n\'ai pas de réponse précise.'}
          ]}),
    });
    await t.enterText(find.byType(TextField), 'Comment faire un bilan ?');
    await t.tap(find.byIcon(Icons.send));
    await t.pumpAndSettle();
    expect(find.text('Comment faire un bilan ?'), findsOneWidget);
    expect(find.text('Je n\'ai pas de réponse précise.'), findsOneWidget);
    expect(find.text('Parler à un agent'), findsOneWidget);
  });

  testWidgets('mot de passe : trois champs requis, corps envoyé tel quel', (t) async {
    Map<String, dynamic>? sent;
    await _pump(t, const PasswordPage(), {
      'POST /profile/password': (o) {
        sent = Map<String, dynamic>.from(o.data as Map);
        return ok({'message': 'ok'});
      },
    });
    await t.tap(find.text('Enregistrer'));
    await t.pump();
    expect(find.text('Requis'), findsNWidgets(3));
    await t.enterText(find.widgetWithText(TextFormField, 'Mot de passe actuel *'), 'ancien-1');
    await t.enterText(find.widgetWithText(TextFormField, 'Nouveau mot de passe *'), 'nouveau-22');
    await t.enterText(find.widgetWithText(TextFormField, 'Confirmer le nouveau mot de passe *'), 'nouveau-22');
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(sent, {'actuel': 'ancien-1', 'nouveau': 'nouveau-22', 'confirmation': 'nouveau-22'});
  });

  testWidgets('formation : progression, cours et statut', (t) async {
    await _pump(t, const TrainingPage(), {
      'GET /training': (_) => ok([
            {'id': 1, 'titre': 'Démarrage poussins', 'description': 'Les 7 premiers jours', 'progression': {'total': 4, 'termines': 1, 'pourcentage': 25}}
          ]),
    });
    expect(find.text('Démarrage poussins'), findsOneWidget);
    expect(find.text('1/4 cours terminés'), findsOneWidget);
  });
}
