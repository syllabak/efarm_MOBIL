import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import 'sale_form.dart';

const _modes = {'especes': 'Espèces', 'virement': 'Virement', 'cheque': 'Chèque', 'mobile_money': 'Mobile money'};
const _paiementLabels = {'paye': 'Payée', 'partiel': 'Partielle', 'impaye': 'Impayée', 'annulee': 'Annulée'};

String money(Object? v) => '${fmtNum(v)} F';

Color? _paiementColor(String? s) => {'paye': Colors.green, 'partiel': Colors.orange, 'impaye': Colors.red, 'annulee': Colors.grey}[s];

// ── Ventes ───────────────────────────────────────────────────────────
class VentesPage extends ConsumerStatefulWidget {
  const VentesPage({super.key});
  @override
  ConsumerState<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends ConsumerState<VentesPage> {
  String _paiement = '';
  Key _k = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ventes')),
      floatingActionButton: const {'admin', 'responsable'}.contains(ref.watch(sessionProvider).value?.role)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Vente'),
              onPressed: () async {
                final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const SaleForm()));
                if (ok == true && mounted) setState(() => _k = UniqueKey());
              })
          : null,
      body: PagedList(
        key: _k,
        emptyText: 'Aucune vente.',
        fetch: (page) => api.list('/sales', query: {'page': page, if (_paiement.isNotEmpty) 'paiement': _paiement}),
        header: Column(children: [
          FutureBuilder<Map>(
            future: api.get<Map>('/sales/summary'),
            builder: (c, s) {
              if (s.hasError) return ListTile(leading: const Icon(Icons.error_outline), title: Text(errorText(s.error!)));
              if (!s.hasData) return const LinearProgressIndicator();
              final d = s.data!;
              return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.9, padding: const EdgeInsets.all(4), children: [
                Stat('CA du jour', money(d['ca_jour']), icon: Icons.today),
                Stat('CA du mois', money(d['ca_mois']), icon: Icons.calendar_month),
                Stat('CA de l\'année', money(d['ca_annee']), icon: Icons.trending_up),
                Stat('Créances (${d['nb_ventes_non_soldees']})', money(d['creances']), icon: Icons.hourglass_bottom, color: (d['creances'] as num) > 0 ? Colors.orange : null),
              ]);
            },
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (final e in {'': 'Toutes', 'non_soldee': 'À encaisser', 'impayee': 'Impayées', 'partielle': 'Partielles', 'soldee': 'Soldées'}.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(e.value), selected: _paiement == e.key, onSelected: (_) => setState(() {
                        _paiement = e.key;
                        _k = UniqueKey();
                      })),
                ),
            ]),
          ),
        ]),
        itemBuilder: (c, v) => Card(
          child: ListTile(
            title: Text('${v['numero']} · ${money(v['montant_total'])}'),
            subtitle: Text('${fmtDate(v['date_vente'])} · ${(v['client'] as String?)?.isNotEmpty == true ? v['client'] : 'Sans client'}'),
            trailing: Chip(label: Text(_paiementLabels['${v['paiement']}'] ?? '${v['paiement']}'), backgroundColor: _paiementColor('${v['paiement']}')?.withValues(alpha: 0.15)),
            onTap: () async {
              await Navigator.push(c, MaterialPageRoute(builder: (_) => VenteDetailPage(id: v['id'] as int)));
              if (mounted) setState(() => _k = UniqueKey());
            },
          ),
        ),
      ),
    );
  }
}

class VenteDetailPage extends ConsumerStatefulWidget {
  const VenteDetailPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<VenteDetailPage> createState() => _VenteDetailPageState();
}

class _VenteDetailPageState extends ConsumerState<VenteDetailPage> {
  Key _k = UniqueKey();

