import 'package:flutter/material.dart';

enum FieldType { text, multiline, number, integer, date, select, multi, bool, phone, email, password }

/// Un champ de formulaire. `optionsPath` charge les choix depuis l'API (liste d'objets `{id, nom}` par défaut).
class FieldSpec {
  const FieldSpec(this.key, this.label,
      {this.type = FieldType.text,
      this.required = false,
      this.options,
      this.optionsPath,
      this.optionsQuery,
      this.optionValue = 'id',
      this.optionLabel = 'nom',
      this.suffix,
      this.hint,
      this.initial,
      this.min,
      this.optionsFrom});
  final String key, label;
  final FieldType type;
  final bool required;
  final Map<String, String>? options;
  final String? optionsPath;
  final Map<String, dynamic>? optionsQuery;
  final String optionValue, optionLabel;
  final String? suffix, hint;
  final Object? initial;
  final num? min;

  /// Si la réponse de `optionsPath` est un objet, clé qui contient la liste des choix.
  final String? optionsFrom;
}

/// Mise en forme d'une valeur affichée.
enum Fmt { text, date, dateTime, money, number, decimal, percent, bool, label }

class ColumnSpec {
  const ColumnSpec(this.key, this.label, {this.fmt = Fmt.text, this.labels});
  final String key, label;
  final Fmt fmt;
  final Map<String, String>? labels;
}

typedef Json = Map<String, dynamic>;
typedef RowText = String Function(Json);

/// Une action sur un élément (POST) : avec ou sans formulaire, avec confirmation facultative.
class ActionSpec {
  const ActionSpec(this.label, this.path, {this.icon = Icons.bolt, this.fields = const [], this.confirm, this.visible, this.destructive = false, this.successMessage = 'Fait.', this.prefill = false, this.page});
  final String label;

  /// Chemin avec `{id}` remplacé par l'identifiant de l'élément.
  final String path;
  final IconData icon;
  final List<FieldSpec> fields;
  final String? confirm;
  final bool Function(Json)? visible;
  final bool destructive;
  final String successMessage;

  /// Pré-remplit le formulaire avec les valeurs de l'élément (clés identiques).
  final bool prefill;

  /// Écran sur mesure ouvert à la place d'un formulaire générique ; renvoie `true` pour recharger le détail.
  final Widget Function(Object? id)? page;
}

/// Une liste liée affichée dans le détail (`data[key]` est une liste d'objets).
class SectionSpec {
  const SectionSpec(this.key, this.title, this.itemTitle, {this.itemSubtitle, this.itemTrailing});
  final String key, title;
  final RowText itemTitle;
  final RowText? itemSubtitle, itemTrailing;
}

class FilterSpec {
  const FilterSpec(this.param, this.options, {this.defaultValue = ''});
  final String param;
  final Map<String, String> options; // valeur => libellé
  final String defaultValue;
}

class CreateSpec {
  const CreateSpec(this.title, this.path, this.fields, {this.roles, this.successMessage = 'Enregistré.'});
  final String title, path;
  final List<FieldSpec> fields;
  final Set<String>? roles;
  final String successMessage;
}

class ModuleSpec {
  const ModuleSpec({
    required this.id,
    required this.title,
    required this.icon,
    required this.listPath,
    required this.itemTitle,
    this.itemSubtitle,
    this.itemTrailing,
    this.detailPath,
    this.detailTitle,
    this.detail = const [],
    this.sections = const [],
    this.actions = const [],
    this.create,
    this.filters = const [],
    this.emptyText = 'Aucun élément.',
    this.roles,
    this.query = const {},
    this.searchParam,
    this.listIsPlain = false,
    this.plan,
  });
  final String id, title, listPath;
  final IconData icon;
  final RowText itemTitle;
  final RowText? itemSubtitle, itemTrailing, detailTitle;
  final String? detailPath;
  final List<ColumnSpec> detail;
  final List<SectionSpec> sections;
  final List<ActionSpec> actions;
  final CreateSpec? create;
  final List<FilterSpec> filters;
  final String emptyText;

  /// Rôles de la ferme autorisés à voir le module (null = tous).
  final Set<String>? roles;
  final Map<String, dynamic> query;
  final String? searchParam;

  /// La liste n'est pas paginée (`data` est directement un tableau).
  final bool listIsPlain;

  /// Fonctionnalité de l'offre exigée (clé de `profile.fonctions`).
  final String? plan;
}
