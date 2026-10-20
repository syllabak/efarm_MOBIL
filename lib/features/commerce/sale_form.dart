import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../ui/common.dart';
import 'commerce_pages.dart';

class _Line {
  final designation = TextEditingController();
  final unite = TextEditingController(text: 'tête');
  final quantite = TextEditingController(text: '1');
  final prix = TextEditingController();
  num get total => (num.tryParse(quantite.text.replaceAll(',', '.')) ?? 0) * (num.tryParse(prix.text.replaceAll(',', '.')) ?? 0);
  void dispose() {
    designation.dispose();
    unite.dispose();
    quantite.dispose();
    prix.dispose();
  }
}

/// Création d'une vente (équivalent de « Nouvelle vente » du web).
class SaleForm extends ConsumerStatefulWidget {
  const SaleForm({super.key});
  @override
  ConsumerState<SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends ConsumerState<SaleForm> {
  final _form = GlobalKey<FormState>();
  final _lines = <_Line>[_Line()];
  final _remise = TextEditingController(text: '0'), _notes = TextEditingController(), _clientLibre = TextEditingController();
  List<Map<String, dynamic>> _sites = [], _lots = [];
  int? _site, _lot;
  bool _sansLot = false;
  Map<String, dynamic>? _client;
  String _mode = 'especes';
  DateTime _date = DateTime.now();
  bool _loading = true, _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _remise.dispose();
    _notes.dispose();
    _clientLibre.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = (await ref.read(sessionProvider.future))!;
      _sites = [for (final s in await ref.read(apiProvider).get<List>('/farm/sites')) Map<String, dynamic>.from(s as Map)];
      _site = p.allSites ? (_sites.length == 1 ? _sites.first['id'] as int : null) : p.siteId;
      await _loadLots();
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLots() async {
    _lot = null;
    _lots = [];
    if (_site == null) return;
    final r = await ref.read(apiProvider).list('/farm/lots', query: {'statut': 'actif', 'site_id': _site, 'per_page': 100});
    _lots = r.items;
  }

  num get _sousTotal => _lines.fold<num>(0, (a, l) => a + l.total);
  num get _total => _sousTotal * (1 - ((num.tryParse(_remise.text.replaceAll(',', '.')) ?? 0).clamp(0, 100)) / 100);

  Future<void> _pickClient() async {
    final api = ref.read(apiProvider);
    final c = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ClientPicker(api: api),
    );
    if (c != null) setState(() => _client = c.isEmpty ? null : c);
  }

