import 'package:flutter/material.dart' hide Text;
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/server_support.dart';
import '../../core/session.dart';
import '../../ui/common.dart';
import '../modules/module_pages.dart';
import '../modules/spec.dart';

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
      appBar: AppBar(title: const Text('Devis et factures'), actions: [
        IconButton(
          tooltip: tr('Vente au comptoir'),
          icon: const Icon(Icons.point_of_sale),
          onPressed: () async {
            try {
              final r = await api.get<Map>('/vet/counter-client');
              if (!mounted) return;
              final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DynamicFormPage(
                          title: 'Vente au comptoir',
                          successMessage: 'Facture enregistrée en brouillon : émettez-la puis encaissez.',
                          fields: documentFields('facture'),
                          initialValues: {'client_id': r['client_id'], 'client_id_label': 'Passage (vente comptoir)'},
                          submit: (b) => api.post('/vet/documents', body: {...b, 'type': 'facture'}))));
              if (ok == true && mounted) setState(() => _k = UniqueKey());
            } catch (e) {
              if (mounted) showError(context, e);
            }
          },
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(_type == 'facture' ? 'Facture' : 'Devis'),
        onPressed: () async {
          final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => DynamicFormPage(
                      title: _type == 'facture' ? 'Nouvelle facture' : 'Nouveau devis',
                      successMessage: 'Enregistré en brouillon.',
                      fields: documentFields(_type),
                      submit: (b) => api.post('/vet/documents', body: {...b, 'type': _type}))));
          if (ok == true && mounted) setState(() => _k = UniqueKey());
        },
      ),
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

  void _reload() => setState(() => _k = UniqueKey());

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

  Future<void> _deletePayment(Map p) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(title: const Text('Supprimer le paiement'), content: Text('Supprimer l\'encaissement de ${fcfa(p['montant'])} ? Le reste à payer de la facture sera recalculé.'), actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error), onPressed: () => Navigator.pop(d, true), child: const Text('Confirmer')),
            ]));
    if (yes != true) return;
    try {
      await ref.read(apiProvider).post('/vet/payments/${p['id']}/delete');
      if (!mounted) return;
      showInfo(context, 'Paiement supprimé.');
      _reload();
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
            TitleBanner('${facture ? 'Facture' : 'Devis'} ${d['numero']}'),
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
                  trailing: p['id'] != null && serverCan('POST', '/vet/payments/{id}/delete') ? IconButton(tooltip: tr('Supprimer ce paiement'), icon: const Icon(Icons.delete_outline), onPressed: () => _deletePayment(p)) : null,
                ),
            ],
            if ((d['notes'] as String?)?.isNotEmpty == true) KeyValue('Notes', d['notes']),
            if (canPay) Padding(padding: const EdgeInsets.only(top: 16), child: FilledButton.icon(onPressed: () => _pay(reste), icon: const Icon(Icons.add_card), label: const Text('Encaisser un paiement'))),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (facture && d['statut'] == 'brouillon') VetActionButton(label: tr('Émettre'), icon: Icons.verified_outlined, path: '/vet/documents/${widget.id}/status', body: const {'action': 'emettre'}, confirm: 'Émettre cette facture ? Le stock des produits sera déduit et la facture ne sera plus modifiable.', onDone: _reload),
              if (facture && d['statut'] == 'emise' && (d['paye'] as num) <= 0) VetActionButton(label: tr('Annuler la facture'), icon: Icons.block, path: '/vet/documents/${widget.id}/status', body: const {'action': 'annuler'}, confirm: 'Annuler cette facture ? Le stock sera remis en place.', destructive: true, onDone: _reload),
              if (!facture && const {'brouillon', 'envoye'}.contains(d['statut'])) VetActionButton(label: tr('Marquer envoyé'), icon: Icons.send_outlined, path: '/vet/documents/${widget.id}/status', body: const {'action': 'envoye'}, onDone: _reload),
              if (!facture && const {'brouillon', 'envoye'}.contains(d['statut'])) VetActionButton(label: tr('Accepté'), icon: Icons.thumb_up_outlined, path: '/vet/documents/${widget.id}/status', body: const {'action': 'accepte'}, onDone: _reload),
              if (!facture && const {'brouillon', 'envoye'}.contains(d['statut'])) VetActionButton(label: tr('Refusé'), icon: Icons.thumb_down_outlined, path: '/vet/documents/${widget.id}/status', body: const {'action': 'refuse'}, onDone: _reload),
              if (!facture && d['statut'] != 'refuse') VetActionButton(label: tr('Convertir en facture'), icon: Icons.swap_horiz, path: '/vet/documents/${widget.id}/convert', onDone: _reload),
              if ((facture && d['statut'] == 'brouillon') || (!facture && const {'brouillon', 'envoye'}.contains(d['statut'])))
                FilledButton.tonalIcon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier'),
                    onPressed: () async {
                      final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DynamicFormPage(
                                  title: 'Modifier ${d['numero']}',
                                  successMessage: 'Document modifié.',
                                  fields: documentFields('${d['type']}'),
                                  initialValues: {...Map<String, dynamic>.from(d), 'client_id_label': d['client_nom']},
                                  submit: (b) => ref.read(apiProvider).post('/vet/documents', body: {...b, 'id': widget.id, 'type': d['type']}))));
                      if (ok == true) _reload();
                    }),
              if (const {'brouillon', 'refuse'}.contains(d['statut'])) VetActionButton(label: tr('Supprimer'), icon: Icons.delete_outline, path: '/vet/documents/${widget.id}/delete', confirm: 'Supprimer ce document ?', destructive: true, popAfter: true, onDone: _reload),
            ]),
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
              decoration: InputDecoration(labelText: tr('Montant'), helperText: tr('Reste : ${fcfa(widget.reste)}'), suffixText: 'F'),
              validator: (v) {
                final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Montant invalide';
                if (n > widget.reste + 0.5) return 'Dépasse le reste à payer';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: _mode, decoration: InputDecoration(labelText: tr('Mode')), items: [for (final e in _modesVet.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => _mode = v!),
            const SizedBox(height: 12),
            TextFormField(controller: _ref, decoration: InputDecoration(labelText: tr('Référence (facultatif)'))),
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
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ordonnance'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DynamicFormPage(title: 'Nouvelle ordonnance', successMessage: 'Ordonnance enregistrée en brouillon.', fields: ordonnanceFields, submit: (b) => api.post('/vet/ordonnances', body: b)))),
      ),
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

class OrdonnanceDetailPage extends ConsumerStatefulWidget {
  const OrdonnanceDetailPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<OrdonnanceDetailPage> createState() => _OrdonnanceDetailPageState();
}

class _OrdonnanceDetailPageState extends ConsumerState<OrdonnanceDetailPage> {
  Key _k = UniqueKey();
  void _reload() => setState(() => _k = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final id = widget.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Ordonnance')),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/vet/ordonnances/$id'),
        builder: (c, o) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          TitleBanner('${o['numero']}'),
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
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (o['statut'] == 'brouillon') VetActionButton(label: tr('Émettre'), icon: Icons.verified_outlined, path: '/vet/ordonnances/$id/issue', confirm: 'Émettre cette ordonnance ? Elle ne sera plus modifiable.', onDone: _reload),
            if (o['statut'] != 'brouillon' && o['facture_id'] == null) VetActionButton(label: tr('Créer la facture'), icon: Icons.receipt_long_outlined, path: '/vet/ordonnances/$id/bill', onDone: _reload),
            if (o['statut'] == 'brouillon')
              FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                  onPressed: () async {
                    final ok = await Navigator.push<bool>(
                        c,
                        MaterialPageRoute(
                            builder: (_) => DynamicFormPage(
                                title: 'Modifier ${o['numero']}',
                                successMessage: 'Ordonnance modifiée.',
                                fields: ordonnanceFields,
                                initialValues: {...Map<String, dynamic>.from(o), 'client_id_label': o['client_nom']},
                                submit: (b) => api.post('/vet/ordonnances', body: {...b, 'id': id}))));
                    if (ok == true) _reload();
                  }),
            if (o['statut'] == 'brouillon') VetActionButton(label: tr('Supprimer'), icon: Icons.delete_outline, path: '/vet/ordonnances/$id/delete', confirm: 'Supprimer cette ordonnance ?', destructive: true, popAfter: true, onDone: _reload),
          ]),
        ]),
      ),
    );
  }
}

