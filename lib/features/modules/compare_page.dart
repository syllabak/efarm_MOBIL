import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import 'data_view.dart';

/// « Comparer les bandes » du site web : les dernières bandes d'un site, côte à côte.
class CompareBandsPage extends ConsumerStatefulWidget {
  const CompareBandsPage({super.key});
  @override
  ConsumerState<CompareBandsPage> createState() => _CompareBandsPageState();
}

class _CompareBandsPageState extends ConsumerState<CompareBandsPage> {
  int? _site;
  Key _k = UniqueKey();

  static const _headline = <(String, String, String)>[
    ('taux_mortalite_pct', 'Mortalité', '%'),
    ('total_aliment_kg', 'Aliment', 'kg'),
    ('cout_prod_par_kg', 'Coût / kg', 'F'),
    ('marge_beneficiaire_pct', 'Marge', '%'),
    ('roi_pct', 'ROI', '%'),
  ];

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final p = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer les bandes')),
      body: AsyncView<List>(
        load: () => api.get<List>('/farm/sites'),
        builder: (c, sites) {
          if (sites.isEmpty) return const EmptyView('Aucun site.');
          // Compte rattaché à un site : aucune question à poser.
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
                  ? const EmptyView('Choisissez un site pour comparer ses dernières bandes.')
                  : AsyncView<List>(
                      key: _k,
                      load: () => api.get<List>('/lots/compare', query: {'site_id': site}),
                      builder: (c, bands) => bands.isEmpty
                          ? const EmptyView('Pas encore de bande à comparer sur ce site.')
                          : ListView(padding: const EdgeInsets.all(8), physics: const AlwaysScrollableScrollPhysics(), children: [for (final b in bands) _BandCard(Map<String, dynamic>.from(b as Map))]),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _BandCard extends StatelessWidget {
  const _BandCard(this.b);
  final Map<String, dynamic> b;
  @override
  Widget build(BuildContext context) {
    final title = '${b['code'] ?? b['lot_code'] ?? 'Bande ${b['lot_id'] ?? ''}'}';
    final lines = <String>[
      for (final h in _CompareBandsPageState._headline)
        if (b[h.$1] != null) '${h.$2} : ${fmtNum(b[h.$1], digits: 1)} ${h.$3}',
    ];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.egg_alt_outlined),
        title: Text(title),
        subtitle: Text(lines.isEmpty ? 'Détail ci-dessous' : lines.join(' · ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [DataTree(b, skip: const {'lot_id', 'id'})],
      ),
    );
  }
}
