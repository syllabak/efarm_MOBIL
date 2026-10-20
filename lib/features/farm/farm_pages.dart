import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/server_support.dart';
import '../../ui/common.dart';
import 'ops_pages.dart';
import 'rapport_form.dart';

// ── Accueil ──────────────────────────────────────────────────────────
class FarmHome extends ConsumerWidget {
  const FarmHome({super.key, required this.onGoto});
  final void Function(int tab) onGoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final p = ref.watch(sessionProvider).value!;
    return AsyncView<Map>(
      load: () => api.get<Map>('/farm/resume'),
      builder: (c, d) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text('Bonjour ${p.fullName}', style: Theme.of(c).textTheme.titleLarge),
        ),
        if (p.companyName != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(p.companyName!)),
        if (p.licence != null && (p.licence!['jours_restants'] as int?) != null && (p.licence!['jours_restants'] as int) <= 15)
          Card(
              color: Theme.of(c).colorScheme.errorContainer,
              child: ListTile(leading: const Icon(Icons.warning_amber), title: Text('Licence : ${p.licence!['jours_restants']} jour(s) restant(s)'), subtitle: const Text('Renouvelez depuis le site web.'))),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          padding: const EdgeInsets.all(4),
          children: [
            Stat('Sites actifs', fmtNum(d['sites_actifs']), icon: Icons.location_on_outlined, color: const Color(0xFF9333EA)),
            Stat('Lots actifs', fmtNum(d['lots_actifs']), icon: Icons.egg_alt_outlined, color: const Color(0xFF1D4ED8)),
            Stat('Têtes total', fmtNum(d['effectif_total']), icon: Icons.pets, color: const Color(0xFF15803D)),
            Stat('Dernier rapport', fmtDate(d['dernier_rapport']), icon: Icons.assignment_outlined, color: const Color(0xFFCA8A04)),
          ],
        ),
        if (p.canReport && serverCan('POST', '/farm/rapports'))
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
                onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const RapportForm())),
                icon: const Icon(Icons.edit_note),
                label: const Text('Saisir le rapport du jour')),
          ),
        ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('Voir le stock'), trailing: const Icon(Icons.chevron_right), onTap: () => onGoto(3)),
        ListTile(leading: const Icon(Icons.location_city_outlined), title: const Text('Sites'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SitesPage()))),
      ]),
    );
  }
}

// ── Rapports ─────────────────────────────────────────────────────────
class RapportTile extends StatelessWidget {
  const RapportTile(this.r, {super.key});
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final statut = '${r['statut']}';
    final color = statut == 'valide' ? Colors.green : (statut == 'soumis' ? Colors.blue : Colors.orange);
    return Card(
      child: ListTile(
        leading: Icon(Icons.assignment_turned_in_outlined, color: color),
        title: Text(fmtDate(r['date_rapport'])),
        subtitle: Text('Vivants ${fmtNum(r['nb_tetes_vivantes'])} · morts ${fmtNum(r['mortalite_jour'])} · aliment ${fmtNum(r['sacs_consommes'], digits: 1)} sacs'
            '${r['poids_moyen'] != null ? ' · ${fmtNum(r['poids_moyen'], digits: 3)} kg' : ''}'),
        trailing: Text(statut, style: TextStyle(color: color)),
      ),
    );
  }
}

class RapportsPage extends ConsumerStatefulWidget {
  const RapportsPage({super.key});
  @override
  ConsumerState<RapportsPage> createState() => _RapportsPageState();
}

class _RapportsPageState extends ConsumerState<RapportsPage> {
  Key _k = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final p = ref.watch(sessionProvider).value!;
    return Scaffold(
      body: PagedList(key: _k, fetch: (page) => api.list('/farm/rapports', query: {'page': page}), emptyText: 'Aucun rapport.', itemBuilder: (c, r) => RapportTile(r)),
      floatingActionButton: p.canReport && serverCan('POST', '/farm/rapports')
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Rapport'),
              onPressed: () async {
                final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const RapportForm()));
                if (ok == true) setState(() => _k = UniqueKey());
              })
          : null,
    );
  }
}

