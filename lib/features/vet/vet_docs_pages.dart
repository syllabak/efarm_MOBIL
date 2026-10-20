import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';

const _modesVet = {
  'especes': 'Espèces', 'wave': 'Wave', 'orange_money': 'Orange Money', 'mobile_money': 'Autre mobile money', 'virement': 'Virement', 'cheque': 'Chèque', 'autre': 'Autre',
};
const _etats = {'impayee': 'Impayée', 'partielle': 'Partielle', 'payee': 'Payée', 'annulee': 'Annulée', 'brouillon': 'Brouillon'};
const _statutsDevis = {'brouillon': 'Brouillon', 'envoye': 'Envoyé', 'accepte': 'Accepté', 'refuse': 'Refusé'};

String fcfa(Object? v) => '${fmtNum(v)} F';

Color? _etatColor(String? s) => {'payee': Colors.green, 'partielle': Colors.orange, 'impayee': Colors.red, 'annulee': Colors.grey}[s];

/// Devis et factures du cabinet (consultation + encaissement ; l'émission reste sur le web).
class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _type = 'facture';
  Key _k = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Devis et factures')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'facture', label: Text('Factures')), ButtonSegment(value: 'devis', label: Text('Devis'))],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _k = UniqueKey();
            }),
          ),
        ),
        Expanded(
          child: PagedList(
            key: _k,
            emptyText: _type == 'facture' ? 'Aucune facture.' : 'Aucun devis.',
            fetch: (page) => api.list('/vet/documents', query: {'page': page, 'type': _type}),
            itemBuilder: (c, d) {
              final etat = '${d['paiement']}';
              final facture = d['type'] == 'facture';
              final label = facture ? (_etats[etat] ?? etat) : (_statutsDevis['${d['statut']}'] ?? '${d['statut']}');
              return Card(
                child: ListTile(
                  title: Text('${d['numero']} · ${fcfa(d['total_ttc'])}'),
                  subtitle: Text('${d['client']} · ${fmtDate(d['date_emission'])}'),
                  trailing: Chip(label: Text(label), backgroundColor: facture ? _etatColor(etat)?.withValues(alpha: 0.15) : null),
                  onTap: () async {
                    await Navigator.push(c, MaterialPageRoute(builder: (_) => DocumentDetailPage(id: d['id'] as int)));
                    if (mounted) setState(() => _k = UniqueKey());
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class DocumentDetailPage extends ConsumerStatefulWidget {
  const DocumentDetailPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends ConsumerState<DocumentDetailPage> {
  Key _k = UniqueKey();

  Future<void> _pay(num reste) async {
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _VetPaymentDialog(reste: reste));
    if (r == null) return;
    try {
      await ref.read(apiProvider).post('/vet/documents/${widget.id}/payments', body: r);
      if (!mounted) return;
      showInfo(context, 'Paiement enregistré.');
      setState(() => _k = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Document')),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/vet/documents/${widget.id}'),
        builder: (c, d) {
          final facture = d['type'] == 'facture';
          final reste = (d['reste'] as num);
          final canPay = facture && d['statut'] == 'emise' && reste > 0;
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
            Text('${facture ? 'Facture' : 'Devis'} ${d['numero']}', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 8),
            KeyValue('Client', (d['client'] as Map?)?['nom']),
            KeyValue('Téléphone', (d['client'] as Map?)?['telephone']),
            KeyValue('Émission', fmtDate(d['date_emission'])),
            if (d['date_echeance'] != null) KeyValue('Échéance', fmtDate(d['date_echeance'])),
            KeyValue('Statut', facture ? _etats['${d['paiement']}'] : _statutsDevis['${d['statut']}']),
            const Divider(height: 24),
            for (final l in (d['lignes'] as List).cast<Map>())
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${l['designation']}'),
                subtitle: Text('${fmtNum(l['quantite'], digits: 2)} ${l['unite'] ?? ''} × ${fcfa(l['prix_unitaire'])}${(num.tryParse('${l['remise_pct']}') ?? 0) > 0 ? ' (−${l['remise_pct']} %)' : ''}'),
                trailing: Text(fcfa(l['total_ttc']), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            const Divider(height: 24),
            KeyValue('Total HT', fcfa(d['total_ht'])),
            KeyValue('TVA', fcfa(d['tva_total'])),
            KeyValue('Total TTC', fcfa(d['total_ttc'])),
            if (facture) ...[
              KeyValue('Payé', fcfa(d['paye'])),
              KeyValue('Reste à payer', fcfa(reste)),
              for (final p in (d['paiements'] as List).cast<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(fcfa(p['montant'])),
                  subtitle: Text('${fmtDate(p['date_paiement'])} · ${_modesVet['${p['mode']}'] ?? p['mode']}${p['reference'] != null ? ' · ${p['reference']}' : ''}'),
                ),
            ],
            if ((d['notes'] as String?)?.isNotEmpty == true) KeyValue('Notes', d['notes']),
            if (canPay) Padding(padding: const EdgeInsets.only(top: 16), child: FilledButton.icon(onPressed: () => _pay(reste), icon: const Icon(Icons.add_card), label: const Text('Encaisser un paiement'))),
          ]);
        },
      ),
    );
  }
}

class _VetPaymentDialog extends StatefulWidget {
  const _VetPaymentDialog({required this.reste});
  final num reste;
  @override
  State<_VetPaymentDialog> createState() => _VetPaymentDialogState();
}

class _VetPaymentDialogState extends State<_VetPaymentDialog> {
  late final _montant = TextEditingController(text: '${widget.reste.round()}');
  final _ref = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _mode = 'especes';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Encaisser'),
        content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _montant,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Montant', helperText: 'Reste : ${fcfa(widget.reste)}', suffixText: 'F'),
              validator: (v) {
                final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Montant invalide';
                if (n > widget.reste + 0.5) return 'Dépasse le reste à payer';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: _mode, decoration: const InputDecoration(labelText: 'Mode'), items: [for (final e in _modesVet.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => _mode = v!),
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

// ── Ordonnances ──────────────────────────────────────────────────────
class OrdonnancesPage extends ConsumerWidget {
  const OrdonnancesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    const st = {'brouillon': 'Brouillon', 'emise': 'Émise', 'dispensee': 'Dispensée'};
    return Scaffold(
      appBar: AppBar(title: const Text('Ordonnances')),
      body: PagedList(
        emptyText: 'Aucune ordonnance.',
        fetch: (page) => api.list('/vet/ordonnances', query: {'page': page}),
        itemBuilder: (c, o) => Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text('${o['numero']} · ${o['client']}'),
            subtitle: Text('${fmtDate(o['date_ordonnance'])}${o['animal'] != null ? ' · ${o['animal']}' : ''}${o['diagnostic'] != null ? '\n${o['diagnostic']}' : ''}'),
            isThreeLine: o['diagnostic'] != null,
            trailing: Chip(label: Text(st['${o['statut']}'] ?? '${o['statut']}')),
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => OrdonnanceDetailPage(id: o['id'] as int))),
          ),
        ),
      ),
    );
  }
}

class OrdonnanceDetailPage extends ConsumerWidget {
  const OrdonnanceDetailPage({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ordonnance')),
      body: AsyncView<Map>(
        load: () => api.get<Map>('/vet/ordonnances/$id'),
        builder: (c, o) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          Text('${o['numero']}', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 8),
          KeyValue('Client', (o['client'] as Map?)?['nom']),
          KeyValue('Animal / lot', o['animal']),
          KeyValue('Date', fmtDate(o['date_ordonnance'])),
          KeyValue('Diagnostic', o['diagnostic']),
          if (o['delai_viande_jours'] != null) KeyValue('Délai viande', '${o['delai_viande_jours']} jours'),
          if (o['delai_oeufs_jours'] != null) KeyValue('Délai œufs', '${o['delai_oeufs_jours']} jours'),
          const Divider(height: 24),
          for (final l in (o['lignes'] as List).cast<Map>())
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.medication_outlined),
              title: Text('${l['designation']}'),
              subtitle: Text([l['dosage'], l['voie'], l['duree']].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
              trailing: Text('× ${fmtNum(l['quantite'], digits: 1)}'),
            ),
          if ((o['instructions'] as String?)?.isNotEmpty == true) ...[const Divider(height: 24), KeyValue('Instructions', o['instructions'])],
        ]),
      ),
    );
  }
}
