import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/server_support.dart';
import '../../core/session.dart';
import '../modules/module_pages.dart' show DynamicFormPage;
import '../modules/spec.dart' show FieldSpec, FieldType;
import '../../ui/common.dart';
import 'vet_forms.dart';
import 'vet_repo.dart';

Widget _rebuild(VetRepo repo, Widget Function(BuildContext) b) => ListenableBuilder(listenable: repo, builder: (c, _) => b(c));

/// Bandeau d'état de la synchronisation (saisies en attente, erreurs, copie locale).
class SyncBanner extends StatelessWidget {
  const SyncBanner(this.repo, {super.key});
  final VetRepo repo;
  @override
  Widget build(BuildContext context) {
    final erreurs = repo.queue.where((o) => o.state == 'erreur').length;
    if (repo.syncing) return const LinearProgressIndicator();
    if (repo.pendingCount == 0 && repo.lastSyncError == null) return const SizedBox.shrink();
    return MaterialBanner(
      backgroundColor: erreurs > 0 ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.secondaryContainer,
      content: Text(erreurs > 0
          ? '$erreurs saisie(s) refusée(s) par le serveur — à corriger.'
          : repo.lastSyncError ?? '${repo.pendingCount} saisie(s) en attente d\'envoi.'),
      leading: Icon(erreurs > 0 ? Icons.error_outline : Icons.cloud_upload_outlined),
      actions: [
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SyncPage(repo: repo))), child: const Text('Détails')),
        TextButton(onPressed: repo.sync, child: const Text('Envoyer')),
      ],
    );
  }
}

// ── Accueil ──────────────────────────────────────────────────────────
/// Couleur des indicateurs du cabinet sur le site web (cyan-800).
const _cyan = Color(0xFF155E75);

class VetHome extends ConsumerWidget {
  const VetHome({super.key, required this.repo, required this.onGoto});
  final VetRepo repo;
  final void Function(int) onGoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).value!;
    return _rebuild(repo, (c) {
      final today = isoDate(DateTime.now());
      final rdv = [for (final r in repo.rdv) if ('${r['debut']}'.startsWith(today) && r['statut'] != 'annule') r];
      final rappels = repo.rappels;
      final retard = rappels.where((r) => '${r['rappel_le']}'.compareTo(today) < 0).length;
      final consultMois = repo.consultations.where((r) => '${r['date_consultation']}'.compareTo('${today.substring(0, 8)}01') >= 0).length;
      return Column(children: [
        SyncBanner(repo),
        Expanded(
          child: RefreshIndicator(
            onRefresh: repo.sync,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
              Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Text('Bonjour ${p.fullName}', style: Theme.of(c).textTheme.titleLarge)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(repo.lastSync == null ? 'Copie locale non chargée — connectez-vous au réseau.' : 'Données du ${fmtDateTime(repo.lastSync!.toIso8601String())}', style: Theme.of(c).textTheme.bodySmall),
              ),
              GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.6, padding: const EdgeInsets.all(4), children: [
                Stat('Rendez-vous aujourd\'hui', '${rdv.length}', icon: Icons.event_available, color: _cyan),
                Stat(retard > 0 ? 'Rappels à faire (30 jours) · $retard en retard' : 'Rappels à faire (30 jours)', '${rappels.length}', icon: Icons.notification_important_outlined, color: retard > 0 ? Colors.red : _cyan),
                Stat('Consultations ce mois-ci', '$consultMois', icon: Icons.medical_services_outlined, color: _cyan),
                Stat('Patients suivis', '${repo.patients.length}', icon: Icons.pets, color: _cyan),
              ]),
              if (rdv.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 0), child: Text('📅 Aujourd\'hui', style: TextStyle(fontWeight: FontWeight.bold))),
                for (final r in rdv) RdvTile(r, repo: repo),
              ],
              if (rappels.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 0), child: Text('💉 Rappels de vaccins et soins', style: TextStyle(fontWeight: FontWeight.bold))),
                for (final r in rappels.take(15)) RappelTile(r, repo: repo),
              ],
              if (repo.consultations.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 0), child: Text('🩺 Dernières consultations', style: TextStyle(fontWeight: FontWeight.bold))),
                for (final r in repo.consultations.take(8))
                  ListTile(
                    leading: const Icon(Icons.medical_services_outlined, color: _cyan),
                    title: Text('${repo.patient(r['patient_id'])?['nom'] ?? 'Patient'}'),
                    subtitle: Text('${r['motif'] ?? ''}'),
                    trailing: Text(fmtDate(r['date_consultation'])),
                  ),
              ],
              if (rdv.isEmpty && rappels.isEmpty) const Padding(padding: EdgeInsets.all(32), child: EmptyView('Rien de prévu aujourd\'hui.', icon: Icons.check_circle_outline)),
            ]),
          ),
        ),
      ]);
    });
  }
}

