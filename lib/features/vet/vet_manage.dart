import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import '../modules/data_view.dart';
import '../modules/module_pages.dart';
import '../modules/spec.dart';

String _s(Object? v) => v == null ? '' : '$v';
String _join(Iterable<Object?> parts, [String sep = ' · ']) => parts.where((e) => e != null && '$e'.isNotEmpty).join(sep);
String fcfa(Object? v) => '${fmtNum(v)} F';

const _categoriesArticle = {
  'medicament': 'Médicament', 'vaccin': 'Vaccin', 'antiparasitaire': 'Antiparasitaire', 'complement': 'Complément / vitamines', 'desinfectant': 'Désinfectant',
  'materiel': 'Matériel', 'consommable': 'Consommable', 'consultation': 'Consultation', 'acte': 'Acte', 'autre': 'Autre',
};
const niveauxStock = {'rupture': 'Rupture', 'critique': 'Stock critique', 'faible': 'Stock faible', 'ok': 'Correct'};

// ── Catalogue ────────────────────────────────────────────────────────
const _articleFields = [
  FieldSpec('type', 'Type', type: FieldType.select, required: true, initial: 'produit', options: {'produit': 'Produit (géré en stock)', 'service': 'Prestation'}),
  FieldSpec('nom', 'Nom', required: true),
  FieldSpec('categorie', 'Catégorie', type: FieldType.select, options: _categoriesArticle),
  FieldSpec('code', 'Code'),
  FieldSpec('unite', 'Unité', hint: 'dose, flacon, boîte, acte…'),
  FieldSpec('prix_achat', 'Prix d\'achat', type: FieldType.number, suffix: 'F', min: 0),
  FieldSpec('prix_vente', 'Prix de vente', type: FieldType.number, suffix: 'F', min: 0),
  FieldSpec('tva_pct', 'TVA', type: FieldType.number, suffix: '%', min: 0),
  FieldSpec('seuil_alerte', 'Seuil d\'alerte du stock', type: FieldType.number, min: 0),
  FieldSpec('seuil_minimum', 'Stock minimum (critique)', type: FieldType.number, min: 0),
  FieldSpec('ordonnance_requise', 'Ordonnance requise', type: FieldType.bool),
  FieldSpec('delai_viande_jours', 'Délai d\'attente viande', type: FieldType.integer, suffix: 'jours', min: 0),
  FieldSpec('delai_oeufs_jours', 'Délai d\'attente œufs', type: FieldType.integer, suffix: 'jours', min: 0),
  FieldSpec('code_barres', 'Code-barres'),
  FieldSpec('emplacement', 'Emplacement'),
];

final vetCatalogueModule = ModuleSpec(
  id: 'vet_articles',
  title: 'Catalogue',
  icon: Icons.inventory_outlined,
  listPath: '/vet/articles',
  searchParam: 'q',
  filters: const [FilterSpec('type', {'': 'Tout', 'produit': 'Produits', 'service': 'Prestations'})],
  itemTitle: (r) => _s(r['nom']),
  itemSubtitle: (r) => _join([_categoriesArticle['${r['categorie']}'], r['code'], r['unite']]),
  itemTrailing: (r) => fcfa(r['prix_vente']),
  detailFromList: true,
  exportColumns: const [('nom', 'Nom'), ('type', 'Type'), ('categorie', 'Catégorie'), ('code', 'Code'), ('unite', 'Unité'), ('prix_achat', 'Prix d\'achat'), ('prix_vente', 'Prix de vente'), ('tva_pct', 'TVA %')],
  detailTitle: (r) => _s(r['nom']),
  detail: [
    ColumnSpec('type', 'Type', fmt: Fmt.label, labels: const {'produit': 'Produit', 'service': 'Prestation'}),
    ColumnSpec('categorie', 'Catégorie', fmt: Fmt.label, labels: _categoriesArticle),
    const ColumnSpec('code', 'Code'),
    const ColumnSpec('unite', 'Unité'),
    const ColumnSpec('prix_achat', 'Prix d\'achat', fmt: Fmt.money),
    const ColumnSpec('prix_vente', 'Prix de vente', fmt: Fmt.money),
    const ColumnSpec('tva_pct', 'TVA', fmt: Fmt.percent),
    const ColumnSpec('seuil_alerte', 'Seuil d\'alerte', fmt: Fmt.number),
    const ColumnSpec('ordonnance_requise', 'Ordonnance requise', fmt: Fmt.bool),
    const ColumnSpec('code_barres', 'Code-barres'),
    const ColumnSpec('emplacement', 'Emplacement'),
  ],
  actions: const [
    ActionSpec('Modifier', '/vet/articles/{id}', icon: Icons.edit_outlined, prefill: true, fields: _articleFields, successMessage: 'Article mis à jour.'),
    ActionSpec('Supprimer', '/vet/articles/{id}/delete', icon: Icons.delete_outline, destructive: true, confirm: 'Supprimer cet article du catalogue ?', successMessage: 'Article supprimé.'),
  ],
  create: const CreateSpec('Article', '/vet/articles', _articleFields, successMessage: 'Article ajouté.'),
  emptyText: 'Le catalogue est vide.',
);

