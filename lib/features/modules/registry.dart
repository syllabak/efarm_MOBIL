import 'package:flutter/material.dart';

import 'cattle_extra.dart';
import 'registry_elevage.dart';
import 'registry_gestion.dart';
import 'spec.dart';

/// Modules de la ferme décrits par configuration, par rubrique du menu « Plus ».
/// Chaque module correspond à un groupe de routes de l'API mobile (`docs/api/mobile-v1.md`).
final Map<String, List<ModuleSpec>> farmModuleGroups = {
  'Élevage': [cattleModule],
  'Gestion': [employeesModule, payslipsModule, suppliersModule],
};

/// Écrans sur mesure du menu « Plus » (au-delà des listes / détails génériques).
class ExtraEntry {
  const ExtraEntry(this.group, this.title, this.icon, this.builder, {this.roles});
  final String group, title;
  final IconData icon;
  final Widget Function() builder;
  final Set<String>? roles;
}

final List<ExtraEntry> farmExtraEntries = [
  ExtraEntry('Élevage', 'Bovins — tableau de bord', Icons.insights_outlined, () => const CattleSummaryPage()),
  ExtraEntry('Élevage', 'Traite (lait)', Icons.local_drink_outlined, () => const CattleMilkPage()),
];
