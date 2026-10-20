import 'package:flutter/material.dart';

import '../../ui/common.dart';
import 'spec.dart';

String _s(Object? v) => v == null ? '' : '$v';
String _join(Iterable<Object?> parts, [String sep = ' · ']) => parts.where((e) => e != null && '$e'.isNotEmpty).join(sep);

const _ecriture = {'admin', 'siege', 'responsable'};

const evenementsBovins = {
  'pesee': 'Pesée', 'vaccin': 'Vaccination', 'vermifuge': 'Vermifuge / déparasitage', 'soin': 'Soin / traitement', 'chaleur': 'Chaleurs observées', 'saillie': 'Saillie',
  'insemination': 'Insémination', 'diag_gestation': 'Diagnostic de gestation', 'velage': 'Vêlage', 'avortement': 'Avortement', 'tarissement': 'Tarissement', 'sevrage': 'Sevrage', 'note': 'Observation',
};

const _animalFields = [
  FieldSpec('numero', 'N° de boucle', required: true),
  FieldSpec('nom', 'Nom'),
  FieldSpec('sexe', 'Sexe', type: FieldType.select, required: true, options: {'F': 'Femelle', 'M': 'Mâle'}),
  FieldSpec('race', 'Race', type: FieldType.select, optionsPath: '/cattle/races'),
  FieldSpec('date_naissance', 'Date de naissance', type: FieldType.date),
  FieldSpec('origine', 'Origine', type: FieldType.select, initial: 'ne_ferme', options: {'ne_ferme': 'Né à la ferme', 'achete': 'Acheté'}),
  FieldSpec('poids_naissance', 'Poids à la naissance', type: FieldType.number, suffix: 'kg'),
  FieldSpec('poids_entree', 'Poids à l\'entrée', type: FieldType.number, suffix: 'kg'),
  FieldSpec('prix_achat', 'Prix d\'achat', type: FieldType.number, suffix: 'F'),
  FieldSpec('robe', 'Robe'),
  FieldSpec('notes', 'Notes', type: FieldType.multiline),
];