// ── Fournisseurs du cabinet ──────────────────────────────────────────
const _fourFields = [
  FieldSpec('nom', 'Nom', required: true),
  FieldSpec('telephone', 'Téléphone', type: FieldType.phone),
  FieldSpec('email', 'E-mail', type: FieldType.email),
  FieldSpec('adresse', 'Adresse'),
  FieldSpec('notes', 'Notes'),
];

final vetSuppliersModule = ModuleSpec(
  id: 'vet_suppliers',
  title: 'Fournisseurs',
  icon: Icons.local_shipping_outlined,
  listPath: '/vet/suppliers',
  listIsPlain: true,
  itemTitle: (r) => _s(r['nom']),
  itemSubtitle: (r) => _join([r['telephone'], r['email']]),
  itemTrailing: (r) => (num.tryParse(_s(r['achats'])) ?? 0) > 0 ? fcfa(r['achats']) : '',
  detailFromList: true,
  detailTitle: (r) => _s(r['nom']),
  detail: const [
    ColumnSpec('telephone', 'Téléphone'),
    ColumnSpec('email', 'E-mail'),
    ColumnSpec('adresse', 'Adresse'),
    ColumnSpec('achats', 'Achats cumulés', fmt: Fmt.money),
    ColumnSpec('notes', 'Notes'),
  ],
  actions: const [
    ActionSpec('Modifier', '/vet/suppliers/{id}', icon: Icons.edit_outlined, prefill: true, fields: _fourFields, successMessage: 'Fournisseur mis à jour.'),
    ActionSpec('Supprimer', '/vet/suppliers/{id}/delete', icon: Icons.delete_outline, destructive: true, confirm: 'Supprimer ce fournisseur ?', successMessage: 'Fournisseur supprimé.'),
  ],
  create: const CreateSpec('Fournisseur', '/vet/suppliers', _fourFields, successMessage: 'Fournisseur ajouté.'),
  emptyText: 'Aucun fournisseur.',
);

