import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import 'module_pages.dart';
import 'spec.dart';

/// Pesée de tous les animaux présents d'un lot d'embouche.
class FatteningWeighingPage extends ConsumerStatefulWidget {
  const FatteningWeighingPage({super.key, required this.lotId});
  final Object? lotId;
  @override
  ConsumerState<FatteningWeighingPage> createState() => _FatteningWeighingPageState();
}

class _FatteningWeighingPageState extends ConsumerState<FatteningWeighingPage> {
  DateTime _jour = DateTime.now();
  List<Map<String, dynamic>> _animaux = [];
  final _ctl = <int, TextEditingController>{};
  bool _loading = true, _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiProvider).get<Map>('/fattening/${widget.lotId}');
      _animaux = [for (final a in (d['animaux'] as List)) if ((a as Map)['statut'] == 'present') Map<String, dynamic>.from(a)];
      for (final a in _animaux) {
        _ctl[a['id'] as int] = TextEditingController();
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final poids = <String, dynamic>{};
    for (final e in _ctl.entries) {
      final v = num.tryParse(e.value.text.trim().replaceAll(',', '.'));
      if (v != null && v > 0) poids['${e.key}'] = v;
    }
    if (poids.isEmpty) {
      showInfo(context, 'Aucun poids saisi.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).post('/fattening/${widget.lotId}/weighing', body: {'jour': isoDate(_jour), 'poids': poids});
      if (!mounted) return;
      showInfo(context, 'Pesées enregistrées.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pesée du lot')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorView(_error!)
                : Column(children: [
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(fmtDate(isoDate(_jour))),
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: _jour, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now());
                        if (d != null) setState(() => _jour = d);
                      },
                    ),
                    Expanded(
                      child: ListView(children: [
                        for (final a in _animaux)
                          ListTile(
                            title: Text('${a['numero']}${a['nom'] != null ? ' · ${a['nom']}' : ''}'),
                            subtitle: a['poids'] != null ? Text('Dernier poids : ${fmtNum(a['poids'], digits: 0)} kg') : null,
                            trailing: SizedBox(width: 110, child: TextField(controller: _ctl[a['id']], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'kg', isDense: true))),
                          ),
                      ]),
                    ),
                    Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Enregistrer les pesées')))),
                  ]),
      );
}

/// Poules pondeuses : stock d'œufs par site, lots et taux de ponte.
class LayingPage extends ConsumerStatefulWidget {
  const LayingPage({super.key});
  @override
  ConsumerState<LayingPage> createState() => _LayingPageState();
}

class _LayingPageState extends ConsumerState<LayingPage> {
  Key _k = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final canWrite = const {'admin', 'siege', 'responsable'}.contains(ref.watch(sessionProvider).value?.role);
    return Scaffold(
      appBar: AppBar(title: const Text('Poules pondeuses')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.egg_outlined),
              label: const Text('Perte / ajustement'),
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DynamicFormPage(title: 'Perte d\'œufs', successMessage: 'Mouvement enregistré.', submit: (b) => api.post('/laying/loss', body: b), fields: const [
                              FieldSpec('site_id', 'Site', type: FieldType.select, optionsPath: '/farm/sites', hint: 'Laissez vide si votre compte est rattaché à un site'),
                              FieldSpec('type', 'Type', type: FieldType.select, required: true, options: {'casse_stockage': 'Casse au stockage', 'don': 'Don', 'consommation': 'Consommation interne', 'ajustement': 'Ajustement d\'inventaire'}),
                              FieldSpec('oeufs', 'Nombre d\'œufs', type: FieldType.integer, required: true, hint: 'Négatif possible pour un ajustement'),
                              FieldSpec('note', 'Note'),
                            ])));
                if (ok == true && mounted) setState(() => _k = UniqueKey());
              })
          : null,
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/laying'),
        builder: (c, d) {
          final lots = (d['lots'] as List).cast<Map>(), stocks = (d['stocks'] as List).cast<Map>();
          if (lots.isEmpty) return ListView(children: const [SizedBox(height: 300, child: EmptyView('Aucun lot pondeuse actif.'))]);
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
            for (final s in stocks) Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text('Stock d\'œufs — ${s['site']}'), subtitle: Text('${fmtNum(s['plateaux'], digits: 1)} plateaux'), trailing: Text(fmtNum(s['oeufs']), style: const TextStyle(fontWeight: FontWeight.bold)))),
            for (final l in lots)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.egg_alt_outlined),
                  title: Text('${l['code']} · ${l['age_sem']} sem.'),
                  subtitle: Text('Taux 7 j : ${l['ind']?['taux_7j'] ?? '—'} % · référence ${l['taux_ref'] ?? '—'} %${l['retrait'] != null ? '\n⚠ œufs sous délai d\'attente' : ''}'),
                  isThreeLine: l['retrait'] != null,
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => LayingLotPage(id: l['id'] as int))),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class LayingLotPage extends ConsumerWidget {
  const LayingLotPage({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ponte du lot')),
      body: AsyncView<Map>(
        load: () => api.get<Map>('/laying/$id'),
        builder: (c, l) {
          final ind = Map<String, dynamic>.from(l['ind'] as Map? ?? {});
          final h = (l['historique'] as List).cast<Map>().reversed.toList();
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
            Text('${l['code']}', style: Theme.of(c).textTheme.titleLarge),
            KeyValue('Site', l['site_nom']),
            KeyValue('Âge', '${l['age_sem']} semaines'),
            KeyValue('Courbe de référence', l['courbe_libelle']),
            KeyValue('Taux de ponte (7 j)', ind['taux_7j'] == null ? null : '${ind['taux_7j']} %'),
            KeyValue('Casse (7 j)', ind['casse_7j_pct'] == null ? null : '${ind['casse_7j_pct']} %'),
            KeyValue('Pic', ind['pic'] == null ? null : '${ind['pic']} % (semaine ${ind['pic_age']})'),
            KeyValue('Œufs par poule', ind['par_poule']),
            KeyValue('Coût du plateau', ind['cout_plateau'] == null ? null : '${fmtNum(ind['cout_plateau'])} F'),
            if (l['retrait'] != null) Card(color: Theme.of(c).colorScheme.errorContainer, child: ListTile(leading: const Icon(Icons.warning_amber), title: const Text('Œufs sous délai d\'attente'), subtitle: Text('Jusqu\'au ${fmtDate((l['retrait'] as Map)['jusqu_au'])}'))),
            const Divider(height: 28),
            Text('Dernières journées', style: Theme.of(c).textTheme.titleMedium),
            for (final r in h.take(30))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(fmtDate(r['date_rapport'])),
                subtitle: Text('${fmtNum(r['ramasses'])} ramassés · ${fmtNum(r['casses'])} cassés · ${fmtNum(r['vendables'])} vendables'),
                trailing: Text('${r['taux']} %', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ]);
        },
      ),
    );
  }
}

