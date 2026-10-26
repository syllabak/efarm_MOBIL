import 'package:flutter/material.dart' hide Text;
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';

/// Tableau de bord du troupeau : effectifs, reproduction, lait et alertes.
class CattleSummaryPage extends ConsumerWidget {
  const CattleSummaryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bovins — tableau de bord')),
      body: AsyncView<Map>(
        load: () => api.get<Map>('/cattle/summary'),
        builder: (c, d) {
          final i = Map<String, dynamic>.from(d['indicateurs'] as Map);
          final lait = Map<String, dynamic>.from(i['lait'] as Map);
          final cats = Map<String, dynamic>.from(i['categories'] as Map? ?? {});
          final alertes = (d['alertes'] as List).cast<Map>();
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.7, padding: const EdgeInsets.all(4), children: [
              Stat('Effectif', fmtNum(i['total']), icon: Icons.pets),
              Stat('Femelles / mâles', '${i['femelles']} / ${i['males']}', icon: Icons.wc),
              Stat('Gestantes', fmtNum(i['gestantes']), icon: Icons.child_friendly_outlined),
              Stat('En lactation', fmtNum(i['lactation']), icon: Icons.local_drink_outlined),
              Stat('Lait (dernier jour)', '${fmtNum(lait['litres'], digits: 1)} L', icon: Icons.opacity),
              Stat('Lait du mois', '${fmtNum(lait['mois'], digits: 0)} L', icon: Icons.calendar_month),
              Stat('GMQ moyen', i['gmq_moyen'] == null ? '—' : '${i['gmq_moyen']} g/j', icon: Icons.trending_up),
              Stat('Mortalité 12 mois', '${fmtNum(i['mortalite_pct'], digits: 1)} %', icon: Icons.heart_broken_outlined),
            ]),
            if (cats.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 4), child: Text('Catégories', style: TextStyle(fontWeight: FontWeight.bold))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Wrap(spacing: 8, children: [for (final e in cats.entries) Chip(label: Text('${e.key} : ${e.value}'))])),
            ],
            const Padding(padding: EdgeInsets.fromLTRB(12, 16, 12, 4), child: Text('Alertes', style: TextStyle(fontWeight: FontWeight.bold))),
            if (alertes.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Aucune alerte.')),
            for (final a in alertes)
              Card(child: ListTile(leading: Icon(Icons.warning_amber, color: {'red': Colors.red, 'amber': Colors.orange, 'blue': Colors.blue}['${a['niveau']}']), title: Text('${a['texte']}'))),
          ]);
        },
      ),
    );
  }
}

/// Saisie de la traite du jour : une ligne par vache (matin / soir).
class CattleMilkPage extends ConsumerStatefulWidget {
  const CattleMilkPage({super.key});
  @override
  ConsumerState<CattleMilkPage> createState() => _CattleMilkPageState();
}

class _CattleMilkPageState extends ConsumerState<CattleMilkPage> {
  DateTime _jour = DateTime.now();
  List<Map<String, dynamic>> _vaches = [];
  final _matin = <int, TextEditingController>{}, _soir = <int, TextEditingController>{};
  bool _loading = true, _saving = false;
  Object? _error;
  num _prix = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._matin.values, ..._soir.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref.read(apiProvider).get<Map>('/cattle/milk', query: {'jour': isoDate(_jour)});
      _vaches = [for (final v in (d['vaches'] as List)) Map<String, dynamic>.from(v as Map)];
      _prix = d['prix_litre'] as num? ?? 0;
      for (final v in _vaches) {
        final id = v['id'] as int;
        _matin[id] = TextEditingController(text: v['matin'] == null ? '' : '${v['matin']}');
        _soir[id] = TextEditingController(text: v['soir'] == null ? '' : '${v['soir']}');
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  num get _total => _vaches.fold<num>(0, (a, v) => a + (num.tryParse(_matin[v['id']]!.text.replaceAll(',', '.')) ?? 0) + (num.tryParse(_soir[v['id']]!.text.replaceAll(',', '.')) ?? 0));

  Future<void> _save() async {
    final lignes = <String, dynamic>{};
    for (final v in _vaches) {
      final id = v['id'] as int;
      final m = num.tryParse(_matin[id]!.text.replaceAll(',', '.')), s = num.tryParse(_soir[id]!.text.replaceAll(',', '.'));
      if (m == null && s == null) continue;
      lignes['$id'] = {'matin': m, 'soir': s};
    }
    if (lignes.isEmpty) {
      showInfo(context, 'Aucune quantité saisie.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).post('/cattle/milk', body: {'jour': isoDate(_jour), 'lignes': lignes});
      if (!mounted) return;
      showInfo(context, 'Traite enregistrée.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionProvider).value?.role ?? '';
    final canWrite = const {'admin', 'siege', 'responsable'}.contains(role);
    return Scaffold(
      appBar: AppBar(title: const Text('Traite')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : Column(children: [
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(fmtDate(isoDate(_jour))),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _jour, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now());
                      if (d != null) {
                        _jour = d;
                        _load();
                      }
                    },
                  ),
                  Expanded(
                    child: _vaches.isEmpty
                        ? const EmptyView('Aucune vache en lactation.')
                        : ListView.builder(
                            itemCount: _vaches.length,
                            itemBuilder: (c, i) {
                              final v = _vaches[i], id = v['id'] as int;
                              return ListTile(
                                title: Text('${v['numero']}${v['nom'] != null ? ' · ${v['nom']}' : ''}'),
                                subtitle: v['jours_lactation'] != null ? Text('Jour ${v['jours_lactation']} de lactation') : null,
                                trailing: SizedBox(
                                  width: 170,
                                  child: Row(children: [
                                    Expanded(child: TextField(controller: _matin[id], enabled: canWrite, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Matin'), isDense: true))),
                                    const SizedBox(width: 8),
                                    Expanded(child: TextField(controller: _soir[id], enabled: canWrite, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Soir'), isDense: true))),
                                  ]),
                                ),
                              );
                            }),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(child: Text('Total : ${fmtNum(_total, digits: 1)} L${_prix > 0 ? ' · ${fmtNum(_total * _prix)} F' : ''}', style: Theme.of(context).textTheme.titleMedium)),
                      if (canWrite) FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
                    ]),
                  ),
                ]),
    );
  }
}