class RappelTile extends StatelessWidget {
  const RappelTile(this.s, {super.key, required this.repo});
  final Map<String, dynamic> s;
  final VetRepo repo;
  @override
  Widget build(BuildContext context) {
    final late = '${s['rappel_le']}'.compareTo(isoDate(DateTime.now())) < 0;
    final pat = repo.patient(s['patient_id']);
    return Card(
      child: ListTile(
        leading: Icon(Icons.notifications_active_outlined, color: late ? Colors.red : null),
        title: Text('${s['libelle']}'),
        subtitle: Text('${pat?['nom'] ?? 'Patient'} · ${fmtDate(s['rappel_le'])}${late ? ' · en retard' : ''}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => repo.setStatus('rappel.statut', s['id'] as Object, v),
          itemBuilder: (_) => const [PopupMenuItem(value: 'fait', child: Text('Marquer fait')), PopupMenuItem(value: 'annule', child: Text('Annuler le rappel'))],
        ),
        onTap: pat == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetail(repo: repo, patientId: pat['id']))),
      ),
    );
  }
}

// ── Clients ──────────────────────────────────────────────────────────
class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key, required this.repo});
  final VetRepo repo;
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String _q = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        body: _rebuild(widget.repo, (c) {
          final list = [for (final x in widget.repo.clients) if ('${x['nom']} ${x['telephone'] ?? ''} ${x['contact'] ?? ''}'.toLowerCase().contains(_q.toLowerCase())) x];
          return Column(children: [
            SyncBanner(widget.repo),
            Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Rechercher un client'), onChanged: (v) => setState(() => _q = v))),
            Expanded(
              child: list.isEmpty
                  ? const EmptyView('Aucun client.')
                  : ListView.builder(
                      itemCount: list.length + 1,
                      itemBuilder: (c, i) {
                        if (i == list.length) return const SizedBox(height: 80);
                        final x = list[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${x['nom']}'.isEmpty ? '?' : '${x['nom']}'[0].toUpperCase())),
                            title: Text('${x['nom']}'),
                            subtitle: Text([x['contact'], x['telephone']].whereType<String>().join(' · ')),
                            trailing: x['pending'] == true ? const Icon(Icons.cloud_upload_outlined) : null,
                            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ClientDetail(repo: widget.repo, clientId: x['id']))),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        }),
        floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientForm(repo: widget.repo))), child: const Icon(Icons.person_add_alt)),
      );
}

const _clientFields = [
  FieldSpec('nom', 'Nom / exploitation', required: true),
  FieldSpec('contact', 'Personne à contacter'),
  FieldSpec('telephone', 'Téléphone', type: FieldType.phone),
  FieldSpec('email', 'E-mail', type: FieldType.email),
  FieldSpec('adresse', 'Adresse'),
  FieldSpec('notes', 'Notes', type: FieldType.multiline),
];

class ClientDetail extends ConsumerWidget {
  const ClientDetail({super.key, required this.repo, required this.clientId});
  final VetRepo repo;
  final Object? clientId;