// ── Produit de pharmacie (détail) ────────────────────────────────────
final vetProductModule = ModuleSpec(
  id: 'vet_product',
  title: 'Produit',
  icon: Icons.medication_outlined,
  listPath: '/vet/pharmacy',
  itemTitle: (r) => _s(r['nom']),
  detailPath: '/vet/pharmacy/{id}',
  detailTitle: (r) => _s(r['nom']),
  detail: const [
    ColumnSpec('stock', 'Stock disponible', fmt: Fmt.decimal),
    ColumnSpec('unite', 'Unité'),
    ColumnSpec('seuil_alerte', 'Seuil d\'alerte', fmt: Fmt.decimal),
    ColumnSpec('seuil_minimum', 'Stock minimum', fmt: Fmt.decimal),
    ColumnSpec('prix_achat', 'Prix d\'achat', fmt: Fmt.money),
    ColumnSpec('prix_vente', 'Prix de vente', fmt: Fmt.money),
    ColumnSpec('emplacement', 'Emplacement'),
    ColumnSpec('code_barres', 'Code-barres'),
  ],
  sections: [
    SectionSpec('lots', 'Lots', (r) => _join([r['numero_lot'] ?? 'Sans n°', r['date_peremption'] != null ? 'périme ${fmtDate(r['date_peremption'])}' : null]),
        itemSubtitle: (r) => _join([fmtDate(r['date_reception']), r['fournisseur']]), itemTrailing: (r) => '${fmtNum(r['quantite_restante'], digits: 1)}/${fmtNum(r['quantite_initiale'], digits: 1)}'),
    SectionSpec('mouvements', 'Mouvements récents', (r) => _s(r['type']), itemSubtitle: (r) => _join([fmtDateTime(r['created_at']), r['utilisateur']]), itemTrailing: (r) => fmtNum(r['quantite'], digits: 1)),
  ],
  actions: [
    ActionSpec('Réception de stock', '/vet/pharmacy/entry', icon: Icons.add_box_outlined, idKey: 'article_id', successMessage: 'Réception enregistrée.', fields: [
      const FieldSpec('quantite', 'Quantité reçue', type: FieldType.number, required: true, min: 0.001),
      const FieldSpec('numero_lot', 'N° de lot'),
      const FieldSpec('date_peremption', 'Date de péremption', type: FieldType.date),
      const FieldSpec('prix_achat', 'Prix d\'achat unitaire', type: FieldType.number, suffix: 'F', min: 0),
      const FieldSpec('fournisseur_id', 'Fournisseur', type: FieldType.select, optionsPath: '/vet/suppliers'),
      const FieldSpec('creer_depense', 'Enregistrer la dépense d\'achat', type: FieldType.bool),
      const FieldSpec('date_reception', 'Date de réception', type: FieldType.date, initial: 'today'),
    ]),
    ActionSpec('Perte, péremption, ajustement', '/vet/pharmacy/movement', icon: Icons.tune, idKey: 'article_id', successMessage: 'Mouvement enregistré.', fields: [
      const FieldSpec('type', 'Type', type: FieldType.select, required: true, options: {'perte': 'Perte / casse', 'peremption': 'Produits périmés retirés', 'ajustement': 'Ajustement d\'inventaire'}),
      const FieldSpec('quantite', 'Quantité', type: FieldType.number, required: true, hint: 'Positive pour retirer ; pour un ajustement, positive = ajout, négative = retrait'),
      const FieldSpec('note', 'Note'),
    ]),
  ],
);

/// Pharmacie : stock par produit, alertes de niveau et péremptions.
class PharmacyPage extends ConsumerStatefulWidget {
  const PharmacyPage({super.key});
  @override
  ConsumerState<PharmacyPage> createState() => _PharmacyPageState();
}

