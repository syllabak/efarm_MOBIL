import 'package:flutter/material.dart';

import '../../ui/common.dart';
import 'spec.dart';

String _s(Object? v) => v == null ? '' : '$v';
String _join(Iterable<Object?> parts, [String sep = ' · ']) => parts.where((e) => e != null && '$e'.isNotEmpty).join(sep);
String money(Object? v) => '${fmtNum(v)} F';

const _gestionnaires = {'admin', 'siege', 'responsable'};
const _direction = {'admin', 'siege'};

const _employeFields = [
  FieldSpec('prenom', 'Prénom', required: true),
  FieldSpec('nom', 'Nom', required: true),
  FieldSpec('poste', 'Poste'),
  FieldSpec('telephone', 'Téléphone', type: FieldType.phone),
  FieldSpec('mode_calcul', 'Rémunération', type: FieldType.select, required: true, initial: 'fixe', options: {'fixe': 'Salaire mensuel fixe', 'horaire': 'Taux horaire'}),
  FieldSpec('salaire', 'Salaire mensuel', type: FieldType.number, suffix: 'F', min: 0, hint: 'Pour un salaire fixe'),
  FieldSpec('taux_horaire', 'Taux horaire', type: FieldType.number, suffix: 'F/h', min: 0, hint: 'Pour un employé payé à l\'heure'),
];

bool _estActif(Map<String, dynamic> r) => r['actif'] == 1 || r['actif'] == true || r['actif'] == '1';

final employeesModule = ModuleSpec(
  id: 'employees',
  plan: 'paie',
  title: 'Employés',
  icon: Icons.badge_outlined,
  listPath: '/employees',
  roles: _gestionnaires,
  filters: const [FilterSpec('actif', {'': 'Tous', '1': 'Actifs', '0': 'Inactifs'}, defaultValue: '1')],
  itemTitle: (r) => _join([r['prenom'], r['nom']], ' '),
  itemSubtitle: (r) => _join([r['poste'], r['site'], if (r['actif'] == 0 || r['actif'] == false) 'inactif']),
  itemTrailing: (r) => r['salaire'] != null ? money(r['salaire']) : (r['taux_horaire'] != null ? '${fmtNum(r['taux_horaire'])} F/h' : ''),
  detailPath: '/employees/{id}',
  exportColumns: const [('prenom', 'Prénom'), ('nom', 'Nom'), ('poste', 'Poste'), ('site', 'Site'), ('salaire', 'Salaire mensuel'), ('actif', 'Actif')],
  detailTitle: (r) => _join([r['prenom'], r['nom']], ' '),
  detail: const [
    ColumnSpec('poste', 'Poste'),
    ColumnSpec('telephone', 'Téléphone'),
    ColumnSpec('mode_calcul', 'Rémunération', fmt: Fmt.label, labels: {'fixe': 'Salaire fixe', 'horaire': 'Taux horaire'}),
    ColumnSpec('salaire', 'Salaire mensuel', fmt: Fmt.money),
    ColumnSpec('taux_horaire', 'Taux horaire', fmt: Fmt.money),
    ColumnSpec('date_embauche', 'Embauche', fmt: Fmt.date),
    ColumnSpec('actif', 'Actif', fmt: Fmt.bool),
  ],
  actions: [
    const ActionSpec('Modifier', '/employees/{id}', icon: Icons.edit_outlined, fields: _employeFields, prefill: true, successMessage: 'Employé mis à jour.'),
    ActionSpec('Désactiver', '/employees/{id}/active', icon: Icons.person_off_outlined, body: const {'actif': false}, visible: _estActif, confirm: 'Désactiver cet employé ? Il n\'apparaîtra plus dans la paie.', successMessage: 'Employé désactivé.'),
    ActionSpec('Réactiver', '/employees/{id}/active', icon: Icons.person_outline, body: const {'actif': true}, visible: (r) => !_estActif(r), successMessage: 'Employé réactivé.'),
  ],
  create: const CreateSpec('Employé', '/employees', [
    FieldSpec('site_id', 'Site', type: FieldType.select, required: true, optionsPath: '/farm/sites'),
    ..._employeFields,
    FieldSpec('date_embauche', 'Date d\'embauche', type: FieldType.date, initial: 'today'),
  ], roles: _gestionnaires, successMessage: 'Employé ajouté.'),
  emptyText: 'Aucun employé.',
);