final cattleModule = ModuleSpec(
  id: 'cattle',
  title: 'Troupeau bovin',
  icon: Icons.pets,
  listPath: '/cattle',
  searchParam: 'q',
  filters: const [FilterSpec('statut', {'present': 'Présents', 'vendu': 'Vendus', 'mort': 'Morts', 'reforme': 'Réformés', 'tous': 'Tous'}, defaultValue: 'present')],
  itemTitle: (r) => _join([r['numero'], r['nom']], ' · '),
  itemSubtitle: (r) => _join([r['categorie'], r['race_nom'], r['age'], r['etat']]),
  itemTrailing: (r) => r['poids'] != null ? '${fmtNum(r['poids'], digits: 0)} kg' : '',
  detailPath: '/cattle/{id}',
  detailTitle: (r) => _join([r['numero'], r['nom']], ' · '),
  detail: const [
    ColumnSpec('categorie', 'Catégorie'),
    ColumnSpec('sexe', 'Sexe', fmt: Fmt.label, labels: {'F': 'Femelle', 'M': 'Mâle'}),
    ColumnSpec('race_nom', 'Race'),
    ColumnSpec('age', 'Âge'),
    ColumnSpec('site', 'Site'),
    ColumnSpec('statut', 'Statut', fmt: Fmt.label, labels: {'present': 'Présent', 'vendu': 'Vendu', 'mort': 'Mort', 'reforme': 'Réformé'}),
    ColumnSpec('poids', 'Dernier poids', fmt: Fmt.decimal),
    ColumnSpec('gmq', 'GMQ (g/j)', fmt: Fmt.number),
    ColumnSpec('etat', 'Reproduction'),
    ColumnSpec('velage_prevu', 'Vêlage prévu', fmt: Fmt.date),
    ColumnSpec('attente_lait', 'Attente lait jusqu\'au', fmt: Fmt.date),
    ColumnSpec('attente_viande', 'Attente viande jusqu\'au', fmt: Fmt.date),
    ColumnSpec('mere', 'Mère'),
    ColumnSpec('date_naissance', 'Naissance', fmt: Fmt.date),
    ColumnSpec('origine', 'Origine', fmt: Fmt.label, labels: {'ne_ferme': 'Né à la ferme', 'achete': 'Acheté'}),
    ColumnSpec('date_sortie', 'Sortie le', fmt: Fmt.date),
    ColumnSpec('prix_vente', 'Prix de vente', fmt: Fmt.money),
    ColumnSpec('motif_sortie', 'Motif de sortie'),
    ColumnSpec('notes', 'Notes'),
  ],
  sections: [
    SectionSpec('evenements', 'Historique', (r) => _s(r['type_nom']),
        itemSubtitle: (r) => _join([fmtDate(r['date_event']), r['detail'], if (r['rappel_le'] != null) 'rappel ${fmtDate(r['rappel_le'])}']), itemTrailing: (r) => r['valeur'] != null && r['type'] == 'pesee' ? '${fmtNum(r['valeur'], digits: 0)} kg' : ''),
    SectionSpec('descendants', 'Descendance', (r) => _join([r['numero'], r['nom']], ' · '), itemSubtitle: (r) => r['sexe'] == 'F' ? 'Femelle' : 'Mâle'),
  ],
  actions: [
    ActionSpec('Événement / soin', '/cattle/{id}/events', icon: Icons.medical_services_outlined, visible: (r) => r['statut'] == 'present', successMessage: 'Événement enregistré.', fields: const [
      FieldSpec('type', 'Type', type: FieldType.select, required: true, options: evenementsBovins, initial: 'pesee'),
      FieldSpec('date_event', 'Date', type: FieldType.date, initial: 'today'),
      FieldSpec('valeur', 'Poids (pour une pesée)', type: FieldType.number, suffix: 'kg', min: 0),
      FieldSpec('resultat', 'Résultat (diagnostic de gestation)', type: FieldType.select, options: {'positif': 'Positif', 'negatif': 'Négatif'}),
      FieldSpec('detail', 'Détail (produit, taureau, remarque)'),
      FieldSpec('rappel_le', 'Rappel le', type: FieldType.date),
      FieldSpec('delai_lait_j', 'Délai d\'attente lait', type: FieldType.integer, suffix: 'jours', min: 0),
      FieldSpec('delai_viande_j', 'Délai d\'attente viande', type: FieldType.integer, suffix: 'jours', min: 0),
      FieldSpec('cout', 'Coût', type: FieldType.number, suffix: 'F', min: 0),
      FieldSpec('veau_numero', 'Vêlage : n° du veau'),
      FieldSpec('veau_sexe', 'Vêlage : sexe du veau', type: FieldType.select, options: {'F': 'Femelle', 'M': 'Mâle'}),
      FieldSpec('veau_poids', 'Vêlage : poids du veau', type: FieldType.number, suffix: 'kg', min: 0),
    ]),
    ActionSpec('Sortie du troupeau', '/cattle/{id}/exit', icon: Icons.logout, visible: (r) => r['statut'] == 'present', successMessage: 'Sortie enregistrée.', fields: const [
      FieldSpec('type', 'Type de sortie', type: FieldType.select, required: true, options: {'vente': 'Vente', 'mort': 'Mort', 'reforme': 'Réforme'}),
      FieldSpec('date_sortie', 'Date', type: FieldType.date, initial: 'today'),
      FieldSpec('prix_vente', 'Prix de vente', type: FieldType.number, suffix: 'F', min: 0),
      FieldSpec('poids_sortie', 'Poids de sortie', type: FieldType.number, suffix: 'kg', min: 0),
      FieldSpec('motif', 'Motif / cause'),
    ]),
    ActionSpec('Modifier la fiche', '/cattle/{id}', icon: Icons.edit_outlined, prefill: true, successMessage: 'Fiche mise à jour.', fields: _animalFields),
    ActionSpec('Réintégrer', '/cattle/{id}/reinstate', icon: Icons.undo, confirm: 'Remettre cet animal dans le troupeau ?', visible: (r) => r['statut'] != 'present', successMessage: 'Animal réintégré.'),
  ],
  create: const CreateSpec('Animal', '/cattle', [
    FieldSpec('site_id', 'Site', type: FieldType.select, optionsPath: '/farm/sites', hint: 'Laissez vide si votre compte est rattaché à un site'),
    ..._animalFields,
  ], roles: _ecriture, successMessage: 'Animal ajouté.'),
  emptyText: 'Aucun animal.',
);