class _PharmacyPageState extends ConsumerState<PharmacyPage> {
  Key _k = UniqueKey();
  String _niveau = '';

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacie')),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/vet/pharmacy'),
        builder: (c, d) {
          final all = (d['stock'] as List).cast<Map>();
          final stock = [for (final a in all) if (_niveau.isEmpty ? true : (_niveau == 'alerte' ? a['niveau'] != 'ok' : a['niveau'] == _niveau)) a];
          final per = (d['peremptions'] as List).cast<Map>();
          return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
            ListTile(leading: const Icon(Icons.savings_outlined), title: Text('Valeur du stock : ${fcfa(d['valeur_totale'])}'), subtitle: Text('${all.length} produits · ${per.length} lot(s) proche(s) de la péremption')),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                for (final e in {'': 'Tous', 'alerte': 'À surveiller', 'rupture': 'Ruptures'}.entries)
                  Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(e.value), selected: _niveau == e.key, onSelected: (_) => setState(() => _niveau = e.key))),
              ]),
            ),
            if (per.isNotEmpty && _niveau.isEmpty)
              Card(
                color: Theme.of(c).colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.hourglass_bottom),
                  title: const Text('Péremptions proches'),
                  subtitle: Text(per.take(3).map((p) => '${p['nom'] ?? p['article'] ?? ''} (${fmtDate(p['date_peremption'])})').join('\n')),
                  isThreeLine: per.length > 1,
                  trailing: TextButton(
                      onPressed: () async {
                        try {
                          final r = await api.post<Map>('/vet/pharmacy/expired');
                          if (!mounted) return;
                          showInfo(context, '${r['retires']} produit(s) périmé(s) retiré(s).');
                          setState(() => _k = UniqueKey());
                        } catch (e) {
                          if (mounted) showError(context, e);
                        }
                      },
                      child: const Text('Retirer les périmés')),
                ),
              ),
            if (stock.isEmpty) const SizedBox(height: 200, child: EmptyView('Aucun produit.')),
            for (final a in stock)
              Card(
                child: ListTile(
                  leading: Icon(a['niveau'] == 'ok' ? Icons.check_circle_outline : Icons.warning_amber, color: a['niveau'] == 'rupture' ? Colors.red : (a['niveau'] == 'ok' ? Colors.green : Colors.orange)),
                  title: Text('${a['nom']}'),
                  subtitle: Text(_join([niveauxStock['${a['niveau']}'], if (a['prochaine_peremption'] != null) 'périme ${fmtDate(a['prochaine_peremption'])}', if ((a['stock_perime'] as num) > 0) 'dont ${fmtNum(a['stock_perime'], digits: 1)} périmé'])),
                  trailing: Text('${fmtNum(a['stock'], digits: 1)} ${a['unite'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await Navigator.push(c, MaterialPageRoute(builder: (_) => ModuleDetailPage(vetProductModule, a['id'])));
                    if (mounted) setState(() => _k = UniqueKey());
                  },
                ),
              ),
            const SizedBox(height: 40),
          ]);
        },
      ),
    );
  }
}

// ── Commandes fournisseurs ───────────────────────────────────────────
const _statutsCommande = {'brouillon': 'Brouillon', 'envoyee': 'Envoyée', 'recue': 'Reçue', 'annulee': 'Annulée'};