// ── Formulaires et actions de gestion (devis, factures, ordonnances) ──
const _lignesDoc = FieldSpec('lignes', 'Lignes', type: FieldType.lines, required: true, lineFields: [
  FieldSpec('article_id', 'Article du catalogue (facultatif)', type: FieldType.select, optionsPath: '/vet/articles', optionsQuery: {'per_page': 100},
      fill: {'designation': 'nom', 'unite': 'unite', 'prix_unitaire': 'prix_vente', 'tva_pct': 'tva_pct'}),
  FieldSpec('designation', 'Désignation', required: true),
  FieldSpec('quantite', 'Quantité', type: FieldType.number, required: true, min: 0.001, initial: 1),
  FieldSpec('unite', 'Unité'),
  FieldSpec('prix_unitaire', 'Prix unitaire', type: FieldType.number, required: true, suffix: 'F', min: 0),
  FieldSpec('remise_pct', 'Remise', type: FieldType.number, suffix: '%', min: 0),
  FieldSpec('tva_pct', 'TVA', type: FieldType.number, suffix: '%', min: 0),
]);

List<FieldSpec> documentFields(String type) => [
      const FieldSpec('client_id', 'Client', type: FieldType.pick, required: true, optionsPath: '/vet/clients', optionLabel: 'nom'),
      const FieldSpec('date_emission', 'Date', type: FieldType.date, initial: 'today'),
      const FieldSpec('date_echeance', 'Échéance', type: FieldType.date),
      _lignesDoc,
      const FieldSpec('notes', 'Notes', type: FieldType.multiline),
    ];

