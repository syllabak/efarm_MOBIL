import 'package:flutter/material.dart' hide Text;
import '../../ui/web_menu.dart';
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';

// ── Alertes ──────────────────────────────────────────────────────────
class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});
  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  Key _k = UniqueKey();
  int? _unread;

  Future<void> _markRead() async {
    try {
      await ref.read(apiProvider).post('/alerts/read');
      if (mounted) setState(() => _k = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  IconData _icon(String? t) => switch (t ?? '') {
        final s when s.contains('mort') => Icons.heart_broken_outlined,
        final s when s.contains('stock') => Icons.inventory_2_outlined,
        final s when s.contains('poids') => Icons.monitor_weight_outlined,
        _ => Icons.notifications_active_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(webTitle('Alertes')), actions: [
        TextButton.icon(onPressed: (_unread ?? 0) > 0 ? _markRead : null, icon: const Icon(Icons.done_all), label: const Text('Tout lire')),
      ]),
      body: PagedList(
        key: _k,
        emptyText: 'Aucune alerte.',
        fetch: (page) async {
          final r = await api.list('/alerts', query: {'page': page});
          if (mounted) setState(() => _unread = r.meta['non_lues'] as int?);
          return r;
        },
        itemBuilder: (c, a) {
          final lue = '${a['lue']}' == '1' || a['lue'] == true;
          final texte = (a['message'] ?? a['titre'] ?? a['type'] ?? 'Alerte').toString();
          return Card(
            color: lue ? null : Theme.of(c).colorScheme.errorContainer.withValues(alpha: 0.4),
            child: ListTile(
              leading: Icon(_icon('${a['type']}')),
              title: Text(texte, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: lue ? FontWeight.normal : FontWeight.bold)),
              subtitle: Text([if (a['lot_code'] != null) 'Lot ${a['lot_code']}', fmtDateTime(a['created_at'])].join(' · ')),
            ),
          );
        },
      ),
    );
  }
}

// ── Mouvements de stock ──────────────────────────────────────────────
class MovementsPage extends ConsumerWidget {
  const MovementsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    const labels = {'entree': 'Entrée', 'sortie': 'Sortie', 'transfert_out': 'Transfert (sortie)', 'transfert_in': 'Transfert (entrée)', 'ajustement': 'Ajustement', 'perte': 'Perte'};
    return Scaffold(
      appBar: AppBar(title: const Text('Mouvements de stock')),
      body: PagedList(
        emptyText: 'Aucun mouvement.',
        fetch: (page) => api.list('/stock/movements', query: {'page': page}),
        itemBuilder: (c, m) {
          final entree = const {'entree', 'transfert_in'}.contains('${m['type_mouvement']}');
          return Card(
            child: ListTile(
              leading: Icon(entree ? Icons.add_circle_outline : Icons.remove_circle_outline, color: entree ? Colors.green : Colors.red),
              title: Text('${m['produit']}'),
              subtitle: Text('${labels['${m['type_mouvement']}'] ?? m['type_mouvement']} · ${fmtDateTime(m['created_at'])}${m['note'] != null ? '\n${m['note']}' : ''}'),
              isThreeLine: m['note'] != null,
              trailing: Text('${entree ? '+' : '−'}${fmtNum(m['quantite'], digits: 1)} ${m['unite'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, color: entree ? Colors.green : Colors.red)),
            ),
          );
        },
      ),
    );
  }
}

// ── Entrée / sortie de stock ─────────────────────────────────────────
class StockMovementForm extends ConsumerStatefulWidget {
  const StockMovementForm({super.key, required this.entry, this.productId, this.siteId});
  final bool entry;
  final int? productId, siteId;
  @override
  ConsumerState<StockMovementForm> createState() => _StockMovementFormState();
}

class _StockMovementFormState extends ConsumerState<StockMovementForm> {
  final _form = GlobalKey<FormState>();
  final _qte = TextEditingController(), _cout = TextEditingController(), _ref = TextEditingController(), _note = TextEditingController();
  List<Map<String, dynamic>> _products = [], _sites = [];
  int? _product, _site;
  bool _loading = true, _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final p = (await ref.read(sessionProvider.future))!;
      _products = [for (final x in await api.get<List>('/stock/products')) Map<String, dynamic>.from(x as Map)];
      _sites = [for (final x in await api.get<List>('/farm/sites')) Map<String, dynamic>.from(x as Map)];
      _product = widget.productId;
      _site = p.allSites ? (widget.siteId ?? (_sites.length == 1 ? _sites.first['id'] as int : null)) : p.siteId;
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).post(widget.entry ? '/stock/entries' : '/stock/exits', body: {
        'site_id': ?_site,
        'produit_id': _product,
        'quantite': num.parse(_qte.text.replaceAll(',', '.')),
        if (widget.entry && _cout.text.trim().isNotEmpty) 'cout_unitaire': num.parse(_cout.text.replaceAll(',', '.')),
        if (widget.entry && _ref.text.trim().isNotEmpty) 'reference': _ref.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      showInfo(context, widget.entry ? 'Entrée enregistrée.' : 'Sortie enregistrée.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSites = ref.watch(sessionProvider).value?.allSites ?? false;
    final unite = _products.where((x) => x['id'] == _product).firstOrNull?['unite'];
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry ? 'Entrée de stock' : 'Sortie de stock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    if (allSites) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _site,
                        decoration: InputDecoration(labelText: tr('Site *')),
                        items: [for (final s in _sites) DropdownMenuItem(value: s['id'] as int, child: Text('${s['nom']}'))],
                        validator: (v) => v == null ? 'Requis' : null,
                        onChanged: (v) => _site = v,
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<int>(
                      initialValue: _product,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: tr('Produit *')),
                      items: [for (final x in _products) DropdownMenuItem(value: x['id'] as int, child: Text('${x['nom']} (${x['unite']})', overflow: TextOverflow.ellipsis))],
                      validator: (v) => v == null ? 'Requis' : null,
                      onChanged: (v) => setState(() => _product = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qte,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: tr('Quantité *'), suffixText: unite as String?),
                      validator: (v) => (num.tryParse((v ?? '').replaceAll(',', '.')) ?? 0) > 0 ? null : 'Quantité invalide',
                    ),
                    if (widget.entry) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cout,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: tr('Prix unitaire d\'achat'), suffixText: 'F', helperText: tr('Si renseigné, une dépense est créée automatiquement.')),
                        validator: (v) => (v ?? '').trim().isEmpty || (num.tryParse(v!.replaceAll(',', '.')) ?? -1) >= 0 ? null : 'Invalide',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _ref, decoration: InputDecoration(labelText: tr('Référence (bon, facture)'))),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: tr('Note'))),
                    const SizedBox(height: 20),
                    FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
                  ]),
                ),
    );
  }
}
