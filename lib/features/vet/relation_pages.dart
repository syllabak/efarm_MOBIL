import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import '../modules/data_view.dart';
import '../modules/module_pages.dart';
import '../modules/spec.dart';

String _join(Iterable<Object?> parts, [String sep = ' · ']) => parts.where((e) => e != null && '$e'.isNotEmpty).join(sep);

const _statutsRelation = {'actif': 'Active', 'invitation_envoyee': 'Invitation reçue', 'demande_envoyee': 'Demande envoyée', 'refuse': 'Refusée', 'retire': 'Retirée'};
const _gravites = {'info': 'Information', 'important': 'Important', 'urgent': 'Urgent'};

// ══ Côté vétérinaire : fermes suivies ═════════════════════════════════
class VetFarmsPage extends ConsumerStatefulWidget {
  const VetFarmsPage({super.key});
  @override
  ConsumerState<VetFarmsPage> createState() => _VetFarmsPageState();
}

class _VetFarmsPageState extends ConsumerState<VetFarmsPage> {
  Key _k = UniqueKey();

  Future<void> _answer(Map f, bool yes) async {
    try {
      await ref.read(apiProvider).post('/vet/farms/${f['id']}/respond', body: {'accepter': yes});
      if (mounted) setState(() => _k = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes fermes')),
      body: AsyncView<List>(
        key: _k,
        load: () => api.get<List>('/vet/farms'),
        builder: (c, rows) => rows.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: EmptyView('Aucune ferme pour le moment.', icon: Icons.agriculture))])
            : ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                for (final f in rows.cast<Map>())
                  Card(
                    child: Column(children: [
                      ListTile(
                        leading: const Icon(Icons.agriculture),
                        title: Text('${f['societe_nom']}'),
                        subtitle: Text(_join([f['ville'], _statutsRelation['${f['statut']}']])),
                        trailing: f['statut'] == 'actif' ? const Icon(Icons.chevron_right) : null,
                        onTap: f['statut'] == 'actif' ? () => Navigator.push(c, MaterialPageRoute(builder: (_) => VetFarmPage(societeId: int.parse('${f['societe_id']}'), name: '${f['societe_nom']}'))) : null,
                      ),
                      if (f['statut'] == 'invitation_envoyee')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(children: [
                            Expanded(child: FilledButton(onPressed: () => _answer(f, true), child: const Text('Accepter'))),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton(onPressed: () => _answer(f, false), child: const Text('Refuser'))),
                          ]),
                        ),
                    ]),
                  ),
              ]),
      ),
    );
  }
}

class VetFarmPage extends ConsumerStatefulWidget {
  const VetFarmPage({super.key, required this.societeId, required this.name});
  final int societeId;
  final String name;
  @override
  ConsumerState<VetFarmPage> createState() => _VetFarmPageState();
}

class _VetFarmPageState extends ConsumerState<VetFarmPage> {
  Key _k = UniqueKey();

