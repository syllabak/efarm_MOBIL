import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import '../modules/data_view.dart';

/// « ROI & Performance » du site web : retour sur investissement des bandes d'un site.
class RoiPage extends ConsumerStatefulWidget {
  const RoiPage({super.key});
  @override
  ConsumerState<RoiPage> createState() => _RoiPageState();
}

class _RoiPageState extends ConsumerState<RoiPage> {
  int? _site;
  Key _k = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final p = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('ROI et performance')),
      body: AsyncView<List>(
        load: () => api.get<List>('/farm/sites'),
        builder: (c, sites) {
          if (sites.isEmpty) return const EmptyView('Aucun site.');
          final fixed = p?.siteId ?? (sites.length == 1 ? (sites.first as Map)['id'] as int? : null);
          final site = fixed ?? _site;
          return Column(children: [
            if (fixed == null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<int>(
                  initialValue: _site,
                  decoration: const InputDecoration(labelText: 'Site'),
                  items: [for (final s in sites) DropdownMenuItem(value: (s as Map)['id'] as int, child: Text('${s['nom']}'))],
                  onChanged: (v) => setState(() {
                    _site = v;
                    _k = UniqueKey();
                  }),
                ),
              ),
            Expanded(
              child: site == null
                  ? const EmptyView('Choisissez un site pour voir le retour sur investissement de ses bandes.')
                  : AsyncView<Map>(
                      key: _k,
                      load: () => api.get<Map>('/finance/roi', query: {'site_id': site}),
                      builder: (c, d) {
                        final lots = (d['lots'] as List? ?? const []).cast<Map>();
                        return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
                          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.6, padding: const EdgeInsets.all(4), children: [
                            Stat('Investi', '${fmtNum(d['total_investi'])} F', icon: Icons.trending_down, color: Colors.red),
                            Stat('Revenu', '${fmtNum(d['total_revenu'])} F', icon: Icons.trending_up, color: Colors.green),
                            Stat('Bénéfice net', '${fmtNum(d['benefice_net'])} F', icon: Icons.account_balance_wallet_outlined, color: (num.tryParse('${d['benefice_net']}') ?? 0) >= 0 ? Colors.green : Colors.red),
                            Stat('ROI global', '${fmtNum(d['roi_global_pct'], digits: 1)} %', icon: Icons.percent, color: Colors.blue),
                          ]),
                          if (lots.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Pas encore de bande sur ce site.')),
                          for (final l in lots)
                            Card(
                              child: ExpansionTile(
                                leading: const Icon(Icons.egg_alt_outlined),
                                title: Text('${l['code'] ?? l['lot_code'] ?? 'Bande ${l['lot_id'] ?? l['id'] ?? ''}'}'),
                                subtitle: l['roi_pct'] == null ? null : Text('ROI ${fmtNum(l['roi_pct'], digits: 1)} %'),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                children: [DataTree(Map<String, dynamic>.from(l), skip: const {'id', 'lot_id'})],
                              ),
                            ),
                        ]);
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

/// « Contrôle des chiffres » du site web : cohérence des ventes, dépenses et bilans (lecture seule).
class FinanceControlPage extends ConsumerWidget {
  const FinanceControlPage({super.key});

  static const _niveaux = {
    'erreur': ('Erreur', Colors.red, Icons.error_outline),
    'avert': ('Avertissement', Colors.orange, Icons.warning_amber),
    'info': ('Information', Colors.blue, Icons.info_outline),
    'ok': ('Correct', Colors.green, Icons.check_circle_outline),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle des chiffres')),
      body: AsyncView<Map>(
        load: () => api.get<Map>('/finance/control'),
        builder: (c, d) {
          final syn = Map<String, dynamic>.from(d['synthese'] as Map? ?? const {});
          final checks = (d['controles'] as List? ?? const []).cast<Map>();
          final ordre = ['erreur', 'avert', 'info', 'ok'];
          checks.sort((a, b) => ordre.indexOf('${a['gravite']}').compareTo(ordre.indexOf('${b['gravite']}')));
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final k in ordre) Chip(avatar: Icon(_niveaux[k]!.$3, color: _niveaux[k]!.$2, size: 18), label: Text('${syn[k] ?? 0} · ${_niveaux[k]!.$1}')),
            ]),
            const SizedBox(height: 8),
            for (final k in checks)
              Card(
                child: k['gravite'] == 'ok'
                    ? ListTile(leading: const Icon(Icons.check_circle_outline, color: Colors.green), title: Text('${k['titre']}'))
                    : ExpansionTile(
                        leading: Icon(_niveaux['${k['gravite']}']?.$3 ?? Icons.info_outline, color: _niveaux['${k['gravite']}']?.$2),
                        title: Text('${k['titre']}'),
                        subtitle: Text('${k['nb']} cas'),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ('${k['conseil'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${k['conseil']}', style: Theme.of(c).textTheme.bodySmall)),
                          for (final l in (k['lignes'] as List? ?? const [])) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $l')),
                        ],
                      ),
              ),
          ]);
        },
      ),
    );
  }
}
