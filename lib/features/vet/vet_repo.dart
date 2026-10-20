import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';

/// Une saisie en attente d'envoi (mode hors ligne du cabinet).
class QueuedOp {
  QueuedOp(this.ref, this.type, this.data, this.createdAt, this.state, this.message);
  final String ref;
  final String type;
  final Map<String, dynamic> data;
  final String createdAt;
  final String state; // attente | erreur
  final String? message;

  static const labels = {
    'client.creer': 'Nouveau client',
    'patient.creer': 'Nouveau patient',
    'consultation.creer': 'Consultation',
    'soin.creer': 'Soin / vaccin',
    'rdv.creer': 'Rendez-vous',
    'rappel.statut': 'Rappel',
    'rdv.statut': 'Statut de rendez-vous',
  };
  String get label => labels[type] ?? type;
}

/// Identifiant local d'une saisie qui n'a pas encore de numéro serveur : `ref:<ref>`.
bool isPending(Object? id) => id is String && id.startsWith('ref:');

/// Convertit un identifiant (numérique serveur, ou `ref:…` local) en paire de clés pour une saisie.
Map<String, dynamic> idOrRef(String key, Object? id) {
  if (id == null) return {};
  if (isPending(id)) return {'${key}_ref': (id as String).substring(4)};
  return {'${key}_id': id};
}

/// Copie locale + file de saisies du cabinet vétérinaire d'un compte.
/// Principe (voir docs/api/mobile-v1.md §4) : lecture sur la copie locale, écriture dans une file envoyée par `POST /vet/sync/push`.
class VetRepo extends ChangeNotifier {
  VetRepo(this._api, this.key, {Stream<List<ConnectivityResult>>? connectivity}) : _connectivity = connectivity;
  final ApiClient _api;
  final String key;
  final Stream<List<ConnectivityResult>>? _connectivity;
  Database? _db;
  final _uuid = const Uuid();
  bool syncing = false;
  String? lastSyncError;
  String? snapshotAt;
  DateTime? lastSync;
  StreamSubscription<List<ConnectivityResult>>? _net;

  List<Map<String, dynamic>> _clients = [], _patients = [], _consultations = [], _soins = [], _rdv = [], _produits = [];
  List<QueuedOp> queue = [];

  Future<void> open() async {
    final dir = await getDatabasesPath();
    _db = await openDatabase(p.join(dir, 'vet_$key.db'), version: 1, onCreate: (d, _) async {
      await d.execute('CREATE TABLE docs (kind TEXT NOT NULL, id INTEGER NOT NULL, json TEXT NOT NULL, PRIMARY KEY (kind, id))');
      await d.execute('CREATE TABLE queue (seq INTEGER PRIMARY KEY AUTOINCREMENT, ref TEXT UNIQUE NOT NULL, type TEXT NOT NULL, donnees TEXT NOT NULL, created_at TEXT NOT NULL, etat TEXT NOT NULL, message TEXT)');
      await d.execute('CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT)');
    });
    await _loadAll();
    _net = (_connectivity ?? Connectivity().onConnectivityChanged).listen((r) {
      if (!r.contains(ConnectivityResult.none)) sync();
    });
  }

  @override
  void dispose() {
    _net?.cancel();
    _db?.close();
    super.dispose();
  }