const _statutsPaie = {'brouillon': 'Brouillon', 'valide': 'Validé', 'paye': 'Payé'};

final payslipsModule = ModuleSpec(
  id: 'payslips',
  plan: 'paie',
  title: 'Paie',
  icon: Icons.payments_outlined,
  listPath: '/payslips',
  roles: _gestionnaires,
  filters: const [FilterSpec('statut', {'': 'Tous', 'brouillon': 'Brouillons', 'valide': 'Validés', 'paye': 'Payés'})],
  itemTitle: (r) => _join([r['prenom'], r['nom']], ' '),
  itemSubtitle: (r) => '${fmtDate(r['periode_debut'])} → ${fmtDate(r['periode_fin'])} · ${_statutsPaie[_s(r['statut'])] ?? r['statut']}',
  itemTrailing: (r) => money(r['salaire_net']),
  create: const CreateSpec('Générer', '/payslips/generate', [
    FieldSpec('periode_debut', 'Début de période', type: FieldType.date, required: true),
    FieldSpec('periode_fin', 'Fin de période', type: FieldType.date, required: true),
    FieldSpec('employe_ids', 'Employés', type: FieldType.multi, required: true, optionsPath: '/employees', optionsQuery: {'actif': 1, 'per_page': 100}, optionLabel: 'nom_complet'),
  ], roles: _direction, successMessage: 'Bulletins générés.'),
  detailPath: '/payslips/{id}',
  detailTitle: (r) => _join([r['prenom'], r['nom']], ' '),
  detail: const [
    ColumnSpec('poste', 'Poste'),
    ColumnSpec('periode_debut', 'Début', fmt: Fmt.date),
    ColumnSpec('periode_fin', 'Fin', fmt: Fmt.date),
    ColumnSpec('salaire_base', 'Salaire de base', fmt: Fmt.money),
    ColumnSpec('primes', 'Primes', fmt: Fmt.money),
    ColumnSpec('deductions', 'Déductions', fmt: Fmt.money),
    ColumnSpec('salaire_net', 'Net à payer', fmt: Fmt.money),
    ColumnSpec('statut', 'Statut', fmt: Fmt.label, labels: _statutsPaie),
    ColumnSpec('date_paiement', 'Payé le', fmt: Fmt.date),
    ColumnSpec('notes', 'Notes'),
  ],
  actions: [
    ActionSpec('Ajuster primes / déductions', '/payslips/{id}', icon: Icons.tune, prefill: true, visible: (r) => r['statut'] != 'paye', successMessage: 'Bulletin mis à jour.', fields: const [
      FieldSpec('primes', 'Primes', type: FieldType.number, suffix: 'F', min: 0),
      FieldSpec('deductions', 'Déductions', type: FieldType.number, suffix: 'F', min: 0),
      FieldSpec('notes', 'Notes', type: FieldType.multiline),
    ]),
    ActionSpec('Valider', '/payslips/{id}/validate', icon: Icons.check_circle_outline, confirm: 'Valider ce bulletin ?', visible: (r) => r['statut'] == 'brouillon', successMessage: 'Bulletin validé.'),
    ActionSpec('Marquer payé', '/payslips/{id}/pay', icon: Icons.paid_outlined, confirm: 'Marquer ce bulletin comme payé ? Une dépense « Salaires » sera enregistrée.', visible: (r) => r['statut'] != 'paye', successMessage: 'Bulletin payé, dépense enregistrée.'),
  ],
);

const _fournisseurFields = [
  FieldSpec('nom', 'Nom', required: true),
  FieldSpec('contact', 'Personne à contacter'),
  FieldSpec('telephone', 'Téléphone', type: FieldType.phone),
  FieldSpec('email', 'E-mail', type: FieldType.email),
  FieldSpec('adresse', 'Adresse'),
  FieldSpec('categorie', 'Catégorie', hint: 'Aliment, vaccins, matériel…'),
  FieldSpec('notes', 'Notes', type: FieldType.multiline),
];