const _lignesOrd = FieldSpec('lignes', 'Médicaments', type: FieldType.lines, required: true, lineFields: [
  FieldSpec('article_id', 'Produit du catalogue (facultatif)', type: FieldType.select, optionsPath: '/vet/articles', optionsQuery: {'per_page': 100, 'type': 'produit'}, fill: {'designation': 'nom'}),
  FieldSpec('designation', 'Désignation', required: true),
  FieldSpec('dosage', 'Dosage'),
  FieldSpec('voie', 'Voie (orale, injectable…)'),
  FieldSpec('duree', 'Durée du traitement'),
  FieldSpec('quantite', 'Quantité', type: FieldType.number, min: 0.001, initial: 1),
]);

const ordonnanceFields = [
  FieldSpec('client_id', 'Client', type: FieldType.pick, required: true, optionsPath: '/vet/clients', optionLabel: 'nom'),
  FieldSpec('animal', 'Animal / troupeau / lot'),
  FieldSpec('date_ordonnance', 'Date', type: FieldType.date, initial: 'today'),
  FieldSpec('diagnostic', 'Diagnostic'),
  _lignesOrd,
  FieldSpec('instructions', 'Instructions', type: FieldType.multiline),
  FieldSpec('delai_viande_jours', 'Délai d\'attente viande', type: FieldType.integer, suffix: 'jours', min: 0),
  FieldSpec('delai_oeufs_jours', 'Délai d\'attente œufs', type: FieldType.integer, suffix: 'jours', min: 0),
];

/// Bouton d'action POST avec confirmation facultative ; recharge l'écran appelant au succès.
class VetActionButton extends ConsumerWidget {
  const VetActionButton({super.key, required this.label, required this.icon, required this.path, required this.onDone, this.body, this.confirm, this.destructive = false, this.popAfter = false});
  final String label, path;
  final IconData icon;
  final VoidCallback onDone;
  final Map<String, dynamic>? body;
  final String? confirm;
  final bool destructive, popAfter;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton.tonalIcon(
        style: destructive ? FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error) : null,
        icon: Icon(icon),
        label: Text(label),
        onPressed: () async {
          if (confirm != null) {
            final yes = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(title: Text(label), content: Text(confirm!), actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer')),
                    ]));
            if (yes != true) return;
          }
          try {
            await ref.read(apiProvider).post(path, body: body);
            if (!context.mounted) return;
            if (popAfter) {
              Navigator.pop(context, true);
            } else {
              onDone();
            }
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
      );
}