  Future<void> _save({bool confirmRetrait = false}) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final r = await ref.read(apiProvider).post<Map>('/sales', body: {
        'site_id': ?_site,
        'lot_id': ?_lot,
        if (_sansLot) 'sans_lot': true,
        if (_client != null) 'client_id': _client!['id'] else if (_clientLibre.text.trim().isNotEmpty) 'client_nom_libre': _clientLibre.text.trim(),
        'date_vente': isoDate(_date),
        'mode_paiement': _mode,
        'remise_pct': num.tryParse(_remise.text.replaceAll(',', '.')) ?? 0,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (confirmRetrait) 'confirmer_retrait': true,
        'lignes': [
          for (final l in _lines)
            {
              'designation': l.designation.text.trim(),
              'unite': l.unite.text.trim(),
              'quantite': num.parse(l.quantite.text.replaceAll(',', '.')),
              'prix_unitaire': num.parse(l.prix.text.replaceAll(',', '.')),
            }
        ],
      });
      if (!mounted) return;
      showInfo(context, 'Vente ${r['numero']} enregistrée (${money(r['montant_total'])}).');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 'retrait_en_cours') {
        final go = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                  title: const Text('Œufs sous délai d\'attente'),
                  content: Text(e.message),
                  actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Vendre quand même'))],
                ));
        if (go == true) {
          setState(() => _saving = false);
          return _save(confirmRetrait: true);
        }
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _pos(String? v, {bool zero = false}) {
    final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null) return 'Requis';
    return (zero ? n < 0 : n <= 0) ? 'Invalide' : null;
  }

  @override
  Widget build(BuildContext context) {
    final allSites = ref.watch(sessionProvider).value?.allSites ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(_error!, onRetry: _init)
              : Form(
                  key: _form,
                  child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (allSites) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _site,
                        decoration: const InputDecoration(labelText: 'Site *'),
                        items: [for (final s in _sites) DropdownMenuItem(value: s['id'] as int, child: Text('${s['nom']}'))],
                        validator: (v) => v == null ? 'Requis' : null,
                        onChanged: (v) async {
                          _site = v;
                          try {
                            await _loadLots();
                          } catch (e) {
                            if (mounted) showError(context, e);
                          }
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_lots.isNotEmpty && !_sansLot)
                      DropdownButtonFormField<int>(
                        initialValue: _lot,
                        decoration: const InputDecoration(labelText: 'Lot concerné *'),
                        items: [for (final l in _lots) DropdownMenuItem(value: l['id'] as int, child: Text('${l['code']} · ${fmtNum(l['nb_actuel'])} têtes'))],
                        validator: (v) => v == null ? 'Choisissez un lot ou cochez « sans lot »' : null,
                        onChanged: (v) => _lot = v,
                      ),
                    if (_lots.isNotEmpty) CheckboxListTile(contentPadding: EdgeInsets.zero, value: _sansLot, onChanged: (v) => setState(() => _sansLot = v ?? false), title: const Text('Vente liée à aucun lot')),
                    InputDecorator(
                      decoration: InputDecoration(labelText: 'Client', suffixIcon: _client != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _client = null)) : const Icon(Icons.search)),
                      child: InkWell(onTap: _pickClient, child: Text(_client == null ? 'Client comptoir — toucher pour choisir' : '${_client!['prenom'] ?? ''} ${_client!['nom'] ?? ''}'.trim())),
                    ),
                    if (_client == null) ...[const SizedBox(height: 12), TextFormField(controller: _clientLibre, decoration: const InputDecoration(labelText: 'Nom du client (facultatif)'))],
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(4)),
                      leading: const Icon(Icons.event),
                      title: Text(fmtDate(isoDate(_date))),
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now());
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Lignes', style: Theme.of(context).textTheme.titleMedium),
                    for (var i = 0; i < _lines.length; i++)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            Row(children: [
                              Expanded(child: TextFormField(controller: _lines[i].designation, decoration: const InputDecoration(labelText: 'Désignation *'), validator: (v) => (v ?? '').trim().isEmpty ? 'Requis' : null)),
                              if (_lines.length > 1) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _lines.removeAt(i).dispose())),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: TextFormField(controller: _lines[i].quantite, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Qté'), validator: _pos, onChanged: (_) => setState(() {}))),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _lines[i].unite, decoration: const InputDecoration(labelText: 'Unité'))),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: TextFormField(controller: _lines[i].prix, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix unitaire', suffixText: 'F'), validator: (v) => _pos(v, zero: true), onChanged: (_) => setState(() {}))),
                            ]),
                            Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(money(_lines[i].total), style: const TextStyle(fontWeight: FontWeight.bold)))),
                          ]),
                        ),
                      ),
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _lines.add(_Line())), icon: const Icon(Icons.add), label: const Text('Ajouter une ligne'))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _remise,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Remise globale', suffixText: '%'),
                      validator: (v) {
                        final n = num.tryParse((v ?? '0').replaceAll(',', '.'));
                        return n == null || n < 0 || n > 100 ? '0 à 100' : null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _mode,
                      decoration: const InputDecoration(labelText: 'Paiement'),
                      items: const [
                        DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                        DropdownMenuItem(value: 'mobile_money', child: Text('Mobile money')),
                        DropdownMenuItem(value: 'virement', child: Text('Virement')),
                        DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                        DropdownMenuItem(value: 'credit', child: Text('À crédit (rien encaissé)')),
                      ],
                      onChanged: (v) => _mode = v!,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
                    const Divider(height: 32),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Total', style: Theme.of(context).textTheme.titleMedium),
                      Text(money(_total.round()), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(),
                      icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                      label: const Text('Enregistrer la vente'),
                    ),
                    const SizedBox(height: 4),
                    Text('Le total définitif est recalculé par le serveur.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                  ])),
                ),
    );
  }
}

class _ClientPicker extends StatefulWidget {
  const _ClientPicker({required this.api});
  final ApiClient api;
  @override
  State<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends State<_ClientPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(12), child: TextField(autofocus: true, decoration: const InputDecoration(labelText: 'Rechercher un client', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _q = v.trim()))),
              ListTile(leading: const Icon(Icons.storefront), title: const Text('Client comptoir'), onTap: () => Navigator.pop(context, <String, dynamic>{})),
              Expanded(
                child: PagedList(
                  key: ValueKey(_q),
                  emptyText: 'Aucun client.',
                  fetch: (page) => widget.api.list('/clients', query: {'page': page, if (_q.isNotEmpty) 'q': _q}),
                  itemBuilder: (c, x) => ListTile(title: Text('${x['prenom'] ?? ''} ${x['nom'] ?? ''}'.trim()), subtitle: Text('${x['telephone'] ?? ''}'), onTap: () => Navigator.pop(context, x)),
                ),
              ),
            ]),
          ),
        ),
      );
}