  // ── Lecture ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _docs(String kind) async => [
        for (final r in await _db!.query('docs', where: 'kind = ?', whereArgs: [kind])) Map<String, dynamic>.from(jsonDecode(r['json'] as String) as Map)
      ];

  Future<void> _loadAll() async {
    _clients = await _docs('clients');
    _patients = await _docs('patients');
    _consultations = await _docs('consultations');
    _soins = await _docs('soins');
    _rdv = await _docs('rdv');
    _produits = await _docs('produits');
    snapshotAt = await _meta('genere_le');
    final ls = await _meta('derniere_synchro');
    lastSync = ls == null ? null : DateTime.tryParse(ls);
    queue = [
      for (final r in await _db!.query('queue', orderBy: 'seq'))
        QueuedOp(r['ref'] as String, r['type'] as String, Map<String, dynamic>.from(jsonDecode(r['donnees'] as String) as Map), r['created_at'] as String, r['etat'] as String, r['message'] as String?)
    ];
    notifyListeners();
  }

  Future<String?> _meta(String k) async {
    final r = await _db!.query('meta', where: 'k = ?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  bool get hasSnapshot => snapshotAt != null;
  int get pendingCount => queue.length;

  Iterable<QueuedOp> _ops(String type) => queue.where((o) => o.type == type);

  /// Valeur de l'identifiant référencé par une saisie : numéro serveur ou `ref:…`.
  Object? _target(Map<String, dynamic> d, String key) => d['${key}_id'] ?? (d['${key}_ref'] != null ? 'ref:${d['${key}_ref']}' : null);

  /// Cible d'un changement de statut : `{id}` serveur ou `{ref}` d'une saisie locale.
  Object? _targetOf(Map<String, dynamic> d) => d['id'] ?? (d['ref'] != null ? 'ref:${d['ref']}' : null);

  List<Map<String, dynamic>> get clients => [
        ..._clients,
        for (final o in _ops('client.creer')) {...o.data, 'id': 'ref:${o.ref}', 'pending': true},
      ]..sort((a, b) => '${a['nom']}'.toLowerCase().compareTo('${b['nom']}'.toLowerCase()));

  List<Map<String, dynamic>> get patients => [
        ..._patients,
        for (final o in _ops('patient.creer')) {...o.data, 'id': 'ref:${o.ref}', 'client_id': _target(o.data, 'client'), 'pending': true},
      ]..sort((a, b) => '${a['nom']}'.toLowerCase().compareTo('${b['nom']}'.toLowerCase()));

  List<Map<String, dynamic>> get produits => _produits;

  Map<String, dynamic>? client(Object? id) => clients.where((c) => c['id'] == id).firstOrNull;
  Map<String, dynamic>? patient(Object? id) => patients.where((c) => c['id'] == id).firstOrNull;

  /// Rendez-vous (copie + saisies en attente), statuts modifiés hors ligne appliqués.
  List<Map<String, dynamic>> get rdv {
    final changes = {for (final o in _ops('rdv.statut')) _targetOf(o.data): o.data['statut']};
    final out = [
      for (final r in _rdv) {...r, if (changes.containsKey(r['id'])) 'statut': changes[r['id']]},
      for (final o in _ops('rdv.creer'))
        {...o.data, 'id': 'ref:${o.ref}', 'client_id': _target(o.data, 'client'), 'patient_id': _target(o.data, 'patient'), 'statut': o.data['statut'] ?? 'prevu', 'duree_min': o.data['duree_min'] ?? 30, 'pending': true},
    ];
    out.sort((a, b) => '${a['debut']}'.compareTo('${b['debut']}'));
    return out;
  }

  List<Map<String, dynamic>> consultationsOf(Object? patientId) => [
        for (final c in _consultations) if (c['patient_id'] == patientId) c,
        for (final o in _ops('consultation.creer'))
          if (_target(o.data, 'patient') == patientId) {...o.data, 'id': 'ref:${o.ref}', 'date_consultation': o.data['date_consultation'] ?? o.createdAt, 'pending': true},
      ]..sort((a, b) => '${b['date_consultation']}'.compareTo('${a['date_consultation']}'));

  List<Map<String, dynamic>> soinsOf(Object? patientId) => [for (final s in soins) if (s['patient_id'] == patientId) s];

  /// Soins avec rappels hors ligne appliqués.
  List<Map<String, dynamic>> get soins {
    final changes = {for (final o in _ops('rappel.statut')) _targetOf(o.data): o.data['statut']};
    return [
      for (final s in _soins) {...s, if (changes.containsKey(s['id'])) 'rappel_statut': changes[s['id']]},
      for (final o in _ops('soin.creer'))
        {...o.data, 'id': 'ref:${o.ref}', 'patient_id': _target(o.data, 'patient'), 'date_acte': o.data['date_acte'] ?? o.createdAt.substring(0, 10), 'rappel_statut': o.data['rappel_le'] != null ? 'a_faire' : 'aucun', 'pending': true},
    ]..sort((a, b) => '${b['date_acte']}'.compareTo('${a['date_acte']}'));
  }

  /// Rappels de soins à faire, du plus ancien au plus récent.
  List<Map<String, dynamic>> get rappels => [
        for (final s in soins) if (s['rappel_statut'] == 'a_faire' && s['rappel_le'] != null) s,
      ]..sort((a, b) => '${a['rappel_le']}'.compareTo('${b['rappel_le']}'));

  // ── Écriture (file d'attente) ──────────────────────────────────────
  String newRef() => _uuid.v4().replaceAll('-', '');

  Future<String> enqueue(String type, Map<String, dynamic> data) async {
    final ref = newRef();
    await _db!.insert('queue', {'ref': ref, 'type': type, 'donnees': jsonEncode(data), 'created_at': DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' '), 'etat': 'attente'});
    await _loadAll();
    unawaited(sync());
    return ref;
  }

  /// Changement de statut idempotent sur un élément (numéro serveur ou saisie locale).
  Future<void> setStatus(String type, Object id, String statut) => enqueue(type, {if (isPending(id)) 'ref': (id as String).substring(4) else 'id': id, 'statut': statut});

  Future<void> discard(String ref) async {
    await _db!.delete('queue', where: 'ref = ?', whereArgs: [ref]);
    await _loadAll();
  }

  Future<void> retryAll() async {
    await _db!.update('queue', {'etat': 'attente', 'message': null});
    await sync();
  }

  // ── Synchronisation ────────────────────────────────────────────────
  /// Envoie la file puis recharge la copie locale. Sans danger si rappelée : les saisies portent une `ref` unique.
  Future<void> sync() => _running ??= _sync().whenComplete(() => _running = null);
  Future<void>? _running;

  Future<void> _sync() async {
    if (_db == null) return;
    syncing = true;
    lastSyncError = null;
    notifyListeners();
    try {
      final waiting = queue.where((o) => o.state == 'attente').toList();
      for (var i = 0; i < waiting.length; i += 200) {
        final batch = waiting.sublist(i, (i + 200).clamp(0, waiting.length));
        final r = await _api.post<Map>('/vet/sync/push', body: {
          'operations': [for (final o in batch) {'ref': o.ref, 'type': o.type, 'donnees': o.data}]
        });
        final res = Map<String, dynamic>.from(r['resultats'] as Map? ?? {});
        for (final o in batch) {
          final x = res[o.ref] as Map?;
          if (x == null) continue;
          if (x['statut'] == 'ok' || x['statut'] == 'deja') {
            await _db!.delete('queue', where: 'ref = ?', whereArgs: [o.ref]);
          } else {
            await _db!.update('queue', {'etat': 'erreur', 'message': x['message'] as String?}, where: 'ref = ?', whereArgs: [o.ref]);
          }
        }
      }
      await _pull();
    } on ApiException catch (e) {
      lastSyncError = e.isNetwork ? null : e.message; // hors ligne : pas une erreur à afficher
    } finally {
      syncing = false;
      await _loadAll();
    }
  }

  Future<void> _pull() async {
    final s = await _api.get<Map>('/vet/sync/snapshot');
    await _db!.transaction((t) async {
      await t.delete('docs');
      final b = t.batch();
      for (final kind in ['clients', 'patients', 'consultations', 'soins', 'rdv', 'produits']) {
        for (final row in (s[kind] as List? ?? const [])) {
          b.insert('docs', {'kind': kind, 'id': (row as Map)['id'] as int, 'json': jsonEncode(row)}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      b.insert('meta', {'k': 'genere_le', 'v': '${s['genere_le']}'}, conflictAlgorithm: ConflictAlgorithm.replace);
      b.insert('meta', {'k': 'derniere_synchro', 'v': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
      await b.commit(noResult: true);
    });
  }

  /// Efface toutes les copies locales du cabinet (déconnexion) : elles contiennent des données de clients.
  static Future<void> wipeAll() async {
    final dir = await getDatabasesPath();
    for (final f in await Directory(dir).list().toList()) {
      final n = p.basename(f.path);
      if (n.startsWith('vet_')) await deleteDatabase(f.path);
    }
  }
}

/// Empreinte stable (djb2) pour nommer la base d'un compte sans y mettre l'adresse e-mail.
String _stableHash(String s) {
  var h = 5381;
  for (final c in s.codeUnits) {
    h = ((h << 5) + h + c) & 0x7fffffff;
  }
  return h.toRadixString(36);
}

final vetRepoProvider = FutureProvider.autoDispose<VetRepo>((ref) async {
  final api = ref.watch(apiProvider);
  final profile = ref.watch(sessionProvider.select((s) => s.value));
  if (profile == null || !profile.isVet) throw StateError('Compte vétérinaire requis');
  // Une base par compte (le collaborateur et le titulaire n'ont pas les mêmes droits)
  final repo = VetRepo(api, '${profile.id}_${_stableHash(profile.email.toLowerCase())}');
  await repo.open();
  ref.onDispose(repo.dispose);
  unawaited(repo.sync());
  return repo;
});
