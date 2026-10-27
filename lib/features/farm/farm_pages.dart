import 'package:flutter/material.dart' hide Text;
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/export.dart';
import '../../core/session.dart';
import '../../core/server_support.dart';
import '../../ui/common.dart';
import '../modules/module_pages.dart' show DynamicFormPage;
import '../modules/spec.dart' show FieldSpec, FieldType;
import 'ops_pages.dart';
import 'rapport_form.dart';

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
        trailing: statut == 'null' || statut.isEmpty ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text(const {'valide': 'Validé', 'soumis': 'Soumis', 'brouillon': 'Brouillon'}[statut] ?? statut, style: TextStyle(color: color, fontSize: 12))),
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
          if (rows.isNotEmpty)
            ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Exporter le stock (CSV)'),
                onTap: () => shareCsv('stock_${isoDate(DateTime.now())}.csv', const ['Produit', 'Site', 'Quantité', 'Unité', 'Seuil d\'alerte'], [for (final r in rows.cast<Map>()) [r['produit'], r['site_id'], r['quantite'], r['unite'], r['seuil_alerte']]]).catchError((Object e) {
                      if (c.mounted) showError(c, e);
                    })),
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
                  onTap: serverCan('POST', '/stock/exits') ? () => _move(false, product: s['produit_id'] as int?, site: s['site_id'] as int?) : null,
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
const _siteFields = [
  FieldSpec('nom', 'Nom du site', required: true),
  FieldSpec('adresse', 'Adresse'),
  FieldSpec('telephone', 'Téléphone', type: FieldType.phone),
  FieldSpec('capacite_max', 'Capacité maximale', type: FieldType.integer, min: 0, suffix: 'têtes'),
  FieldSpec('latitude', 'Latitude', type: FieldType.number, hint: 'Pour la météo du site (ex. 14.79)'),
  FieldSpec('longitude', 'Longitude', type: FieldType.number, hint: 'Ex. -16.93'),
];

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});
  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage> {
  Key _k = UniqueKey();

  Future<void> _form({Map? site}) async {
    final api = ref.read(apiProvider);
    final fields = site == null ? [const FieldSpec('code', 'Code', hint: 'Facultatif, ex. S1'), ..._siteFields] : _siteFields;
    final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => DynamicFormPage(
                title: site == null ? 'Nouveau site' : 'Modifier le site',
                fields: fields,
                initialValues: site == null ? const {} : Map<String, dynamic>.from(site),
                successMessage: site == null ? 'Site créé.' : 'Site mis à jour.',
                submit: (b) => site == null ? api.post('/farm/sites', body: b) : api.post('/farm/sites/${site['id']}', body: b))));
    if (ok == true && mounted) setState(() => _k = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final admin = ref.watch(sessionProvider).value?.role == 'admin';
    return Scaffold(
      appBar: AppBar(title: const Text('Sites')),
      floatingActionButton: admin && serverCan('POST', '/farm/sites') ? FloatingActionButton.extended(onPressed: () => _form(), icon: const Icon(Icons.add), label: const Text('Site')) : null,
      body: AsyncView<List>(
        key: _k,
        load: () => api.get<List>('/farm/sites'),
        builder: (c, rows) => rows.isEmpty
            ? const EmptyView('Aucun site.')
            : ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 80), children: [
                if (admin && serverCan('POST', '/farm/sites/{id}')) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Touchez un site pour le modifier. Un champ laissé vide n\'est pas modifié.', style: Theme.of(c).textTheme.bodySmall)),
                for (final r in rows)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text('${(r as Map)['nom']}'),
                      subtitle: Text('${r['code'] ?? ''}${r['adresse'] != null ? ' · ${r['adresse']}' : ''}'),
                      trailing: Text('Capacité ${fmtNum(r['capacite_max'])}'),
                      onTap: admin && serverCan('POST', '/farm/sites/{id}') ? () => _form(site: r) : null,
                    ),
                  ),
              ]),
      ),
    );
  }
}
