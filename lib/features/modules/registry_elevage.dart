import 'package:flutter/material.dart';

import '../../ui/common.dart';
import 'elevage_extra.dart';
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
  plan: 'bovins',
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

// ── Embouche ─────────────────────────────────────────────────────────
const _embFields = [
  FieldSpec('nom', 'Nom du lot', required: true),
  FieldSpec('date_debut', 'Début', type: FieldType.date, initial: 'today'),
  FieldSpec('duree_jours', 'Durée du cycle', type: FieldType.integer, suffix: 'jours', initial: 90, min: 15),
  FieldSpec('poids_cible', 'Poids de vente visé', type: FieldType.number, required: true, suffix: 'kg', min: 50),
  FieldSpec('gmq_cible', 'Gain visé', type: FieldType.integer, suffix: 'g/jour', initial: 800, min: 100),
  FieldSpec('prix_kg_vif', 'Prix du kg vif', type: FieldType.number, suffix: 'F', min: 0),
  FieldSpec('notes', 'Notes', type: FieldType.multiline),
];

final fatteningModule = ModuleSpec(
  id: 'fattening',
  plan: 'embouche',
  title: 'Embouche bovine',
  icon: Icons.fitness_center,
  listPath: '/fattening',
  listIsPlain: true,
  itemTitle: (r) => _join([r['code'], r['nom']]),
  itemSubtitle: (r) => _join([r['site_nom'], r['statut'] == 'termine' ? 'terminé' : 'en cours', '${r['bilan']?['nb_presents'] ?? 0} animaux']),
  itemTrailing: (r) => '${r['bilan']?['avancement'] ?? 0} %',
  detailPath: '/fattening/{id}',
  detailTitle: (r) => _join([r['code'], r['nom']]),
  detail: const [
    ColumnSpec('site_nom', 'Site'),
    ColumnSpec('statut', 'Statut', fmt: Fmt.label, labels: {'en_cours': 'En cours', 'termine': 'Terminé'}),
    ColumnSpec('date_debut', 'Début', fmt: Fmt.date),
    ColumnSpec('duree_jours', 'Durée du cycle (j)', fmt: Fmt.number),
    ColumnSpec('bilan.jour', 'Jour du cycle', fmt: Fmt.number),
    ColumnSpec('bilan.avancement', 'Avancement', fmt: Fmt.percent),
    ColumnSpec('poids_cible', 'Poids visé (kg)', fmt: Fmt.number),
    ColumnSpec('bilan.poids_moy', 'Poids moyen (kg)', fmt: Fmt.decimal),
    ColumnSpec('bilan.gmq_moy', 'GMQ moyen (g/j)', fmt: Fmt.number),
    ColumnSpec('gmq_cible', 'GMQ visé (g/j)', fmt: Fmt.number),
    ColumnSpec('bilan.prets', 'Animaux prêts', fmt: Fmt.number),
    ColumnSpec('bilan.date_prevue', 'Vente prévue', fmt: Fmt.date),
    ColumnSpec('bilan.cout_alim_soins', 'Alimentation + soins', fmt: Fmt.money),
    ColumnSpec('bilan.cout_kg_gagne', 'Coût du kg gagné', fmt: Fmt.money),
    ColumnSpec('bilan.marge_prevue', 'Marge prévue', fmt: Fmt.money),
    ColumnSpec('notes', 'Notes'),
  ],
  sections: [
    SectionSpec('animaux', 'Animaux du lot', (r) => _join([r['numero'], r['nom']]),
        itemSubtitle: (r) => _join([if (r['gmq'] != null) 'GMQ ${r['gmq']} g/j', if (r['reste'] != null) 'reste ${fmtNum(r['reste'], digits: 0)} kg', if (r['date_prevue'] != null) 'vente ${fmtDate(r['date_prevue'])}']),
        itemTrailing: (r) => r['poids'] != null ? '${fmtNum(r['poids'], digits: 0)} kg' : ''),
  ],
  actions: [
    ActionSpec('Pesée du lot', '/fattening/{id}/weighing', icon: Icons.monitor_weight_outlined, visible: (r) => r['statut'] == 'en_cours', page: (id) => FatteningWeighingPage(lotId: id)),
    ActionSpec('Ajouter des animaux', '/fattening/{id}/animals', icon: Icons.playlist_add, visible: (r) => r['statut'] == 'en_cours', successMessage: 'Animaux ajoutés.', fields: const [
      FieldSpec('animaux', 'Animaux disponibles', type: FieldType.multi, required: true, optionsPath: '/fattening/{id}', optionsFrom: 'candidats', optionLabel: 'numero'),
    ]),
    ActionSpec('Modifier le lot', '/fattening/{id}', icon: Icons.edit_outlined, prefill: true, successMessage: 'Lot mis à jour.', fields: _embFields),
    ActionSpec('Clôturer', '/fattening/{id}/close', icon: Icons.flag_outlined, confirm: 'Clôturer ce lot d\'embouche ?', visible: (r) => r['statut'] == 'en_cours', successMessage: 'Lot clôturé.'),
    ActionSpec('Rouvrir', '/fattening/{id}/reopen', icon: Icons.replay, confirm: 'Rouvrir ce lot ?', visible: (r) => r['statut'] == 'termine', successMessage: 'Lot rouvert.'),
  ],
  create: const CreateSpec('Lot', '/fattening', [
    FieldSpec('site_id', 'Site', type: FieldType.select, optionsPath: '/farm/sites', hint: 'Laissez vide si votre compte est rattaché à un site'),
    ..._embFields,
  ], roles: _ecriture, successMessage: 'Lot créé.'),
  emptyText: 'Aucun lot d\'embouche.',
);