  List<FieldSpec> _docFields(List lots) => [
        const FieldSpec('type', 'Type', type: FieldType.select, required: true, initial: 'rapport', options: {'rapport': 'Rapport sanitaire', 'ordonnance': 'Ordonnance', 'instruction': 'Instruction'}),
        FieldSpec('lot_id', 'Lot concerné', type: FieldType.select, options: {for (final l in lots.cast<Map>()) '${l['id']}': '${l['code']} · ${l['site_nom']}'}),
        const FieldSpec('titre', 'Titre', required: true),
        const FieldSpec('diagnostic', 'Diagnostic'),
        const FieldSpec('contenu', 'Contenu', type: FieldType.multiline),
        const FieldSpec('medicaments', 'Médicaments', type: FieldType.lines, lineFields: [
          FieldSpec('nom', 'Médicament'),
          FieldSpec('dosage', 'Dosage'),
          FieldSpec('voie', 'Voie'),
          FieldSpec('duree', 'Durée'),
        ]),
        const FieldSpec('delai_attente_jours', 'Délai d\'attente viande', type: FieldType.integer, suffix: 'jours', min: 0),
        const FieldSpec('delai_oeufs_jours', 'Délai d\'attente œufs', type: FieldType.integer, suffix: 'jours', min: 0),
        const FieldSpec('gravite', 'Gravité', type: FieldType.select, initial: 'info', options: _gravites),
        const FieldSpec('sms', 'Prévenir aussi par SMS', type: FieldType.bool),
      ];

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/vet/farms/${widget.societeId}'),
        builder: (c, d) {
          final lots = (d['lots'] as List).cast<Map>(), causes = (d['causes'] as List).cast<Map>(), docs = (d['documents'] as List).cast<Map>(), alertes = (d['alertes'] as List).cast<Map>();
          final bov = d['bovins'] as Map?;
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                  icon: const Icon(Icons.post_add),
                  label: const Text('Émettre un document'),
                  onPressed: () async {
                    final ok = await Navigator.push<bool>(
                        c,
                        MaterialPageRoute(
                            builder: (_) => DynamicFormPage(title: 'Nouveau document', successMessage: 'Document émis, la ferme est prévenue.', fields: _docFields(lots), submit: (b) => api.post('/vet/farms/${widget.societeId}/documents', body: b))));
                    if (ok == true && mounted) setState(() => _k = UniqueKey());
                  }),
              OutlinedButton.icon(
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Messages'),
                  onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RelationThreadPage(path: '/vet/messages/${widget.societeId}', title: widget.name, mySens: 'veto')))),
              if (bov != null)
                OutlinedButton.icon(
                    icon: const Icon(Icons.vaccines_outlined),
                    label: const Text('Acte sur un bovin'),
                    onPressed: () async {
                      final animaux = (bov['animaux'] as List).cast<Map>();
                      final ok = await Navigator.push<bool>(
                          c,
                          MaterialPageRoute(
                              builder: (_) => DynamicFormPage(title: 'Acte sur un bovin', successMessage: 'Acte enregistré, la ferme est prévenue.', submit: (b) => api.post('/vet/farms/${widget.societeId}/cattle-event', body: b), fields: [
                                    FieldSpec('animal_id', 'Animal', type: FieldType.select, required: true, options: {for (final a in animaux) '${a['id']}': '${a['numero']}${a['nom'] != null ? ' · ${a['nom']}' : ''}'}),
                                    const FieldSpec('type', 'Acte', type: FieldType.select, required: true, options: {'soin': 'Soin / traitement', 'vaccin': 'Vaccination', 'vermifuge': 'Vermifuge', 'diag_gestation': 'Diagnostic de gestation', 'note': 'Observation'}),
                                    const FieldSpec('date_event', 'Date', type: FieldType.date, initial: 'today'),
                                    const FieldSpec('detail', 'Détail (produit, résultat…)'),
                                    const FieldSpec('rappel_le', 'Rappel le', type: FieldType.date),
                                    const FieldSpec('delai_lait_j', 'Délai d\'attente lait', type: FieldType.integer, suffix: 'jours', min: 0),
                                    const FieldSpec('delai_viande_j', 'Délai d\'attente viande', type: FieldType.integer, suffix: 'jours', min: 0),
                                  ])));
                      if (ok == true && mounted) setState(() => _k = UniqueKey());
                    }),
            ]),
            const Padding(padding: EdgeInsets.fromLTRB(8, 16, 8, 4), child: Text('Lots actifs', style: TextStyle(fontWeight: FontWeight.bold))),
            if (lots.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aucun lot actif.')),
            for (final l in lots)
              Card(
                child: ListTile(
                  leading: Icon(Icons.egg_alt_outlined, color: (l['mort_7j_pct'] as num) >= 1 ? Colors.red : null),
                  title: Text('${l['code']} · ${l['race'] ?? ''}'),
                  subtitle: Text('${l['site_nom']} · ${fmtNum(l['nb_actuel'])} têtes\nMortalité 7 j : ${l['mort_7j']} (${l['mort_7j_pct']} %) · cumul ${l['mort_cumul_pct']} %'),
                  isThreeLine: true,
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DataPage(title: 'Lot ${l['code']}', path: '/vet/farms/${widget.societeId}/lots/${l['id']}'))),
                ),
              ),
            if (causes.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(8, 16, 8, 4), child: Text('Causes de mortalité (30 jours)', style: TextStyle(fontWeight: FontWeight.bold))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Wrap(spacing: 6, children: [for (final x in causes) Chip(label: Text('${x['cause']} : ${x['q']}'))])),
            ],
            if (alertes.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(8, 16, 8, 4), child: Text('Alertes récentes', style: TextStyle(fontWeight: FontWeight.bold))),
              for (final a in alertes) ListTile(dense: true, leading: const Icon(Icons.warning_amber), title: Text('${a['message'] ?? a['type']}'), subtitle: Text(_join([a['lot_code'], fmtDateTime(a['created_at'])]))),
            ],
            const Padding(padding: EdgeInsets.fromLTRB(8, 16, 8, 4), child: Text('Mes documents', style: TextStyle(fontWeight: FontWeight.bold))),
            if (docs.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aucun document émis.')),
            for (final x in docs) ListTile(dense: true, leading: const Icon(Icons.description_outlined), title: Text('${x['titre']}'), subtitle: Text(_join([x['type'], _gravites['${x['gravite']}'], x['lot_code'], fmtDate(x['created_at'])])), trailing: Text('${x['statut']}')),
            const SizedBox(height: 40),
          ]);
        },
      ),
    );
  }
}

