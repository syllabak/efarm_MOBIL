import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/server_support.dart';
import '../../core/session.dart';
import '../../ui/common.dart';
import '../../ui/tr_text.dart';
import '../modules/data_view.dart' show DataPage;
import '../modules/module_pages.dart' show ModuleDetailPage;
import '../modules/registry_elevage.dart';
import 'home_cards.dart';
import 'lot_card.dart';
import 'mortality_chart.dart';
import 'ops_pages.dart';
import 'rapport_form.dart';


/// Tableau de bord de la ferme, composé comme `views/dashboard/global.php` du site web :
/// titre, pastilles, quatre indicateurs, performance par site (siège), cartes des lots, mortalité, alertes, finances.
class FarmHome extends ConsumerStatefulWidget {
  const FarmHome({super.key, required this.onGoto});
  final void Function(int tab) onGoto;
  @override
  ConsumerState<FarmHome> createState() => _FarmHomeState();
}

class _FarmHomeState extends ConsumerState<FarmHome> {
  late Future<_Dash> _f = _load();

  Future<_Dash> _load() async {
    final api = ref.read(apiProvider);
    final p = ref.read(sessionProvider).value!;
    final today = isoDate(DateTime.now());
    final resume = await api.get<Map>('/farm/resume');
    Future<List<Map<String, dynamic>>> safe(String path, [Map<String, dynamic>? q]) async {
      if (!serverGets(path)) return const [];
      try {
        return await api.listAll(path, query: q);
      } catch (_) {
        return const [];
      }
    }

    final r = await Future.wait([
      safe('/farm/lots', {'statut': 'actif'}),
      safe('/stock/alerts'),
      safe('/farm/rapports', {'du': today, 'au': today}),
      if (p.role == 'siege') safe('/farm/sites'),
    ]);
    return _Dash(resume, r[0], r[1], r[2], r.length > 3 ? r[3] : const []);
  }

  Future<void> _reload() async {
    setState(() => _f = _load());
    await _f.catchError((_) => _Dash({}, const [], const [], const [], const []));
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(sessionProvider).value;
    if (p == null) return const SizedBox.shrink();
    return FutureBuilder<_Dash>(
      future: _f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return ErrorView(s.error!, onRetry: _reload);
        final d = s.data!;
        final now = DateTime.now();
        final mortToday = d.rapportsToday.fold<num>(0, (a, r) => a + (num.tryParse('${r['mortalite_jour']}') ?? 0));
        final nbStock = d.stockAlerts.length;
        final green = Theme.of(c).brightness == Brightness.dark ? const Color(0xFF86EFAC) : const Color(0xFF166534);
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(8, 12, 8, 24), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📊 Tableau de bord', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: green)),
                const SizedBox(height: 2),
                Text('${p.companyName ?? tr('Vue globale — tous les sites')} — ${fmtDate(now.toIso8601String())}', style: Theme.of(c).textTheme.bodySmall?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant)),
                if (nbStock > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    ActionChip(
                      backgroundColor: const Color(0xFFFEE2E2),
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      label: Text('🔴 $nbStock alerte(s) stock', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w500, fontSize: 12)),
                      onPressed: () => widget.onGoto(3),
                    ),
                  ]),
                ],
              ]),
            ),
            if (p.licence != null && (p.licence!['jours_restants'] as int?) != null && (p.licence!['jours_restants'] as int) <= 15)
              Card(
                  color: const Color(0xFFFEF3C7),
                  child: ListTile(leading: const Text('⚠️', style: TextStyle(fontSize: 22)), title: Text('Licence : ${p.licence!['jours_restants']} jour(s) restant(s)', style: const TextStyle(color: Color(0xFF78350F), fontWeight: FontWeight.w600)), subtitle: const Text('Renouvelez depuis le site web.'))),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.7,
              padding: const EdgeInsets.all(4),
              children: [
                Stat('Têtes total', fmtNum(d.resume['effectif_total']), emoji: '🐔', color: const Color(0xFF15803D)),
                Stat('Lots actifs', fmtNum(d.resume['lots_actifs']), emoji: '🐣', color: const Color(0xFF1D4ED8)),
                Stat('Mortalité / j', fmtNum(mortToday), emoji: '📉', color: const Color(0xFFB91C1C)),
                Stat('Alertes stock', fmtNum(nbStock), emoji: '⚠️', color: const Color(0xFFA16207)),
              ],
            ),
            if (p.role == 'siege' && d.sites.isNotEmpty) _SitesTable(d),
            for (final l in d.lots) LotCard(l, onForecast: serverGets('/forecast/{id}/feed') ? () => Navigator.push(c, MaterialPageRoute(builder: (_) => DataPage(title: 'Prévision d\'aliment', path: '/forecast/${l['id']}/feed', pick: 'prevision', query: const {'ia': 1}))) : null, onDetail: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ModuleDetailPage(lotsSpec, l['id'], row: l))), onReport: p.canReport && serverCan('POST', '/farm/rapports') ? () => Navigator.push(c, MaterialPageRoute(builder: (_) => RapportForm(lotId: l['id'] as int?))) : null),
            if (d.lots.isEmpty && p.role != 'siege')
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Column(children: [
                    const Text('🐣', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    Text('Aucun lot actif', style: Theme.of(c).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    const Text('Créez votre premier lot pour commencer le suivi.', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => widget.onGoto(1), child: const Text('➕ Créer un lot')),
                  ]),
                ),
              ),
            if (serverGets('/farm/rapports')) const MortalityChartCard(),
            if (serverGets('/alerts')) RecentAlertsCard(onSeeAll: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AlertsPage()))),
            if (serverGets('/finance/summary') && const {'admin', 'siege', 'responsable'}.contains(p.role)) const MonthFinanceCard(),
            if (p.canReport && serverCan('POST', '/farm/rapports'))
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: FilledButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const RapportForm())), icon: const Icon(Icons.edit_note), label: const Text('Saisir le rapport du jour')),
              ),
          ]),
        );
      },
    );
  }
}

class _Dash {
  _Dash(this.resume, this.lots, this.stockAlerts, this.rapportsToday, this.sites);
  final Map resume;
  final List<Map<String, dynamic>> lots, stockAlerts, rapportsToday, sites;
}

/// « 🏭 Performance par site » (siège) : lots actifs, têtes, rapport du jour.
class _SitesTable extends StatelessWidget {
  const _SitesTable(this.d);
  final _Dash d;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(child: Text('🏭 Performance par site', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
            Text('${d.sites.length} site(s)', style: t.bodySmall),
          ]),
        ),
        const Divider(height: 1),
        for (final s in d.sites)
          Builder(builder: (c) {
            final lots = d.lots.where((l) => '${l['site_id']}' == '${s['id']}');
            final heads = lots.fold<num>(0, (a, l) => a + (num.tryParse('${l['nb_actuel']}') ?? 0));
            final done = d.rapportsToday.any((r) => '${r['site_id']}' == '${s['id']}');
            return ListTile(
              dense: true,
              title: Text('${s['nom']}', style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('${lots.length} lot(s) · ${fmtNum(heads)} têtes'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: done ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                child: Text(done ? '✓ Soumis' : '✗ Manquant', style: TextStyle(fontSize: 12, color: done ? const Color(0xFF15803D) : const Color(0xFFB91C1C))),
              ),
            );
          }),
      ]),
    );
  }
}

