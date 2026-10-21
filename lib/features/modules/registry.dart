import 'package:flutter/material.dart';

import '../comm/account_pages.dart';
import '../comm/chat_pages.dart';
import '../comm/support_pages.dart';
import '../vet/relation_pages.dart';
import 'cattle_extra.dart';
import 'data_view.dart';
import 'elevage_extra.dart';
import 'registry_elevage.dart';
import 'registry_gestion.dart';
import '../farm/finance_extra.dart';
import 'compare_page.dart';
import 'spec.dart';

/// Modules de la ferme décrits par configuration, par rubrique du menu « Plus ».
/// Chaque module correspond à un groupe de routes de l'API mobile (`docs/api/mobile-v1.md`).
final Map<String, List<ModuleSpec>> farmModuleGroups = {
  'Élevage': [cattleModule, fatteningModule, hatcheryModule, sensorsModule],
  'Gestion': [employeesModule, payslipsModule, suppliersModule, investmentsModule],
  'Vétérinaire': [farmVetsModule, farmVetDocsModule],
};

/// Écrans sur mesure du menu « Plus » (au-delà des listes / détails génériques).
class ExtraEntry {
  const ExtraEntry(this.group, this.title, this.icon, this.builder, {this.roles, this.plan, this.route = ''});
  final String group, title;

  /// Route GET qui doit exister sur le serveur pour afficher l'entrée (voir `core/server_support.dart`).
  final String route;
  final IconData icon;
  final Widget Function() builder;
  final Set<String>? roles;
  final String? plan;
}

final List<ExtraEntry> farmExtraEntries = [
  ExtraEntry('Vétérinaire', 'Messages des vétérinaires', Icons.forum_outlined,
      () => RelationConversationsPage(listPath: '/vets/messages', threadBase: '/vets/messages', mySens: 'ferme', title: 'Messages des vétérinaires', name: (r) => '${r['prenom'] ?? ''} ${r['nom'] ?? ''}'.trim()),
      roles: {'admin', 'siege', 'responsable'}, plan: 'veterinaire', route: '/vets/messages'),
  ExtraEntry('Communication', 'Messagerie', Icons.forum_outlined, () => const ChatRoomsPage(), plan: 'messagerie', route: '/chat/rooms'),
  ExtraEntry('Communication', 'Aide et support', Icons.support_agent, () => const SupportPage(), route: '/support/tickets'),
  ExtraEntry('Communication', 'Formation', Icons.school_outlined, () => const TrainingPage(), route: '/training'),
  ExtraEntry('Communication', 'Parrainage', Icons.card_giftcard, () => const ReferralPage(), roles: {'admin', 'siege'}, route: '/referral'),
  ExtraEntry('Gestion', 'Écritures comptables', Icons.menu_book_outlined, () => DataPage(title: 'Écritures du mois', path: '/accounting/entries'), roles: {'admin', 'siege'}, plan: 'comptabilite', route: '/accounting/entries'),
  ExtraEntry('Élevage', 'Bovins — tableau de bord', Icons.insights_outlined, () => const CattleSummaryPage(), plan: 'bovins', route: '/cattle/summary'),
  ExtraEntry('Gestion', 'ROI et performance', Icons.show_chart, () => const RoiPage(), roles: {'admin', 'siege', 'responsable'}, route: '/finance/roi'),
  ExtraEntry('Gestion', 'Contrôle des chiffres', Icons.fact_check_outlined, () => const FinanceControlPage(), roles: {'admin', 'siege'}, route: '/finance/control'),
  ExtraEntry('Élevage', 'Comparer les bandes', Icons.compare_arrows, () => const CompareBandsPage(), plan: 'bande_intelligence', route: '/lots/compare'),
  ExtraEntry('Élevage', 'Poules pondeuses', Icons.egg_alt_outlined, () => const LayingPage(), plan: 'ponte', route: '/laying'),
  ExtraEntry('Élevage', 'Ambiance (capteurs)', Icons.thermostat, () => const IotPage(), plan: 'iot', route: '/iot/sensors'),
  ExtraEntry('Élevage', 'Traite (lait)', Icons.local_drink_outlined, () => const CattleMilkPage(), plan: 'bovins', route: '/cattle/milk'),
];
