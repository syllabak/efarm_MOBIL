import 'package:efarm360/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('renvoie data et envoie le jeton', () async {
    final (api, a, _) = await makeClient({'GET /me': (_) => ok({'id': 1})});
    final d = await api.get<Map>('/me');
    expect(d['id'], 1);
    expect(a.calls.single.headers['Authorization'], 'Bearer acc_old_token_aaaaaaaaaa');
    expect(a.calls.single.uri.toString(), startsWith('https://efarm360.danov.sn/api/mobile/v1/me'));
  });

  test('mappe les erreurs sur le code, pas sur le message', () async {
    final (api, _, _) = await makeClient({'POST /auth/login': (_) => ko(401, 'identifiants_incorrects', 'Mauvais')});
    await expectLater(api.post('/auth/login', auth: false), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'identifiants_incorrects').having((e) => e.status, 'status', 401)));
  });

  test('route absente du serveur (404 sans JSON) : message explicite', () async {
    final (api, _, _) = await makeClient({'GET /sales': (_) => (status: 404, body: <String, dynamic>{})});
    await expectLater(api.get('/sales'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'non_disponible')));
  });

  test('réseau coupé : relit la dernière réponse GET réussie', () async {
    var online = true;
    final (api, a, _) = await makeClient({'GET /farm/lots': (_) => online ? ok([{'id': 1}], meta: {'page': 1}) : throw StateError('x')});
    final first = await api.list('/farm/lots', query: {'page': 1});
    expect(first.items.single['id'], 1);
    expect(api.offlineSince.value, isNull);
    online = false;
    a.routes.remove('GET /farm/lots'); // le faux serveur coupe la connexion
    final cached = await api.list('/farm/lots', query: {'page': 1});
    expect(cached.items.single['id'], 1);
    expect(api.offlineSince.value, isNotNull);
    await expectLater(api.list('/farm/lots', query: {'page': 2}), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
    await api.clearCache();
    await expectLater(api.list('/farm/lots', query: {'page': 1}), throwsA(isA<ApiException>()));
  });

  test('contrat OpenAPI : lu sur le serveur, copie locale si le réseau est coupé', () async {
    final (api, a, _) = await makeClient({'GET /openapi.json': (_) => (status: 200, body: {'paths': {'/sales': {'get': {}}}})});
    expect((await api.contract())!['paths'], isNotEmpty);
    a.routes.remove('GET /openapi.json');
    expect((await api.contract())!['paths'], isNotEmpty);
    await api.clearCache();
    expect(await api.contract(), isNull);
  });

  test('adresse du serveur collée avec le chemin de l\'API : ramenée à la racine du site', () async {
    final (api, a, t) = await makeClient({'GET /status': (_) => ok({'service': 'EFarm360'})});
    for (final u in ['https://efarm360.danov.sn/', 'https://efarm360.danov.sn/api/mobile/v1/status', 'https://efarm360.danov.sn/api/mobile/v1']) {
      await t.saveServer(u);
      await api.get<Map>('/status', auth: false);
      expect(a.calls.last.uri.toString(), 'https://efarm360.danov.sn/api/mobile/v1/status', reason: u);
    }
  });

  test('erreur 500 non JSON : extrait de la page d\'erreur affiché', () async {
    final (api, _, _) = await makeClient({'POST /auth/login': (_) => (status: 500, body: <String, dynamic>{})});
    await expectLater(api.post('/auth/login', auth: false), throwsA(isA<ApiException>().having((e) => e.status, 'status', 500).having((e) => e.code, 'code', 'erreur_serveur')));
  });

  test('coupure réseau = ApiException reseau', () async {
    final (api, _, _) = await makeClient({});
    await expectLater(api.get('/me'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
  });

  test('401 jeton_invalide : rafraîchit, stocke la nouvelle paire et rejoue', () async {
    var n = 0;
    final (api, a, t) = await makeClient({
      'GET /me': (o) => o.headers['Authorization'] == 'Bearer acc_new_token_bbbbbbbbbb' ? ok({'id': 7}) : ko(401, 'jeton_invalide'),
      'POST /auth/refresh': (o) {
        n++;
        expect(o.data, {'refresh_token': 'ref_old_token_aaaaaaaaaa'});
        return ok({'access_token': 'acc_new_token_bbbbbbbbbb', 'refresh_token': 'ref_new_token_bbbbbbbbbb'});
      },
    });
    final d = await api.get<Map>('/me');
    expect(d['id'], 7);
    expect(n, 1);
    expect(await t.refresh, 'ref_new_token_bbbbbbbbbb');
    expect(a.calls.length, 3);
  });

  test('requêtes simultanées : un seul rafraîchissement (rotation à usage unique)', () async {
    var refreshes = 0;
    final (api, _, _) = await makeClient({
      'GET /me': (o) => o.headers['Authorization'] == 'Bearer acc_new_token_bbbbbbbbbb' ? ok({'id': 1}) : ko(401, 'jeton_invalide'),
      'GET /devices': (o) => o.headers['Authorization'] == 'Bearer acc_new_token_bbbbbbbbbb' ? ok([]) : ko(401, 'jeton_invalide'),
      'POST /auth/refresh': (_) {
        refreshes++;
        return ok({'access_token': 'acc_new_token_bbbbbbbbbb', 'refresh_token': 'ref_new_token_bbbbbbbbbb'});
      },
    });
    await Future.wait([api.get('/me'), api.get('/devices'), api.get('/me')]);
    expect(refreshes, 1);
  });

  test('refresh refusé : session expirée, jetons effacés', () async {
    var expired = false;
    final (api, _, t) = await makeClient({
      'GET /me': (_) => ko(401, 'jeton_invalide'),
      'POST /auth/refresh': (_) => ko(401, 'refresh_rejoue'),
    });
    api.onSessionExpired = () => expired = true;
    await expectLater(api.get('/me'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'session_expiree')));
    expect(expired, isTrue);
    expect(await t.access, isNull);
  });

  test('refresh impossible faute de réseau : les jetons sont conservés', () async {
    final (api, _, t) = await makeClient({'GET /me': (_) => ko(401, 'jeton_invalide')});
    await expectLater(api.get('/me'), throwsA(isA<ApiException>()));
    expect(await t.refresh, 'ref_old_token_aaaaaaaaaa');
  });

  test('liste paginée : items et meta', () async {
    final (api, _, _) = await makeClient({
      'GET /farm/lots': (_) => ok([{'id': 1}, {'id': 2}], meta: {'page': 1, 'pages': 3, 'total': 5, 'per_page': 2})
    });
    final r = await api.list('/farm/lots');
    expect(r.items.length, 2);
    expect(r.meta['pages'], 3);
  });
}