  Future<void> _edit(BuildContext c, WidgetRef ref, Map<String, dynamic> x) async {
    final api = ref.read(apiProvider);
    final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => DynamicFormPage(title: 'Modifier le client', fields: _clientFields, initialValues: x, successMessage: 'Client mis à jour.', submit: (b) => api.post('/vet/clients/${x['id']}', body: b))));
    if (ok == true) await repo.sync();
  }

  Future<void> _delete(BuildContext c, WidgetRef ref, Map<String, dynamic> x) async {
    final yes = await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(title: const Text('Supprimer le client'), content: const Text('Supprimer ce client ? S\'il a des factures ou des ordonnances, il est archivé au lieu d\'être effacé.'), actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error), onPressed: () => Navigator.pop(d, true), child: const Text('Confirmer')),
            ]));
    if (yes != true || !c.mounted) return;
    try {
      final r = await ref.read(apiProvider).post<Map>('/vet/clients/${x['id']}/delete');
      await repo.sync();
      if (!c.mounted) return;
      showInfo(c, r['archive'] == true ? 'Client archivé (il a des documents).' : 'Client supprimé.');
      Navigator.pop(c);
    } catch (e) {
      if (c.mounted) showError(c, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _rebuild(repo, (c) {
        final x = repo.client(clientId);
        if (x == null) return Scaffold(appBar: AppBar(), body: const EmptyView('Client introuvable.'));
        final pats = [for (final p in repo.patients) if (p['client_id'] == clientId) p];
        final rdvs = [for (final r in repo.rdv) if (r['client_id'] == clientId) r];
        // Modifier / supprimer passent directement par le serveur : impossible pour un client encore en attente d'envoi.
        final enLigne = !isPending(clientId);
        return Scaffold(
          appBar: AppBar(title: Text('${x['nom']}'), actions: [
            if (enLigne && serverCan('POST', '/vet/clients/{id}')) IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(c, ref, x)),
            if (enLigne && serverCan('POST', '/vet/clients/{id}/delete')) IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(c, ref, x)),
          ]),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            KeyValue('Contact', x['contact']),
            KeyValue('Téléphone', x['telephone']),
            KeyValue('E-mail', x['email']),
            KeyValue('Adresse', x['adresse']),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => PatientForm(repo: repo, client: x))), icon: const Icon(Icons.add), label: const Text('Patient'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RdvForm(repo: repo, client: x))), icon: const Icon(Icons.event), label: const Text('Rendez-vous'))),
            ]),
            const SizedBox(height: 16),
            Text('Patients (${pats.length})', style: Theme.of(c).textTheme.titleMedium),
            for (final p in pats) PatientTile(p, repo: repo),
            const SizedBox(height: 16),
            Text('Rendez-vous (${rdvs.length})', style: Theme.of(c).textTheme.titleMedium),
            for (final r in rdvs.reversed.take(10)) RdvTile(r, repo: repo, showClient: false),
          ]),
        );
      });
}

// ── Patients ─────────────────────────────────────────────────────────
/// Âge lisible à partir d'une date de naissance (« 3 ans », « 8 mois »), comme sur la fiche web.
String? _age(Object? naissance) {
  final d = DateTime.tryParse('${naissance ?? ''}');
  if (d == null) return null;
  final now = DateTime.now();
  final mois = (now.year - d.year) * 12 + now.month - d.month - (now.day < d.day ? 1 : 0);
  if (mois < 0) return null;
  if (mois < 24) return '$mois mois';
  return '${mois ~/ 12} ans';
}

class PatientTile extends StatelessWidget {
  const PatientTile(this.p, {super.key, required this.repo, this.showClient = false});
  final Map<String, dynamic> p;
  final VetRepo repo;
  final bool showClient;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(p['type'] == 'groupe' ? Icons.groups_outlined : Icons.pets)),
          title: Text('${p['nom']}'),
          subtitle: Text([
            especes['${p['espece']}'],
            p['race'],
            if (p['type'] == 'groupe') '${p['effectif']} têtes',
            if (showClient) repo.client(p['client_id'])?['nom'],
            _age(p['date_naissance']),
            if (repo.consultationsOf(p['id']).isNotEmpty) 'vu le ${fmtDate(repo.consultationsOf(p['id']).first['date_consultation'])}',
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
          trailing: p['pending'] == true ? const Icon(Icons.cloud_upload_outlined) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetail(repo: repo, patientId: p['id']))),
        ),
      );
}

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key, required this.repo});
  final VetRepo repo;
  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  String _q = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        body: _rebuild(widget.repo, (c) {
          final list = [for (final x in widget.repo.patients) if ('${x['nom']} ${x['identification'] ?? ''} ${widget.repo.client(x['client_id'])?['nom'] ?? ''}'.toLowerCase().contains(_q.toLowerCase())) x];
          return Column(children: [
            SyncBanner(widget.repo),
            Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Nom, identification, propriétaire'), onChanged: (v) => setState(() => _q = v))),
            Expanded(child: list.isEmpty ? const EmptyView('Aucun patient.') : ListView(children: [for (final p in list) PatientTile(p, repo: widget.repo, showClient: true), const SizedBox(height: 80)])),
          ]);
        }),
        floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientForm(repo: widget.repo))), child: const Icon(Icons.add)),
      );
}

