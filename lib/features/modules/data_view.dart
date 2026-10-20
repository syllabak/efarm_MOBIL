import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';

String humanize(String key) {
  final t = key.replaceAll('_', ' ').trim();
  return t.isEmpty ? key : t[0].toUpperCase() + t.substring(1);
}

/// Affiche récursivement une réponse JSON (objets, listes, valeurs) : sert aux analyses et bilans dont la structure évolue côté serveur.
class DataTree extends StatelessWidget {
  const DataTree(this.data, {super.key, this.skip = const {}});
  final Object? data;
  final Set<String> skip;

  Widget _node(BuildContext c, String? label, Object? v, int depth) {
    if (v is Map) {
      final entries = v.entries.where((e) => !skip.contains('${e.key}')).toList();
      if (entries.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(left: depth == 0 ? 0 : 12, top: 4, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null) Text(humanize(label), style: Theme.of(c).textTheme.titleSmall),
          for (final e in entries) _node(c, '${e.key}', e.value, depth + 1),
        ]),
      );
    }
    if (v is List) {
      if (v.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null) Text('${humanize(label)} (${v.length})', style: Theme.of(c).textTheme.titleSmall),
          for (final e in v.take(60)) _node(c, null, e, depth + 1),
        ]),
      );
    }
    if (label == null) return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• ${_fmt(v)}'));
    return KeyValue(humanize(label), _fmt(v));
  }

  static String _fmt(Object? v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Oui' : 'Non';
    if (v is num) return fmtNum(v, digits: v is int || v == v.roundToDouble() ? 0 : 2);
    final s = '$v';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return fmtDate(s);
    return s;
  }

  @override
  Widget build(BuildContext context) => _node(context, null, data, 0);
}

/// Page de consultation d'une ressource JSON affichée telle quelle.
class DataPage extends ConsumerWidget {
  const DataPage({super.key, required this.title, required this.path, this.query, this.pick, this.header});
  final String title, path;
  final Map<String, dynamic>? query;

  /// Sous-élément à afficher (ex. `prevision`).
  final String? pick;
  final Widget Function(BuildContext, Map)? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncView<Map>(
        load: () => api.get<Map>(path, query: query),
        builder: (c, d) {
          final shown = pick == null ? d : d[pick];
          final ia = d['ia'];
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (header != null) header!(c, d),
              if (shown == null || (shown is Map && shown.isEmpty) || (shown is List && shown.isEmpty)) const Padding(padding: EdgeInsets.all(24), child: Text('Données insuffisantes pour le moment.')),
              DataTree(shown, skip: const {'id', 'lot_id'}),
              if (ia is String && ia.isNotEmpty) ...[const Divider(height: 28), Text('Analyse IA', style: Theme.of(c).textTheme.titleMedium), const SizedBox(height: 6), Text(ia)],
            ]),
          );
        },
      ),
    );
  }
}