  Future<void> _encaisser(Map v) async {
    final reste = (v['situation']['reste'] as num);
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _PaymentDialog(reste: reste));
    if (r == null) return;
    try {
      await ref.read(apiProvider).post('/sales/${widget.id}/payments', body: r);
      if (!mounted) return;
      showInfo(context, 'Encaissement enregistré.');
      setState(() => _k = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final role = ref.watch(sessionProvider).value?.role;
    return Scaffold(
      appBar: AppBar(title: const Text('Vente')),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/sales/${widget.id}'),
        builder: (c, v) {
          final sit = Map<String, dynamic>.from(v['situation'] as Map);
          final canPay = const {'admin', 'responsable'}.contains(role) && sit['statut'] != 'annulee' && (sit['reste'] as num) > 0;
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
            Text('${v['numero']}', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 8),
            KeyValue('Date', fmtDate(v['date_vente'])),
            KeyValue('Client', v['client']),
            KeyValue('Téléphone', v['client_tel']),
            KeyValue('Site', v['site_nom']),
            KeyValue('Lot', v['lot_code']),
            KeyValue('Facture', v['numero_facture']),
            KeyValue('Mode', _modes['${v['mode_paiement']}'] ?? v['mode_paiement']),
            const Divider(height: 24),
            Text('Lignes', style: Theme.of(c).textTheme.titleMedium),
            for (final l in (v['lignes'] as List).cast<Map>())
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${l['designation']}'),
                subtitle: Text('${fmtNum(l['quantite'], digits: 2)} ${l['unite'] ?? ''} × ${money(l['prix_unitaire'])}'),
                trailing: Text(money(l['montant_ligne']), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            const Divider(height: 24),
            KeyValue('Total', money(sit['total'])),
            KeyValue('Encaissé', money(sit['encaisse'])),
            KeyValue('Reste à payer', money(sit['reste'])),
            KeyValue('Statut', _paiementLabels['${sit['statut']}']),
            if ((v['encaissements'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Encaissements', style: Theme.of(c).textTheme.titleMedium),
              for (final e in (v['encaissements'] as List).cast<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(money(e['montant'])),
                  subtitle: Text('${fmtDate(e['date_encaissement'])} · ${_modes['${e['mode']}'] ?? e['mode']}${e['reference'] != null ? ' · ${e['reference']}' : ''}'),
                ),
            ],
            if (canPay) Padding(padding: const EdgeInsets.only(top: 16), child: FilledButton.icon(onPressed: () => _encaisser(v), icon: const Icon(Icons.add_card), label: const Text('Encaisser un paiement'))),
          ]);
        },
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.reste});
  final num reste;
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _montant = TextEditingController(text: '${widget.reste}');
  final _ref = TextEditingController();
  String _mode = 'especes';
  final _form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Encaisser'),
        content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _montant,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Montant', helperText: 'Reste : ${money(widget.reste)}', suffixText: 'F'),
              validator: (v) {
                final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Montant invalide';
                if (n > widget.reste + 1) return 'Dépasse le reste à payer';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: _mode, decoration: const InputDecoration(labelText: 'Mode'), items: [for (final e in _modes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => _mode = v!),
            const SizedBox(height: 12),
            TextFormField(controller: _ref, decoration: const InputDecoration(labelText: 'Référence (facultatif)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, {'montant': num.parse(_montant.text.replaceAll(',', '.')), 'mode': _mode, 'date': isoDate(DateTime.now()), if (_ref.text.trim().isNotEmpty) 'reference': _ref.text.trim()});
                }
              },
              child: const Text('Valider')),
        ],
      );
}

// ── Clients ──────────────────────────────────────────────────────────
class ClientsVentePage extends ConsumerStatefulWidget {
  const ClientsVentePage({super.key});
  @override
  ConsumerState<ClientsVentePage> createState() => _ClientsVentePageState();
}

class _ClientsVentePageState extends ConsumerState<ClientsVentePage> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Rechercher'), onChanged: (v) => setState(() => _q = v.trim()))),
        Expanded(
          child: PagedList(
            key: ValueKey(_q),
            emptyText: 'Aucun client.',
            fetch: (page) => api.list('/clients', query: {'page': page, if (_q.isNotEmpty) 'q': _q}),
            itemBuilder: (c, x) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(('${x['nom'] ?? '?'}').characters.first.toUpperCase())),
                title: Text('${x['prenom'] ?? ''} ${x['nom'] ?? ''}'.trim()),
                subtitle: Text([x['telephone'], x['type_client']].whereType<String>().join(' · ')),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(x['total_achats']), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${x['nb_ventes']} vente(s)', style: Theme.of(c).textTheme.bodySmall),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Finance ──────────────────────────────────────────────────────────
class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});
  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> {
  DateTime _m = DateTime(DateTime.now().year, DateTime.now().month);
  Key _k = UniqueKey();

  void _shift(int d) => setState(() {
        _m = DateTime(_m.year, _m.month + d);
        _k = UniqueKey();
      });

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final mois = ['', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Dépense'),
        onPressed: () async {
          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ExpenseForm()));
          if (ok == true) setState(() => _k = UniqueKey());
        },
      ),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
          Text('${mois[_m.month]} ${_m.year}', style: Theme.of(context).textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _m.isBefore(DateTime(DateTime.now().year, DateTime.now().month)) ? () => _shift(1) : null),
        ]),
        Expanded(
          child: PagedList(
            key: _k,
            emptyText: 'Aucune dépense ce mois-ci.',
            fetch: (page) => api.list('/finance/expenses', query: {'page': page, 'du': isoDate(_m), 'au': isoDate(DateTime(_m.year, _m.month + 1, 0))}),
            header: FutureBuilder<Map>(
              future: api.get<Map>('/finance/summary', query: {'annee': _m.year, 'mois': _m.month}),
              builder: (c, s) {
                if (s.hasError) return ListTile(leading: const Icon(Icons.error_outline), title: Text(errorText(s.error!)));
                if (!s.hasData) return const LinearProgressIndicator();
                final d = s.data!;
                final net = d['benefice_net'] as num;
                return Column(children: [
                  GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.9, padding: const EdgeInsets.all(4), children: [
                    Stat('Ventes', money(d['total_ventes']), icon: Icons.south_west, color: Colors.green),
                    Stat('Dépenses', money(d['total_depenses']), icon: Icons.north_east, color: Colors.red),
                    Stat('Bénéfice net', money(net), icon: Icons.account_balance_wallet_outlined, color: net >= 0 ? Colors.green : Colors.red),
                    Stat('Trésorerie du mois', money(d['tresorerie_mois']), icon: Icons.savings_outlined),
                  ]),
                  ListTile(dense: true, title: Text('Créances : ${money(d['creances'])} (${d['nb_creances']} vente(s))'), subtitle: Text('ROI du mois : ${d['roi_pct']} %')),
                  for (final cat in (d['par_categorie'] as List).cast<Map>())
                    ListTile(dense: true, title: Text('${cat['categorie']}'), trailing: Text(money(cat['total']))),
                  const Divider(),
                ]);
              },
            ),
            itemBuilder: (c, x) => Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('${x['description']}'),
                subtitle: Text('${fmtDate(x['date_depense'])} · ${x['categorie'] ?? 'Non classé'}'),
                trailing: Text(money(x['montant']), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class ExpenseForm extends ConsumerStatefulWidget {
  const ExpenseForm({super.key});
  @override
  ConsumerState<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  final _form = GlobalKey<FormState>();
  final _montant = TextEditingController(), _desc = TextEditingController(), _facture = TextEditingController();
  List<Map<String, dynamic>> _cats = [], _sites = [];
  int? _cat, _site;
  DateTime _date = DateTime.now();
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
      _cats = [for (final c in await api.get<List>('/finance/categories')) Map<String, dynamic>.from(c as Map)];
      _sites = [for (final c in await api.get<List>('/farm/sites')) Map<String, dynamic>.from(c as Map)];
      final p = ref.read(sessionProvider).value!;
      _site = p.allSites ? null : p.siteId;
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).post('/finance/expenses', body: {
        'montant': num.parse(_montant.text.replaceAll(',', '.')),
        'categorie_id': _cat,
        'description': _desc.text.trim(),
        'date_depense': isoDate(_date),
        'site_id': ?_site,
        if (_facture.text.trim().isNotEmpty) 'facture_ref': _facture.text.trim(),
      });
      if (!mounted) return;
      showInfo(context, 'Dépense enregistrée.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    TextFormField(
                      controller: _montant,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Montant *', suffixText: 'F'),
                      validator: (v) => (num.tryParse((v ?? '').replaceAll(',', '.')) ?? 0) > 0 ? null : 'Montant invalide',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _cat,
                      decoration: const InputDecoration(labelText: 'Catégorie *'),
                      items: [for (final c in _cats) DropdownMenuItem(value: c['id'] as int, child: Text('${c['nom']}'))],
                      onChanged: (v) => _cat = v,
                      validator: (v) => v == null ? 'Requis' : null,
                    ),
                    if (allSites) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _site,
                        decoration: const InputDecoration(labelText: 'Site *'),
                        items: [for (final s in _sites) DropdownMenuItem(value: s['id'] as int, child: Text('${s['nom']}'))],
                        onChanged: (v) => _site = v,
                        validator: (v) => v == null ? 'Requis' : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description *'), validator: (v) => (v ?? '').trim().isEmpty ? 'Requis' : null),
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
                    const SizedBox(height: 12),
                    TextFormField(controller: _facture, decoration: const InputDecoration(labelText: 'N° de facture (facultatif)')),
                    const SizedBox(height: 20),
                    FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
                  ]),
                ),
    );
  }
}