// ══ Messagerie ferme ↔ vétérinaire (les deux côtés) ═══════════════════
class RelationConversationsPage extends ConsumerWidget {
  const RelationConversationsPage({super.key, required this.listPath, required this.threadBase, required this.mySens, required this.title, required this.name});
  final String listPath, threadBase, mySens, title;
  final String Function(Map) name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncView<List>(
        load: () => api.get<List>(listPath),
        builder: (c, rows) => rows.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: EmptyView('Aucune conversation : il faut une collaboration active.'))])
            : ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                for (final r in rows.cast<Map>())
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name(r), style: TextStyle(fontWeight: (int.tryParse('${r['non_lus']}') ?? 0) > 0 ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('${r['dernier'] ?? r['dernier_message'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: (int.tryParse('${r['non_lus']}') ?? 0) > 0 ? Badge(label: Text('${r['non_lus']}')) : null,
                    onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RelationThreadPage(path: '$threadBase/${r['id']}', title: name(r), mySens: mySens))),
                  ),
              ]),
      ),
    );
  }
}

class RelationThreadPage extends ConsumerStatefulWidget {
  const RelationThreadPage({super.key, required this.path, required this.title, required this.mySens});
  final String path, title, mySens;
  @override
  ConsumerState<RelationThreadPage> createState() => _RelationThreadPageState();
}

class _RelationThreadPageState extends ConsumerState<RelationThreadPage> {
  final _items = <Map<String, dynamic>>[];
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  bool _loading = true, _sending = false;
  Object? _error;
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _poll(first: true);
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _poll({bool first = false}) async {
    try {
      final rows = [for (final m in await ref.read(apiProvider).get<List>(widget.path, query: {if (_last > 0) 'depuis': _last})) Map<String, dynamic>.from(m as Map)];
      if (!mounted) return;
      if (rows.isNotEmpty) {
        setState(() {
          _items.addAll(rows.where((m) => !_items.any((x) => x['id'] == m['id'])));
          _last = _items.map((m) => m['id'] as int).reduce((a, b) => a > b ? a : b);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
      if (first) setState(() => _loading = false);
    } catch (e) {
      if (first && mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final t = _ctl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiProvider).post(widget.path, body: {'corps': t});
      _ctl.clear();
      await _poll();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorView(_error!)
                : Column(children: [
                    Expanded(
                      child: _items.isEmpty
                          ? const EmptyView('Aucun message.')
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(8),
                              itemCount: _items.length,
                              itemBuilder: (c, i) {
                                final m = _items[i];
                                final moi = m['sens'] == widget.mySens;
                                final scheme = Theme.of(c).colorScheme;
                                return Align(
                                  alignment: moi ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width * 0.78),
                                    margin: const EdgeInsets.symmetric(vertical: 3),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: moi ? scheme.primaryContainer : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      if (!moi) Text('${m['auteur'] ?? ''}', style: Theme.of(c).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                      if (m['piece_type'] != null) Text(m['piece_type'] == 'audio' ? '🎤 Note vocale (sur le site web)' : '📷 Photo (sur le site web)', style: const TextStyle(fontStyle: FontStyle.italic)),
                                      if (m['corps'] != null) Text('${m['corps']}'),
                                      Text(fmtDateTime(m['created_at']), style: Theme.of(c).textTheme.labelSmall),
                                    ]),
                                  ),
                                );
                              }),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(children: [
                          Expanded(child: TextField(controller: _ctl, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: tr('Votre message'), isDense: true), onSubmitted: (_) => _send())),
                          const SizedBox(width: 6),
                          IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
                        ]),
                      ),
                    ),
                  ]),
      );
}