final suppliersModule = ModuleSpec(
  id: 'suppliers',
  plan: 'fournisseurs',
  title: 'Fournisseurs',
  icon: Icons.local_shipping_outlined,
  listPath: '/suppliers',
  searchParam: 'q',
  itemTitle: (r) => _s(r['nom']),
  itemSubtitle: (r) => _join([r['categorie'], r['telephone'], if (r['actif'] == 0 || r['actif'] == false) 'inactif']),
  itemTrailing: (r) => (num.tryParse(_s(r['total_achats'])) ?? 0) > 0 ? money(r['total_achats']) : '',
  detailPath: '/suppliers/{id}',
  exportColumns: const [('nom', 'Fournisseur'), ('telephone', 'Téléphone'), ('email', 'E-mail'), ('adresse', 'Adresse')],
  detailTitle: (r) => _s(r['nom']),
  detail: const [
    ColumnSpec('contact', 'Contact'),
    ColumnSpec('telephone', 'Téléphone'),
    ColumnSpec('email', 'E-mail'),
    ColumnSpec('adresse', 'Adresse'),
    ColumnSpec('categorie', 'Catégorie'),
    ColumnSpec('notes', 'Notes'),
    ColumnSpec('actif', 'Actif', fmt: Fmt.bool),
  ],
  sections: [
    SectionSpec('achats', 'Achats', (r) => _s(r['description']), itemSubtitle: (r) => _join([fmtDate(r['date_depense']), r['site'], r['facture_ref']]), itemTrailing: (r) => money(r['montant'])),
  ],
  actions: [
    const ActionSpec('Modifier', '/suppliers/{id}', icon: Icons.edit_outlined, fields: _fournisseurFields, prefill: true, successMessage: 'Fournisseur mis à jour.'),
    ActionSpec('Désactiver', '/suppliers/{id}/active', icon: Icons.block, body: const {'actif': false}, visible: _estActif, confirm: 'Désactiver ce fournisseur ?', successMessage: 'Fournisseur désactivé.'),
    ActionSpec('Réactiver', '/suppliers/{id}/active', icon: Icons.check_circle_outline, body: const {'actif': true}, visible: (r) => !_estActif(r), successMessage: 'Fournisseur réactivé.'),
  ],
  create: const CreateSpec('Fournisseur', '/suppliers', _fournisseurFields, roles: _gestionnaires, successMessage: 'Fournisseur ajouté.'),
  emptyText: 'Aucun fournisseur.',
);

// ── Investissements ──────────────────────────────────────────────────
final investmentsModule = ModuleSpec(
  id: 'investments',
  title: 'Investissements',
  icon: Icons.account_balance_outlined,
  listPath: '/finance/investments',
  roles: _gestionnaires,
  itemTitle: (r) => _s(r['description']),
  itemSubtitle: (r) => _join([fmtDate(r['date_investissement']), r['categorie'], r['lot_code'], r['facture_ref']]),
  itemTrailing: (r) => money(r['montant']),
  detailFromList: true,
  detailTitle: (r) => _s(r['description']),
  detail: const [
    ColumnSpec('date_investissement', 'Date', fmt: Fmt.date),
    ColumnSpec('montant', 'Montant', fmt: Fmt.money),
    ColumnSpec('categorie', 'Catégorie'),
    ColumnSpec('lot_code', 'Lot'),
    ColumnSpec('facture_ref', 'N° de facture'),
  ],
  actions: [
    const ActionSpec('Supprimer', '/finance/investments/{id}/delete', icon: Icons.delete_outline, destructive: true, confirm: 'Supprimer cet investissement ?', successMessage: 'Investissement supprimé.'),
  ],
  create: const CreateSpec('Investissement', '/finance/investments', [
    FieldSpec('site_id', 'Site', type: FieldType.select, optionsPath: '/farm/sites', hint: 'Laissez vide si votre compte est rattaché à un site'),
    FieldSpec('description', 'Description', required: true, hint: 'Équipement, bâtiment, véhicule…'),
    FieldSpec('montant', 'Montant', type: FieldType.number, required: true, suffix: 'F', min: 1),
    FieldSpec('date_investissement', 'Date', type: FieldType.date, initial: 'today'),
    FieldSpec('categorie_id', 'Catégorie', type: FieldType.select, optionsPath: '/finance/categories'),
    FieldSpec('facture_ref', 'N° de facture'),
  ], roles: _gestionnaires, successMessage: 'Investissement enregistré.'),
  emptyText: 'Aucun investissement.',
);