final vetOrdersModule = ModuleSpec(
  id: 'vet_orders',
  title: 'Commandes',
  icon: Icons.shopping_cart_outlined,
  listPath: '/vet/orders',
  listIsPlain: true,
  itemTitle: (r) => _join([r['numero'], r['fournisseur']]),
  itemSubtitle: (r) => _join([fmtDate(r['date_commande']), _statutsCommande['${r['statut']}']]),
  itemTrailing: (r) => fcfa(r['total_estime']),
  detailPath: '/vet/orders/{id}',
  detailTitle: (r) => _join([r['numero'], r['fournisseur']]),
  detail: const [
    ColumnSpec('date_commande', 'Date', fmt: Fmt.date),
    ColumnSpec('statut', 'Statut', fmt: Fmt.label, labels: _statutsCommande),
    ColumnSpec('total_estime', 'Total estimé', fmt: Fmt.money),
    ColumnSpec('notes', 'Notes'),
  ],
  sections: [
    SectionSpec('lignes', 'Lignes', (r) => _s(r['designation']),
        itemSubtitle: (r) => 'Reçu ${fmtNum(r['quantite_recue'], digits: 1)} sur ${fmtNum(r['quantite'], digits: 1)} · ${fcfa(r['prix_achat'])}', itemTrailing: (r) => '× ${fmtNum(r['quantite'], digits: 1)}'),
  ],
  actions: [
    ActionSpec('Réceptionner', '', needs: 'POST /vet/orders/{id}/receive', icon: Icons.move_to_inbox_outlined, visible: (r) => r['statut'] == 'envoyee' || r['statut'] == 'brouillon', page: (id) => ReceiveOrderPage(orderId: id)),
    const ActionSpec('Marquer envoyée', '/vet/orders/{id}/status', icon: Icons.send_outlined, body: {'action': 'envoyer'}, successMessage: 'Commande envoyée.', visible: _brouillon),
    const ActionSpec('Annuler', '/vet/orders/{id}/status', icon: Icons.block, body: {'action': 'annuler'}, confirm: 'Annuler cette commande ?', visible: _annulable, successMessage: 'Commande annulée.'),
    const ActionSpec('Supprimer', '/vet/orders/{id}/status', icon: Icons.delete_outline, body: {'action': 'supprimer'}, confirm: 'Supprimer ce brouillon ?', destructive: true, visible: _brouillon, successMessage: 'Commande supprimée.'),
  ],
  create: const CreateSpec('Commande', '/vet/orders', [
    FieldSpec('fournisseur_id', 'Fournisseur', type: FieldType.select, required: true, optionsPath: '/vet/suppliers'),
    FieldSpec('date_commande', 'Date', type: FieldType.date, initial: 'today'),
    FieldSpec('lignes', 'Produits à commander', type: FieldType.lines, required: true, lineFields: [
      FieldSpec('article_id', 'Produit du catalogue', type: FieldType.select, optionsPath: '/vet/articles', optionsQuery: {'per_page': 100, 'type': 'produit'}, fill: {'designation': 'nom', 'prix_achat': 'prix_achat'}),
      FieldSpec('designation', 'Désignation', required: true),
      FieldSpec('quantite', 'Quantité', type: FieldType.number, required: true, min: 0.001),
      FieldSpec('prix_achat', 'Prix d\'achat', type: FieldType.number, suffix: 'F', min: 0),
    ]),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ], successMessage: 'Commande enregistrée en brouillon.'),
  emptyText: 'Aucune commande.',
);

bool _brouillon(Json r) => r['statut'] == 'brouillon';
bool _annulable(Json r) => r['statut'] == 'brouillon' || r['statut'] == 'envoyee';

/// Inventaire physique (page « Inventaire » du site) : on saisit les quantités comptées ; seuls les écarts deviennent des ajustements de stock.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _counts = <int, TextEditingController>{};
  final _motif = TextEditingController();
  String _q = '';
  bool _saving = false;
  Key _k = UniqueKey();

  @override
  void dispose() {
    for (final c in _counts.values) {
      c.dispose();
    }
    _motif.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final comptes = <String, num>{};
    for (final e in _counts.entries) {
      final n = num.tryParse(e.value.text.trim().replaceAll(',', '.'));
      if (n != null) comptes['${e.key}'] = n;
    }
    if (comptes.isEmpty) return showInfo(context, 'Saisissez au moins une quantité comptée.');
    setState(() => _saving = true);
    try {
      final r = await ref.read(apiProvider).post<Map>('/vet/inventory', body: {'comptes': comptes, if (_motif.text.trim().isNotEmpty) 'motif': _motif.text.trim()});
      if (!mounted) return;
      showInfo(context, '${r['message']}');
      for (final c in _counts.values) {
        c.clear();
      }
      setState(() => _k = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventaire')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Régulariser les écarts')))),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/vet/pharmacy'),
        builder: (c, d) {
          final rows = [for (final r in (d['stock'] as List).cast<Map>()) if ('${r['nom']}'.toLowerCase().contains(_q.toLowerCase())) r];
          return ListView(padding: const EdgeInsets.all(8), children: [
            Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Rechercher un produit'), onChanged: (v) => setState(() => _q = v))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: TextField(controller: _motif, decoration: const InputDecoration(labelText: 'Motif (facultatif)', hintText: 'Inventaire de fin de mois'))),
            const Padding(padding: EdgeInsets.all(8), child: Text('Comptez le stock réel : laissez vide un produit non compté. Les différences avec le stock théorique sont enregistrées comme ajustements.')),
            for (final r in rows)
              Card(
                child: ListTile(
                  title: Text('${r['nom']}'),
                  subtitle: Text('Théorique : ${fmtNum(r['stock'], digits: 2)} ${r['unite'] ?? ''}'),
                  trailing: SizedBox(width: 100, child: TextField(controller: _counts.putIfAbsent(int.parse('${r['id']}'), TextEditingController.new), keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.end, decoration: const InputDecoration(labelText: 'Compté', isDense: true))),
                ),
              ),
            const SizedBox(height: 12),
          ]);
        },
      ),
    );
  }
}