// ── Couvoir ──────────────────────────────────────────────────────────
final hatcheryModule = ModuleSpec(
  id: 'hatchery',
  plan: 'couvoir',
  title: 'Couvoir et incubation',
  icon: Icons.egg_outlined,
  listPath: '/hatchery',
  listIsPlain: true,
  itemTitle: (r) => _join([r['code'], r['race']]),
  itemSubtitle: (r) => _join([r['site_nom'], '${fmtNum(r['nb_oeufs_mis'])} œufs', r['statut'] == 'en_incubation' ? 'jour ${r['indicateurs']?['jour_actuel']}/${r['indicateurs']?['jours_total']}' : r['statut']]),
  itemTrailing: (r) => r['indicateurs']?['taux_eclosion'] != null ? '${r['indicateurs']['taux_eclosion']} %' : '',
  detailPath: '/hatchery/{id}',
  detailTitle: (r) => _join([r['code'], r['race']]),
  detail: const [
    ColumnSpec('site_nom', 'Site'),
    ColumnSpec('couvoir_nom', 'Couvoir'),
    ColumnSpec('statut', 'Statut', fmt: Fmt.label, labels: {'en_incubation': 'En incubation', 'eclos': 'Éclos', 'converti': 'Converti en lot'}),
    ColumnSpec('source_oeufs', 'Source des œufs'),
    ColumnSpec('nb_oeufs_mis', 'Œufs mis', fmt: Fmt.number),
    ColumnSpec('date_mise_incubation', 'Mise en incubation', fmt: Fmt.date),
    ColumnSpec('date_eclosion_prevue', 'Éclosion prévue', fmt: Fmt.date),
    ColumnSpec('indicateurs.jours_restants', 'Jours restants', fmt: Fmt.number),
    ColumnSpec('indicateurs.taux_fertilite', 'Fertilité', fmt: Fmt.percent),
    ColumnSpec('nb_poussins_eclos', 'Poussins éclos', fmt: Fmt.number),
    ColumnSpec('date_eclosion_reelle', 'Éclosion réelle', fmt: Fmt.date),
    ColumnSpec('indicateurs.taux_eclosion', 'Taux d\'éclosion', fmt: Fmt.percent),
    ColumnSpec('notes', 'Notes'),
  ],
  sections: [
    SectionSpec('mirages', 'Contrôles de mirage', (r) => 'Jour ${r['jour_incubation']}',
        itemSubtitle: (r) => _join([fmtDate(r['date_controle']), 'fertiles ${r['nb_oeufs_fertiles'] ?? '—'}', 'clairs ${r['nb_oeufs_clairs'] ?? '—'}', 'morts ${r['nb_oeufs_morts'] ?? '—'}'])),
  ],
  actions: [
    ActionSpec('Contrôle de mirage', '/hatchery/{id}/candling', icon: Icons.light_mode_outlined, visible: (r) => r['statut'] == 'en_incubation', successMessage: 'Contrôle enregistré.', fields: const [
      FieldSpec('jour_incubation', 'Jour d\'incubation', type: FieldType.integer, required: true, min: 0),
      FieldSpec('date_controle', 'Date', type: FieldType.date, initial: 'today'),
      FieldSpec('nb_oeufs_fertiles', 'Œufs fertiles', type: FieldType.integer, min: 0),
      FieldSpec('nb_oeufs_clairs', 'Œufs clairs', type: FieldType.integer, min: 0),
      FieldSpec('nb_oeufs_morts', 'Œufs morts', type: FieldType.integer, min: 0),
      FieldSpec('notes', 'Notes', type: FieldType.multiline),
    ]),
    ActionSpec('Enregistrer l\'éclosion', '/hatchery/{id}/hatch', icon: Icons.child_friendly_outlined, visible: (r) => r['statut'] == 'en_incubation', successMessage: 'Éclosion enregistrée.', fields: const [
      FieldSpec('nb_poussins_eclos', 'Poussins éclos', type: FieldType.integer, required: true, min: 1),
      FieldSpec('date_eclosion_reelle', 'Date d\'éclosion', type: FieldType.date, initial: 'today'),
    ]),
    ActionSpec('Convertir en lot d\'élevage', '/hatchery/{id}/convert', icon: Icons.swap_horiz, visible: (r) => r['statut'] == 'eclos', successMessage: 'Lot d\'élevage créé.', fields: const [
      FieldSpec('code_lot', 'Code du nouveau lot', required: true),
    ]),
  ],
  create: const CreateSpec('Incubation', '/hatchery', [
    FieldSpec('site_id', 'Site', type: FieldType.select, optionsPath: '/farm/sites', hint: 'Laissez vide si votre compte est rattaché à un site'),
    FieldSpec('couvoir_id', 'Couvoir', type: FieldType.select, optionsPath: '/hatchery/equipment'),
    FieldSpec('race', 'Race / souche'),
    FieldSpec('source_oeufs', 'Source des œufs'),
    FieldSpec('nb_oeufs_mis', 'Nombre d\'œufs mis', type: FieldType.integer, required: true, min: 1),
    FieldSpec('date_mise_incubation', 'Mise en incubation', type: FieldType.date, initial: 'today'),
    FieldSpec('duree_incubation_jours', 'Durée', type: FieldType.integer, suffix: 'jours', initial: 21, min: 1),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ], roles: {'admin', 'responsable'}, successMessage: 'Incubation créée.'),
  emptyText: 'Aucune incubation.',
);

// ── Capteurs ─────────────────────────────────────────────────────────
final sensorsModule = ModuleSpec(
  id: 'sensors',
  plan: 'iot',
  title: 'Capteurs',
  icon: Icons.sensors,
  listPath: '/iot/sensors',
  listIsPlain: true,
  roles: null,
  itemTitle: (r) => _s(r['nom']),
  itemSubtitle: (r) => _join([r['type'], r['actif'] == 0 || r['actif'] == '0' ? 'inactif' : 'actif', if (r['derniere_lecture_at'] != null) 'dernière lecture ${fmtDateTime(r['derniere_lecture_at'])}']),
  create: const CreateSpec('Capteur', '/iot/sensors', [
    FieldSpec('site_id', 'Site', type: FieldType.select, required: true, optionsPath: '/farm/sites'),
    FieldSpec('nom', 'Nom du capteur', required: true),
    FieldSpec('type', 'Type', type: FieldType.select, initial: 'multi', options: {'multi': 'Multi-mesures', 'temperature_hygrometrie': 'Température et humidité', 'co2_nh3': 'CO₂ et NH₃'}),
  ], roles: {'admin'}, successMessage: 'Capteur créé : sa clé API est visible dans le site web.'),
  emptyText: 'Aucun capteur.',
);
