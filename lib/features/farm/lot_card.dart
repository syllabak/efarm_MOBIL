import 'package:flutter/material.dart' hide Text;

import '../../ui/common.dart';
import '../../ui/tr_text.dart';

/// Carte d'un lot comme sur le site : bandeau vert, progression, trois chiffres, trois boutons.
class LotCard extends StatelessWidget {
  const LotCard(this.l, {super.key, this.onReport, this.onDetail, this.onForecast});
  final Map<String, dynamic> l;
  final VoidCallback? onReport, onDetail, onForecast;
  @override
  Widget build(BuildContext context) {
    final entree = DateTime.tryParse('${l['date_entree']}'.replaceFirst(' ', 'T'));
    final age = entree == null ? 0 : DateTime.now().difference(entree).inDays.clamp(0, 9999);
    final pct = (age / 42).clamp(0.0, 1.0);
    final init = num.tryParse('${l['nb_initial']}') ?? 0;
    final cur = num.tryParse('${l['nb_actuel']}') ?? 0;
    final mort = init > 0 ? (init - cur) * 100 / init : 0;
    final mortColor = mort > 5 ? const Color(0xFFDC2626) : (mort > 2 ? const Color(0xFFF97316) : const Color(0xFF16A34A));
    final t = Theme.of(context).textTheme;
    Widget cell(String v, String lab, [Color? col]) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text(v, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: col ?? const Color(0xFF1F2937))),
              Text(lab, style: t.bodySmall?.copyWith(color: const Color(0xFF9CA3AF))),
            ]),
          ),
        );
    Widget btn(String label, Color bg, Color fg, VoidCallback? f) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: f,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500))),
            ),
          ),
        );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF15803D), Color(0xFF16A34A)])),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l['code']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${l['race'] ?? 'Race non définie'}', style: const TextStyle(color: Color(0xFFBBF7D0), fontSize: 12)),
              ]),
            ),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Text('J+$age', style: const TextStyle(color: Colors.white, fontSize: 12))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Progression', style: t.bodySmall?.copyWith(color: const Color(0xFF9CA3AF))), Text('$age/42 j', style: t.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)))]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: const Color(0xFFF3F4F6), color: const Color(0xFF22C55E))),
            const SizedBox(height: 10),
            Row(children: [cell(fmtNum(cur), 'têtes'), cell('${fmtNum(mort, digits: 1)}%', 'mortalité', mortColor), cell('—', 'poids')]),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            if (onReport != null) btn('📋 Rapport', const Color(0xFFF0FDF4), const Color(0xFF15803D), onReport),
            if (onForecast != null) btn('📈 Prévoir', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), onForecast),
            if (onDetail != null) btn('🔍 Détail', const Color(0xFFF9FAFB), const Color(0xFF4B5563), onDetail),
          ]),
        ),
      ]),
    );
  }

}