/// Tableau financier du cabinet (même indicateurs que la page « Comptabilité » du site) : chiffres du mois, créances, stock à surveiller, factures impayées.
class VetFinancePage extends ConsumerWidget {
  const VetFinancePage({super.key});

  static const _cyan = Color(0xFF155E75);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau financier')),
      body: AsyncView<Map>(
        load: () => api.get<Map>('/vet/finance'),
        builder: (c, d) {
          Widget section(String titre, String cle) {
            final v = d[cle];
            if (v is! List || v.isEmpty) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$titre (${v.length})', style: Theme.of(c).textTheme.titleMedium),
              DataTree(v, skip: const {'id', 'article_id'}),
            ]));
          }
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
              GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.6, padding: const EdgeInsets.all(4), children: [
                Stat('Chiffre d\'affaires du mois', fcfa(d['ca_mois']), icon: Icons.trending_up, color: _cyan),
                Stat('Encaissé ce mois-ci', fcfa(d['encaisse_mois']), icon: Icons.payments_outlined, color: Colors.green),
                Stat('Dépenses du mois', fcfa(d['depenses_mois']), icon: Icons.trending_down, color: Colors.red),
                Stat('Créances', fcfa(d['creances']), icon: Icons.hourglass_bottom, color: Colors.orange),
                Stat('Devis en attente', fmtNum(d['devis_attente']), icon: Icons.request_quote_outlined, color: _cyan),
                Stat('Factures en brouillon', fmtNum(d['factures_brouillon']), icon: Icons.edit_note, color: _cyan),
                Stat('Valeur du stock', fcfa(d['valeur_stock']), icon: Icons.inventory_2_outlined, color: _cyan),
                Stat('Clients', fmtNum(d['nb_clients']), icon: Icons.people_outline, color: _cyan),
              ]),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                section('Factures impayées', 'impayees'),
                section('Stock à surveiller', 'rupture'),
                section('Péremptions proches', 'peremptions'),
              ])),
            ]);
        },
      ),
    );
  }
}