class PatientDetail extends StatelessWidget {
  const PatientDetail({super.key, required this.repo, required this.patientId});
  final VetRepo repo;
  final Object? patientId;
  @override
  Widget build(BuildContext context) => _rebuild(repo, (c) {
        final p = repo.patient(patientId);
        if (p == null) return Scaffold(appBar: AppBar(), body: const EmptyView('Patient introuvable.'));
        final hist = <({String date, Widget tile})>[
          for (final x in repo.consultationsOf(patientId))
            (
              date: '${x['date_consultation']}',
              tile: Card(
                  child: ExpansionTile(
                leading: const Icon(Icons.medical_information_outlined),
                title: Text('${x['motif']}'),
                subtitle: Text(fmtDateTime(x['date_consultation'])),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  KeyValue('Anamnèse', x['anamnese']), KeyValue('Examen', x['examen']), KeyValue('Température', x['temperature'] == null ? null : '${x['temperature']} °C'),
                  KeyValue('Poids', x['poids_kg'] == null ? null : '${x['poids_kg']} kg'), KeyValue('Diagnostic', x['diagnostic']), KeyValue('Traitement', x['traitement']),
                  KeyValue('Observations', x['observations']), KeyValue('Prochaine visite', x['prochaine_visite'] == null ? null : fmtDate(x['prochaine_visite'])),
                ],
              ))
            ),
          for (final s in repo.soinsOf(patientId))
            (
              date: '${s['date_acte']} 00:00:00',
              tile: Card(
                  child: ListTile(
                leading: const Icon(Icons.vaccines_outlined),
                title: Text('${s['libelle']}'),
                subtitle: Text('${typesSoin['${s['type']}'] ?? ''} · ${fmtDate(s['date_acte'])}${s['numero_lot'] != null && '${s['numero_lot']}'.isNotEmpty ? ' · lot ${s['numero_lot']}' : ''}'
                    '${s['rappel_le'] != null ? '\nRappel ${fmtDate(s['rappel_le'])} (${s['rappel_statut']})' : ''}'),
                isThreeLine: s['rappel_le'] != null,
              ))
            ),
        ]..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(title: Text('${p['nom']}')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            KeyValue('Propriétaire', repo.client(p['client_id'])?['nom']),
            KeyValue('Espèce', especes['${p['espece']}']),
            KeyValue('Race', p['race']),
            KeyValue('Sexe', sexes['${p['sexe']}']),
            KeyValue('Naissance', p['date_naissance'] == null ? null : fmtDate(p['date_naissance'])),
            KeyValue('Identification', p['identification']),
            if (p['type'] == 'groupe') KeyValue('Effectif', p['effectif']),
            KeyValue('Dernier poids', p['poids_kg'] == null ? null : '${p['poids_kg']} kg'),
            KeyValue('Notes', p['notes']),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.tonalIcon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ConsultationForm(repo: repo, patient: p))), icon: const Icon(Icons.medical_information_outlined), label: const Text('Consultation')),
              FilledButton.tonalIcon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SoinForm(repo: repo, patient: p))), icon: const Icon(Icons.vaccines_outlined), label: const Text('Soin / vaccin')),
              FilledButton.tonalIcon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RdvForm(repo: repo, patient: p))), icon: const Icon(Icons.event), label: const Text('Rendez-vous')),
            ]),
            const SizedBox(height: 16),
            Text('Historique', style: Theme.of(c).textTheme.titleMedium),
            if (hist.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aucun acte enregistré.')),
            for (final h in hist) h.tile,
          ]),
        );
      });
}

