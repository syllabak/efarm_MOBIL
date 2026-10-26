import 'package:flutter/material.dart' hide Text;
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';

/// « 🔔 Alertes récentes » du tableau de bord web : les 5 dernières, les non lues en évidence.
class RecentAlertsCard extends ConsumerWidget {
  const RecentAlertsCard({super.key, this.onSeeAll});
  final VoidCallback? onSeeAll;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('🔔 Alertes récentes', style: Theme.of(context).textTheme.titleSmall)),
            if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('Tout voir')),
          ]),
          FutureBuilder<({List<Map<String, dynamic>> items, Map<String, dynamic> meta})>(
            future: api.list('/alerts', query: {'per_page': 5}),
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const LinearProgressIndicator();
              if (s.hasError) return Text(errorText(s.error!), style: Theme.of(c).textTheme.bodySmall);
              final rows = s.data!.items;
              if (rows.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucune alerte.'));
              return Column(children: [
                for (final a in rows)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon('${a['lue']}' == '1' || a['lue'] == true ? Icons.notifications_none : Icons.notifications_active, color: '${a['lue']}' == '1' || a['lue'] == true ? null : Colors.red),
                    title: Text('${a['message'] ?? a['titre'] ?? a['type'] ?? 'Alerte'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(fmtDateTime(a['created_at'])),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

/// « 💰 Finances du mois » du tableau de bord web (administrateur, siège, responsable).
class MonthFinanceCard extends ConsumerWidget {
  const MonthFinanceCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('💰 Finances du mois', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          FutureBuilder<Map>(
            future: api.get<Map>('/finance/summary', query: {'annee': now.year, 'mois': now.month}),
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const LinearProgressIndicator();
              if (s.hasError) return Text(errorText(s.error!), style: Theme.of(c).textTheme.bodySmall);
              final d = s.data!;
              final net = (num.tryParse('${d['benefice_net']}') ?? 0);
              Widget line(String l, String v, [Color? col]) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(child: Text(l)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: col))]));
              return Column(children: [
                line('Ventes', '${fmtNum(d['total_ventes'])} F', Colors.green),
                line('Dépenses', '${fmtNum(d['total_depenses'])} F', Colors.red),
                line('Bénéfice net', '${fmtNum(net)} F', net >= 0 ? Colors.green : Colors.red),
                if ((num.tryParse('${d['creances']}') ?? 0) > 0) line('Créances à encaisser', '${fmtNum(d['creances'])} F', Colors.orange),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