/// Produits sous leur seuil d'alerte (suggestions du serveur) : un toucher prépare la commande avec ces lignes déjà remplies.
class OrderSuggestionsPage extends ConsumerWidget {
  const OrderSuggestionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Réapprovisionnement')),
      body: AsyncView<List>(
        load: () => api.get<List>('/vet/orders/suggestions'),
        builder: (c, rows) {
          if (rows.isEmpty) return const EmptyView('Aucun produit sous son seuil d\'alerte.', icon: Icons.check_circle_outline);
          final lignes = [for (final r in rows.cast<Map>()) Map<String, dynamic>.from(r)];
          return ListView(padding: const EdgeInsets.all(8), children: [
            for (final r in lignes)
              Card(child: ListTile(leading: const Icon(Icons.warning_amber, color: Colors.orange), title: Text('${r['designation']}'), subtitle: Text('À commander : ${fmtNum(r['quantite'], digits: 1)}'), trailing: Text(fcfa(r['prix_achat'])))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Préparer la commande'),
                onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DynamicFormPage(title: 'Nouvelle commande', fields: vetOrdersModule.create!.fields, initialValues: {'lignes': lignes}, successMessage: vetOrdersModule.create!.successMessage, submit: (b) => api.post('/vet/orders', body: b)))),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Réception d'une commande : quantités reçues par ligne (avec lot et péremption), entrée en stock automatique.
class ReceiveOrderPage extends ConsumerStatefulWidget {
  const ReceiveOrderPage({super.key, required this.orderId});
  final Object? orderId;
  @override
  ConsumerState<ReceiveOrderPage> createState() => _ReceiveOrderPageState();
}

class _ReceiveOrderPageState extends ConsumerState<ReceiveOrderPage> {
  List<Map<String, dynamic>> _lignes = [];
  final _qte = <int, TextEditingController>{}, _lot = <int, TextEditingController>{};
  final _per = <int, DateTime?>{};
  bool _depense = true, _loading = true, _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._qte.values, ..._lot.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiProvider).get<Map>('/vet/orders/${widget.orderId}');
      _lignes = [for (final l in (d['lignes'] as List)) Map<String, dynamic>.from(l as Map)];
      for (final l in _lignes) {
        final id = int.parse('${l['id']}');
        final reste = (num.tryParse('${l['quantite']}') ?? 0) - (num.tryParse('${l['quantite_recue']}') ?? 0);
        _qte[id] = TextEditingController(text: reste > 0 ? '$reste' : '');
        _lot[id] = TextEditingController();
        _per[id] = null;
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final recu = <String, dynamic>{};
    for (final l in _lignes) {
      final id = int.parse('${l['id']}');
      final q = num.tryParse(_qte[id]!.text.trim().replaceAll(',', '.'));
      if (q == null || q <= 0) continue;
      recu['$id'] = {'quantite': q, 'numero_lot': _lot[id]!.text.trim(), if (_per[id] != null) 'date_peremption': isoDate(_per[id]!)};
    }
    if (recu.isEmpty) {
      showInfo(context, 'Indiquez les quantités reçues.');
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await ref.read(apiProvider).post<Map>('/vet/orders/${widget.orderId}/receive', body: {'recu': recu, 'creer_depense': _depense});
      if (!mounted) return;
      showInfo(context, '${r['message']}');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Réception')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorView(_error!)
                : ListView(padding: const EdgeInsets.all(12), children: [
                    for (final l in _lignes)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${l['designation']}', style: Theme.of(context).textTheme.titleSmall),
                            Text('Commandé ${fmtNum(l['quantite'], digits: 1)} · déjà reçu ${fmtNum(l['quantite_recue'], digits: 1)}', style: Theme.of(context).textTheme.bodySmall),
                            if (l['article_id'] == null) const Text('Ligne libre : à enregistrer en pharmacie', style: TextStyle(color: Colors.orange)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: TextField(controller: _qte[int.parse('${l['id']}')], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Reçu', isDense: true))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: _lot[int.parse('${l['id']}')], decoration: const InputDecoration(labelText: 'N° de lot', isDense: true))),
                            ]),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.event),
                              label: Text(_per[int.parse('${l['id']}')] == null ? 'Date de péremption' : fmtDate(isoDate(_per[int.parse('${l['id']}')]!))),
                              onPressed: () async {
                                final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime(2100));
                                if (d != null) setState(() => _per[int.parse('${l['id']}')] = d);
                              },
                            ),
                          ]),
                        ),
                      ),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enregistrer la dépense d\'achat'), value: _depense, onChanged: (v) => setState(() => _depense = v)),
                    FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Enregistrer la réception')),
                  ]),
      );
}

// ── Comptabilité du cabinet ──────────────────────────────────────────
class VetAccountingPage extends ConsumerStatefulWidget {
  const VetAccountingPage({super.key});
  @override
  ConsumerState<VetAccountingPage> createState() => _VetAccountingPageState();
}