// ══ Côté ferme : vétérinaires et documents reçus ══════════════════════
final farmVetsModule = ModuleSpec(
  id: 'farm_vets',
  title: 'Mes vétérinaires',
  icon: Icons.medical_services_outlined,
  plan: 'veterinaire',
  roles: const {'admin', 'siege', 'responsable'},
  listPath: '/vets',
  listIsPlain: true,
  itemTitle: (r) => _join([r['prenom'], r['nom']], ' '),
  itemSubtitle: (r) => _join([r['nom_cabinet'], r['telephone'], _statutsRelation['${r['statut']}']]),
  emptyText: 'Aucun vétérinaire. Invitez le vôtre depuis le site web.',
);

final farmVetDocsModule = ModuleSpec(
  id: 'farm_vet_docs',
  title: 'Documents du vétérinaire',
  icon: Icons.description_outlined,
  plan: 'veterinaire',
  roles: const {'admin', 'siege', 'responsable'},
  listPath: '/vets/documents',
  listIsPlain: true,
  itemTitle: (r) => '${r['titre']}',
  itemSubtitle: (r) => _join([r['type'], _gravites['${r['gravite']}'], r['lot_code'], r['veto_nom'], fmtDate(r['created_at'])]),
  itemTrailing: (r) => r['statut'] == 'emis' ? 'Nouveau' : '${r['statut']}',
  detailPath: '/vets/documents/{id}',
  detailTitle: (r) => '${r['titre']}',
  detail: const [
    ColumnSpec('type', 'Type', fmt: Fmt.label, labels: {'rapport': 'Rapport sanitaire', 'ordonnance': 'Ordonnance', 'instruction': 'Instruction'}),
    ColumnSpec('gravite', 'Gravité', fmt: Fmt.label, labels: _gravites),
    ColumnSpec('veto_nom', 'Vétérinaire'),
    ColumnSpec('lot_code', 'Lot'),
    ColumnSpec('diagnostic', 'Diagnostic'),
    ColumnSpec('contenu', 'Contenu'),
    ColumnSpec('delai_attente_jours', 'Délai d\'attente viande (jours)', fmt: Fmt.number),
    ColumnSpec('delai_oeufs_jours', 'Délai d\'attente œufs (jours)', fmt: Fmt.number),
    ColumnSpec('created_at', 'Émis le', fmt: Fmt.dateTime),
    ColumnSpec('statut', 'Statut', fmt: Fmt.label, labels: {'emis': 'À lire', 'lu': 'Lu', 'applique': 'Appliqué'}),
  ],
  sections: [
    SectionSpec('medicaments', 'Traitement prescrit', (r) => '${r['nom']}', itemSubtitle: (r) => _join([r['dosage'], r['voie'], if ((r['duree'] ?? '') != '') 'pendant ${r['duree']}'])),
  ],
  actions: [
    ActionSpec('Marquer comme appliqué', '/vets/documents/{id}/applied', icon: Icons.task_alt, visible: (r) => r['statut'] != 'applique', confirm: 'Confirmer que ce document a été appliqué ?', successMessage: 'Marqué comme appliqué.'),
  ],
  emptyText: 'Aucun document reçu.',
);
