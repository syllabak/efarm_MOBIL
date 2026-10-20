import 'registry_gestion.dart';
import 'spec.dart';

/// Modules de la ferme décrits par configuration, par rubrique du menu « Plus ».
/// Chaque module correspond à un groupe de routes de l'API mobile (`docs/api/mobile-v1.md`).
final Map<String, List<ModuleSpec>> farmModuleGroups = {
  'Gestion': [employeesModule, payslipsModule, suppliersModule],
};
