import 'dart:convert';

import 'package:efarm360/features/vet/vet_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

Map<String, dynamic> snapshot() => {
      'genere_le': '2026-10-20T08:00:00+00:00',
      'clients': [{'id': 1, 'nom': 'Ferme Ba', 'telephone': '77'}],
      'patients': [{'id': 10, 'client_id': 1, 'nom': 'Bella', 'espece': 'bovin', 'type': 'individuel'}],
      'consultations': [{'id': 100, 'patient_id': 10, 'date_consultation': '2026-09-01 10:00:00', 'motif': 'Boiterie'}],
      'soins': [{'id': 200, 'patient_id': 10, 'libelle': 'Rage', 'type': 'vaccination', 'date_acte': '2026-09-01', 'rappel_le': '2026-10-01', 'rappel_statut': 'a_faire'}],
      'rdv': [{'id': 300, 'client_id': 1, 'patient_id': 10, 'debut': '2026-10-21 09:00:00', 'duree_min': 30, 'statut': 'prevu'}],
      'produits': [{'id': 5, 'nom': 'Ivermectine', 'stock': 3}],
    };

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<(VetRepo, FakeAdapter)> repo(Map<String, Handler> routes, [String key = 't']) async {
    final (api, a, _) = await makeClient({'GET /vet/sync/snapshot': (_) => ok(snapshot()), ...routes});
    await databaseFactory.deleteDatabase('${await getDatabasesPath()}/vet_$key.db');
    final r = VetRepo(api, key, connectivity: const Stream.empty());
    await r.open();
    return (r, a);
  }

  test('sync télécharge la copie locale et lit hors ligne', () async {
    final (r, _) = await repo({});
    expect(r.hasSnapshot, isFalse);
    await r.sync();
    expect(r.clients.single['nom'], 'Ferme Ba');
    expect(r.patients.single['nom'], 'Bella');
    expect(r.consultationsOf(10).single['motif'], 'Boiterie');
    expect(r.rappels.single['libelle'], 'Rage');
    expect(r.produits.single['nom'], 'Ivermectine');
    expect(r.lastSync, isNotNull);
  });

  test('hors ligne : les saisies sont visibles tout de suite et rattachées par ref', () async {
    final (r, _) = await repo({});
    await r.sync();
    // coupe le réseau : plus de route snapshot ni push
    final (api2, _, _) = await makeClient({});
    final off = VetRepo(api2, 't', connectivity: const Stream.empty());
    await off.open();
    expect(off.clients.length, 1, reason: 'la copie locale survit à la réouverture');

    final cref = await off.enqueue('client.creer', {'nom': 'Aaa Nouveau'});
    final cid = 'ref:$cref';
    final pref = await off.enqueue('patient.creer', {...idOrRef('client', cid), 'nom': 'Rex', 'espece': 'chien'});
    await off.enqueue('consultation.creer', {...idOrRef('patient', 'ref:$pref'), 'motif': 'Vaccin', 'date_consultation': '2026-10-20 08:00:00'});
    await off.enqueue('rdv.creer', {...idOrRef('client', cid), ...idOrRef('patient', 'ref:$pref'), 'debut': '2026-10-22 10:00:00'});

    expect(off.pendingCount, 4);
    expect(off.clients.first['nom'], 'Aaa Nouveau');
    expect(off.client(cid)!['pending'], true);
    expect(off.patient('ref:$pref')!['client_id'], cid);
    expect(off.consultationsOf('ref:$pref').single['motif'], 'Vaccin');
    expect(off.rdv.last['client_id'], cid);
    final d = off.queue[1].data;
    expect(d['client_ref'], cref);
    expect(d.containsKey('client_id'), isFalse);
  });

  test('statuts hors ligne appliqués sur la copie, rappel fait disparaît des rappels', () async {
    final (r, _) = await repo({'POST /vet/sync/push': (_) => throw StateError('x')}, 's');
    await r.sync();
    await r.setStatus('rappel.statut', 200, 'fait');
    await r.setStatus('rdv.statut', 300, 'confirme');
    expect(r.rappels, isEmpty);
    expect(r.rdv.single['statut'], 'confirme');
    expect(r.queue.first.data, {'id': 200, 'statut': 'fait'});
  });

  test('envoi : ok/deja retirent de la file, erreur est gardée avec son message', () async {
    late List ops;
    final (r, a) = await repo({}, 'e');
    for (final n in ['B', 'C', 'D']) {
      await r.enqueue('client.creer', {'nom': n});    // hors ligne : aucune route, tout reste en file
    }
    await r.sync();
    expect(r.pendingCount, 3);
    a.routes['POST /vet/sync/push'] = (o) {
      ops = (o.data as Map)['operations'] as List;
      return ok({
        'resultats': {
          ops[0]['ref']: {'statut': 'ok', 'id': 55},
          ops[1]['ref']: {'statut': 'deja', 'id': 56},
          ops[2]['ref']: {'statut': 'erreur', 'message': 'Propriétaire introuvable'},
        }
      });
    };
    await r.sync();
    expect(ops.length, 3);
    expect(jsonEncode(ops.first['donnees']), contains('"nom":"B"'));
    expect(r.queue.length, 1);
    expect(r.queue.single.state, 'erreur');
    expect(r.queue.single.message, 'Propriétaire introuvable');
    expect(r.clients.any((c) => c['nom'] == 'Ferme Ba'), isTrue, reason: 'la copie est rechargée après l\'envoi');
    // une saisie refusée n'est pas renvoyée automatiquement
    var again = 0;
    a.routes['POST /vet/sync/push'] = (_) { again++; return ok({'resultats': {}}); };
    await r.sync();
    expect(again, 0);
  });

  test('idOrRef', () {
    expect(idOrRef('client', 5), {'client_id': 5});
    expect(idOrRef('client', 'ref:abc'), {'client_ref': 'abc'});
    expect(idOrRef('patient', null), isEmpty);
    expect(isPending('ref:x'), isTrue);
    expect(isPending(3), isFalse);
  });
}
