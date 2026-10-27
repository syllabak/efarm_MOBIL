import 'package:flutter/material.dart' hide Text;
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';

/// Mortalité par jour sur [jours] jours à partir des rapports (un jour sans rapport compte 0). Du plus ancien au plus récent.
List<({DateTime jour, num morts})> mortaliteParJour(Iterable<Map<String, dynamic>> rapports, {int jours = 30, DateTime? fin}) {
  final f = DateTime((fin ?? DateTime.now()).year, (fin ?? DateTime.now()).month, (fin ?? DateTime.now()).day);
  final total = <String, num>{};
  for (final r in rapports) {
    final d = '${r['date_rapport']}'.split(' ').first;
    total[d] = (total[d] ?? 0) + (num.tryParse('${r['mortalite_jour']}') ?? 0);
  }
  return [
    for (var i = jours - 1; i >= 0; i--)
      (jour: f.subtract(Duration(days: i)), morts: total[isoDate(f.subtract(Duration(days: i)))] ?? 0),
  ];
}

/// « 📉 Mortalité — 30 derniers jours » du tableau de bord web, en histogramme.
class MortalityChartCard extends ConsumerWidget {
  const MortalityChartCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final fin = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📉 Mortalité — 30 derniers jours', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: api.listAll('/farm/rapports', query: {'du': isoDate(fin.subtract(const Duration(days: 29))), 'au': isoDate(fin)}),
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              if (s.hasError) return Text(errorText(s.error!), style: Theme.of(c).textTheme.bodySmall);
              final data = mortaliteParJour(s.data!, fin: fin);
              final total = data.fold<num>(0, (a, b) => a + b.morts);
              if (total == 0) return const SizedBox(height: 60, child: Center(child: Text('Aucune mortalité enregistrée sur la période.')));
              final max = data.map((e) => e.morts).reduce((a, b) => a > b ? a : b);
              return Column(children: [
                SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: BarsPainter([for (final e in data) e.morts.toDouble()], Colors.red.shade400, Theme.of(c).colorScheme.outlineVariant))),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(fmtDate(isoDate(data.first.jour)), style: Theme.of(c).textTheme.labelSmall),
                  Text('${fmtNum(total)} au total · pic ${fmtNum(max)}', style: Theme.of(c).textTheme.labelSmall),
                  Text(fmtDate(isoDate(data.last.jour)), style: Theme.of(c).textTheme.labelSmall),
                ]),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

class BarsPainter extends CustomPainter {
  BarsPainter(this.values, this.color, this.axis);
  final List<double> values;
  final Color color, axis;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.fold<double>(1, (a, b) => b > a ? b : a);
    final w = size.width / values.length;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = axis);
    final p = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final h = size.height * values[i] / max;
      if (h > 0) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * 0.15, size.height - h, w * 0.7, h), const Radius.circular(2)), p);
    }
  }

  @override
  bool shouldRepaint(BarsPainter old) => old.values != values || old.color != color;
}