// ── Stock ────────────────────────────────────────────────────────────
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});
  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  Key _k = UniqueKey();

  Future<void> _move(bool entry, {int? product, int? site}) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => StockMovementForm(entry: entry, productId: product, siteId: site)));
    if (ok == true && mounted) setState(() => _k = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final role = ref.watch(sessionProvider).value?.role ?? '';
    final canEntry = const {'admin', 'siege', 'responsable'}.contains(role);
    return Scaffold(
      floatingActionButton: !serverCan('POST', '/stock/exits') ? null : FloatingActionButton.extended(
        icon: const Icon(Icons.swap_vert),
        label: const Text('Mouvement'),
        onPressed: () async {
          final entry = await showModalBottomSheet<bool>(
              context: context,
              builder: (c) => SafeArea(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (canEntry) ListTile(leading: const Icon(Icons.add_circle_outline), title: const Text('Entrée de stock'), onTap: () => Navigator.pop(c, true)),
                    ListTile(leading: const Icon(Icons.remove_circle_outline), title: const Text('Sortie de stock'), onTap: () => Navigator.pop(c, false)),
                  ])));
          if (entry != null) _move(entry);
        },
      ),
      body: AsyncView<List>(
        key: _k,
        load: () => api.get<List>('/farm/stock'),
        builder: (c, rows) => ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          if (serverGets('/stock/alerts')) ListTile(leading: const Icon(Icons.warning_amber), title: const Text('Produits sous le seuil'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const LowStockPage()))),
          if (canEntry && serverGets('/stock/movements')) ListTile(leading: const Icon(Icons.history), title: const Text('Historique des mouvements'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const MovementsPage()))),
          const Divider(height: 1),
          if (rows.isEmpty) const SizedBox(height: 300, child: EmptyView('Aucun produit en stock.')),
          for (final r in rows)
            Builder(builder: (c) {
              final s = Map<String, dynamic>.from(r as Map);
              final q = num.tryParse('${s['quantite']}') ?? 0, seuil = num.tryParse('${s['seuil_alerte']}') ?? 0;
              final bas = seuil > 0 && q <= seuil;
              return Card(
                child: ListTile(
                  leading: Icon(bas ? Icons.warning_amber : Icons.inventory_2_outlined, color: bas ? Colors.red : null),
                  title: Text('${s['produit']}'),
                  subtitle: Text('Site ${s['site_id']}${seuil > 0 ? ' · seuil ${fmtNum(seuil, digits: 1)}' : ''}'),
                  trailing: Text('${fmtNum(q, digits: 1)} ${s['unite'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, color: bas ? Colors.red : null)),
                  onTap: () => _move(false, product: s['produit_id'] as int?, site: s['site_id'] as int?),
                ),
              );
            }),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class LowStockPage extends ConsumerWidget {
  const LowStockPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Produits sous le seuil')),
      body: AsyncView<List>(
        load: () => api.get<List>('/stock/alerts'),
        builder: (c, rows) => rows.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: EmptyView('Aucun produit sous le seuil.', icon: Icons.check_circle_outline))])
            : ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                for (final r in rows.cast<Map>())
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.warning_amber, color: '${r['statut_stock']}'.contains('rupt') ? Colors.red : Colors.orange),
                      title: Text('${r['produit_nom']}'),
                      subtitle: Text('${r['site_nom'] ?? ''} · ${r['statut_stock'] ?? ''}'),
                      trailing: Text('${fmtNum(r['quantite'], digits: 1)} / ${fmtNum(r['seuil_alerte'], digits: 1)}'),
                    ),
                  ),
              ]),
      ),
    );
  }
}

// ── Sites ────────────────────────────────────────────────────────────
class SitesPage extends ConsumerWidget {
  const SitesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sites')),
      body: AsyncView<List>(
        load: () => api.get<List>('/farm/sites'),
        builder: (c, rows) => rows.isEmpty
            ? const EmptyView('Aucun site.')
            : ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                for (final r in rows)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text('${(r as Map)['nom']}'),
                      subtitle: Text('${r['code'] ?? ''}${r['adresse'] != null ? ' · ${r['adresse']}' : ''}'),
                      trailing: Text('Capacité ${fmtNum(r['capacite_max'])}'),
                    ),
                  ),
              ]),
      ),
    );
  }
}