/// Capteurs : dernière lecture, historique récent et saisie manuelle.
class IotPage extends ConsumerStatefulWidget {
  const IotPage({super.key});
  @override
  ConsumerState<IotPage> createState() => _IotPageState();
}

class _IotPageState extends ConsumerState<IotPage> {
  Key _k = UniqueKey();
  int? _site;
  List<Map<String, dynamic>> _sites = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final p = await ref.read(sessionProvider.future);
    try {
      _sites = [for (final s in await ref.read(apiProvider).get<List>('/farm/sites')) Map<String, dynamic>.from(s as Map)];
    } catch (_) {}
    _site = (p?.allSites ?? false) ? (_sites.isNotEmpty ? _sites.first['id'] as int : null) : p?.siteId;
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final role = ref.watch(sessionProvider).value?.role ?? '';
    final canWrite = const {'admin', 'responsable', 'employe'}.contains(role);
    final allSites = ref.watch(sessionProvider).value?.allSites ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Ambiance du bâtiment')),
      floatingActionButton: canWrite && _site != null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Relevé'),
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DynamicFormPage(title: 'Relevé manuel', successMessage: 'Relevé enregistré.', submit: (b) => api.post('/iot/readings', body: {...b, if (allSites) 'site_id': _site}), fields: const [
                              FieldSpec('temperature', 'Température', type: FieldType.number, suffix: '°C'),
                              FieldSpec('hygrometrie', 'Humidité', type: FieldType.number, suffix: '%', min: 0),
                              FieldSpec('co2', 'CO₂', type: FieldType.number, suffix: 'ppm', min: 0),
                              FieldSpec('nh3', 'NH₃ (ammoniac)', type: FieldType.number, suffix: 'ppm', min: 0),
                            ])));
                if (ok == true && mounted) setState(() => _k = UniqueKey());
              })
          : null,
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _site == null
              ? const EmptyView('Aucun site.')
              : Column(children: [
                  if (allSites && _sites.length > 1)
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: DropdownButtonFormField<int>(
                            initialValue: _site,
                            decoration: const InputDecoration(labelText: 'Site'),
                            items: [for (final s in _sites) DropdownMenuItem(value: s['id'] as int, child: Text('${s['nom']}'))],
                            onChanged: (v) => setState(() {
                                  _site = v;
                                  _k = UniqueKey();
                                }))),
                  Expanded(
                    child: AsyncView<Map>(
                      key: _k,
                      load: () => api.get<Map>('/iot/readings', query: {'site_id': _site}),
                      builder: (c, d) {
                        final last = d['derniere'] as Map?;
                        final hist = (d['historique'] as List).cast<Map>().reversed.toList();
                        return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
                          if (last == null) const SizedBox(height: 200, child: EmptyView('Aucun relevé.', icon: Icons.thermostat)),
                          if (last != null)
                            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.9, padding: const EdgeInsets.all(4), children: [
                              Stat('Température', last['temperature'] == null ? '—' : '${fmtNum(last['temperature'], digits: 1)} °C', icon: Icons.thermostat),
                              Stat('Humidité', last['hygrometrie'] == null ? '—' : '${fmtNum(last['hygrometrie'], digits: 0)} %', icon: Icons.water_drop_outlined),
                              Stat('CO₂', last['co2'] == null ? '—' : '${last['co2']} ppm', icon: Icons.cloud_outlined),
                              Stat('NH₃', last['nh3'] == null ? '—' : '${fmtNum(last['nh3'], digits: 1)} ppm', icon: Icons.air),
                            ]),
                          if (last != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('Dernier relevé : ${fmtDateTime(last['created_at'])}', style: Theme.of(c).textTheme.bodySmall)),
                          const Padding(padding: EdgeInsets.fromLTRB(12, 16, 12, 4), child: Text('Dernières 24 h', style: TextStyle(fontWeight: FontWeight.bold))),
                          for (final r in hist.take(40))
                            ListTile(dense: true, title: Text(fmtDateTime(r['created_at'])), subtitle: Text([if (r['temperature'] != null) '${r['temperature']} °C', if (r['hygrometrie'] != null) '${r['hygrometrie']} %', if (r['co2'] != null) 'CO₂ ${r['co2']}', if (r['nh3'] != null) 'NH₃ ${r['nh3']}'].join(' · '))),
                        ]);
                      },
                    ),
                  ),
                ]),
    );
  }
}