class _VetAccountingPageState extends ConsumerState<VetAccountingPage> {
  DateTime _m = DateTime(DateTime.now().year, DateTime.now().month);
  Key _k = UniqueKey();

  void _shift(int d) => setState(() {
        _m = DateTime(_m.year, _m.month + d);
        _k = UniqueKey();
      });

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    const mois = ['', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return Scaffold(
      appBar: AppBar(title: const Text('Comptabilité')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Dépense'),
        onPressed: () async {
          final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => DynamicFormPage(title: 'Nouvelle dépense', successMessage: 'Dépense enregistrée.', submit: (b) => api.post('/vet/expenses', body: b), fields: const [
                        FieldSpec('description', 'Description', required: true),
                        FieldSpec('montant', 'Montant', type: FieldType.number, required: true, suffix: 'F', min: 1),
                        FieldSpec('categorie', 'Catégorie', type: FieldType.select, initial: 'autre', options: {
                          'achat_pharmacie': 'Achat pharmacie', 'loyer': 'Loyer', 'salaires': 'Salaires', 'transport': 'Transport / carburant', 'materiel': 'Matériel',
                          'electricite_eau': 'Électricité, eau, internet', 'assurance': 'Assurance', 'impots': 'Impôts et taxes', 'autre': 'Autre',
                        }),
                        FieldSpec('date_depense', 'Date', type: FieldType.date, initial: 'today'),
                        FieldSpec('fournisseur_id', 'Fournisseur', type: FieldType.select, optionsPath: '/vet/suppliers'),
                      ])));
          if (ok == true && mounted) setState(() => _k = UniqueKey());
        },
      ),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
          Text('${mois[_m.month]} ${_m.year}', style: Theme.of(context).textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _m.isBefore(DateTime(DateTime.now().year, DateTime.now().month)) ? () => _shift(1) : null),
        ]),
        Expanded(
          child: AsyncView<Map>(
            key: _k,
            load: () => api.get<Map>('/vet/accounting', query: {'du': isoDate(_m), 'au': isoDate(DateTime(_m.year, _m.month + 1, 0))}),
            builder: (c, d) {
              final dep = (d['depenses'] as List).cast<Map>(), enc = (d['encaissements'] as List).cast<Map>();
              final res = (d['resultat'] as num);
              return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
                GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.9, padding: const EdgeInsets.all(4), children: [
                  Stat('Encaissé', fcfa(d['total_enc']), icon: Icons.south_west, color: Colors.green),
                  Stat('Dépenses', fcfa(d['total_dep']), icon: Icons.north_east, color: Colors.red),
                  Stat('Résultat', fcfa(res), icon: Icons.account_balance_wallet_outlined, color: res >= 0 ? Colors.green : Colors.red),
                  Stat('Marge brute', fcfa(d['marge_brute']), icon: Icons.trending_up),
                ]),
                const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 0), child: Text('Dépenses', style: TextStyle(fontWeight: FontWeight.bold))),
                if (dep.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Aucune dépense.')),
                for (final x in dep)
                  Dismissible(
                    key: ValueKey('dep${x['id']}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      try {
                        await api.post('/vet/expenses/${x['id']}/delete');
                        return true;
                      } catch (e) {
                        if (mounted) showError(context, e);
                        return false;
                      }
                    },
                    background: Container(color: Theme.of(c).colorScheme.error, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                    child: ListTile(title: Text('${x['description']}'), subtitle: Text(_join([fmtDate(x['date_depense']), x['categorie'], x['fournisseur']])), trailing: Text(fcfa(x['montant']))),
                  ),
                const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 0), child: Text('Encaissements', style: TextStyle(fontWeight: FontWeight.bold))),
                if (enc.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Aucun encaissement.')),
                for (final p in enc) ListTile(title: Text('${p['numero']} · ${p['client']}'), subtitle: Text(_join([fmtDate(p['date_paiement']), p['mode']])), trailing: Text(fcfa(p['montant']))),
                const SizedBox(height: 80),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