// ── Rendez-vous ──────────────────────────────────────────────────────
class RdvTile extends StatelessWidget {
  const RdvTile(this.r, {super.key, required this.repo, this.showClient = true});
  final Map<String, dynamic> r;
  final VetRepo repo;
  final bool showClient;
  @override
  Widget build(BuildContext context) {
    final cl = repo.client(r['client_id']), pa = repo.patient(r['patient_id']);
    final st = '${r['statut']}';
    final color = {'confirme': Colors.green, 'fait': Colors.blueGrey, 'annule': Colors.red}[st];
    return Card(
      child: ListTile(
        leading: Icon(Icons.event, color: color),
        title: Text('${fmtDateTime(r['debut'])} · ${r['duree_min']} min'),
        subtitle: Text([if (showClient) cl?['nom'], pa?['nom'], r['motif']].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
        trailing: r['pending'] == true
            ? const Icon(Icons.cloud_upload_outlined)
            : PopupMenuButton<String>(
                icon: Chip(label: Text(statutsRdv[st] ?? st), backgroundColor: color?.withValues(alpha: 0.15)),
                onSelected: (v) => repo.setStatus('rdv.statut', r['id'] as Object, v),
                itemBuilder: (_) => [for (final e in statutsRdv.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
              ),
      ),
    );
  }
}

class RdvPage extends StatelessWidget {
  const RdvPage({super.key, required this.repo});
  final VetRepo repo;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: _rebuild(repo, (c) {
          final from = isoDate(DateTime.now().subtract(const Duration(days: 1)));
          final list = [for (final r in repo.rdv) if ('${r['debut']}'.compareTo(from) >= 0 && r['statut'] != 'annule') r];
          return Column(children: [
            SyncBanner(repo),
            Expanded(
              child: list.isEmpty
                  ? const EmptyView('Aucun rendez-vous à venir.', icon: Icons.event_busy)
                  : ListView(children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i == 0 || '${list[i]['debut']}'.substring(0, 10) != '${list[i - 1]['debut']}'.substring(0, 10))
                          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(fmtDate('${list[i]['debut']}'.substring(0, 10)), style: const TextStyle(fontWeight: FontWeight.bold))),
                        RdvTile(list[i], repo: repo),
                      ],
                      const SizedBox(height: 80),
                    ]),
            ),
          ]);
        }),
        floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RdvForm(repo: repo))), child: const Icon(Icons.add)),
      );
}

// ── Produits ─────────────────────────────────────────────────────────
class ProduitsPage extends StatefulWidget {
  const ProduitsPage({super.key, required this.repo});
  final VetRepo repo;
  @override
  State<ProduitsPage> createState() => _ProduitsPageState();
}

class _ProduitsPageState extends State<ProduitsPage> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final list = [for (final p in widget.repo.produits) if ('${p['nom']}'.toLowerCase().contains(_q.toLowerCase())) p];
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacie')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Rechercher un produit'), onChanged: (v) => setState(() => _q = v))),
        Expanded(
          child: list.isEmpty
              ? const EmptyView('Aucun produit.')
              : ListView(children: [
                  for (final p in list)
                    Card(
                        child: ListTile(
                      title: Text('${p['nom']}'),
                      subtitle: Text('${fmtNum(p['prix_vente'], digits: 0)} / ${p['unite'] ?? 'unité'}'),
                      trailing: Text('Stock ${fmtNum(p['stock'], digits: 1)}', style: TextStyle(fontWeight: FontWeight.bold, color: (num.tryParse('${p['stock']}') ?? 0) <= 0 ? Colors.red : null)),
                    )),
                ]),
        ),
      ]),
    );
  }
}

// ── File d'attente ───────────────────────────────────────────────────
class SyncPage extends StatelessWidget {
  const SyncPage({super.key, required this.repo});
  final VetRepo repo;
  @override
  Widget build(BuildContext context) => _rebuild(repo, (c) => Scaffold(
        appBar: AppBar(title: const Text('Synchronisation'), actions: [IconButton(icon: const Icon(Icons.sync), onPressed: repo.syncing ? null : repo.retryAll)]),
        body: Column(children: [
          if (repo.syncing) const LinearProgressIndicator(),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: Text(repo.lastSync == null ? 'Jamais synchronisé' : 'Dernière synchronisation : ${fmtDateTime(repo.lastSync!.toIso8601String())}'),
            subtitle: repo.lastSyncError != null ? Text(repo.lastSyncError!) : null,
          ),
          const Divider(height: 1),
          Expanded(
            child: repo.queue.isEmpty
                ? const EmptyView('Aucune saisie en attente.', icon: Icons.cloud_done_outlined)
                : ListView(children: [
                    for (final o in repo.queue)
                      ListTile(
                        leading: Icon(o.state == 'erreur' ? Icons.error_outline : Icons.schedule, color: o.state == 'erreur' ? Colors.red : null),
                        title: Text(o.label),
                        subtitle: Text('${fmtDateTime(o.createdAt)}${o.message != null ? '\n${o.message}' : ''}'),
                        isThreeLine: o.message != null,
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                  context: c,
                                  builder: (_) => AlertDialog(title: const Text('Supprimer cette saisie ?'), content: const Text('Elle ne sera jamais envoyée au serveur.'), actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Garder')),
                                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
                                      ]));
                              if (ok == true) repo.discard(o.ref);
                            }),
                      ),
                  ]),
          ),
        ]),
      ));
}
