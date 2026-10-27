import 'package:flutter/material.dart' hide Text;
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/export.dart';
import '../../core/server_support.dart';
import '../../ui/common.dart';
import '../../ui/web_menu.dart';
import 'spec.dart';

/// Valeur d'une clé, y compris imbriquée (`bilan.nb_presents`).
Object? lookup(Map<String, dynamic> row, String key) {
  Object? cur = row;
  for (final part in key.split('.')) {
    if (cur is Map) {
      cur = cur[part];
    } else {
      return null;
    }
  }
  return cur;
}

String formatValue(Object? v, ColumnSpec c) {
  if (v == null || '$v'.isEmpty) return '—';
  switch (c.fmt) {
    case Fmt.date:
      return fmtDate(v);
    case Fmt.dateTime:
      return fmtDateTime(v);
    case Fmt.money:
      return '${fmtNum(v)} F';
    case Fmt.number:
      return fmtNum(v);
    case Fmt.decimal:
      return fmtNum(v, digits: 2);
    case Fmt.percent:
      return '${fmtNum(v, digits: 1)} %';
    case Fmt.bool:
      return (v == true || '$v' == '1') ? 'Oui' : 'Non';
    case Fmt.label:
      return c.labels?['$v'] ?? '$v';
    case Fmt.text:
      return '$v';
  }
}

/// Liste d'un module : filtres, recherche, pagination, création.
class ModuleListPage extends ConsumerStatefulWidget {
  const ModuleListPage(this.spec, {super.key, this.embedded = false});
  final ModuleSpec spec;

  /// Sans barre de titre (affichée dans un onglet).
  final bool embedded;
  @override
  ConsumerState<ModuleListPage> createState() => _ModuleListPageState();
}

class _ModuleListPageState extends ConsumerState<ModuleListPage> {
  late final Map<String, String> _filters = {for (final f in widget.spec.filters) f.param: f.defaultValue};
  String _q = '';
  Key _k = UniqueKey();

  void _reload() => setState(() => _k = UniqueKey());

  /// Exporte toute la liste (filtres et recherche inclus) en CSV, page par page, puis ouvre le partage.
  Future<void> _export(Map<String, dynamic> Function(int) query) async {
    final spec = widget.spec, api = ref.read(apiProvider);
    final cols = spec.exportColumns!;
    try {
      final rows = spec.listIsPlain
          ? [for (final e in await api.get<List>(spec.listPath, query: query(1))) Map<String, dynamic>.from(e as Map)]
          : await api.listAll(spec.listPath, query: {...query(1)}..remove('page'));
      if (rows.isEmpty) {
        if (mounted) showInfo(context, 'Rien à exporter.');
        return;
      }
      await shareCsv('${spec.id}_${isoDate(DateTime.now())}.csv', [for (final c in cols) c.$2], [for (final r in rows) [for (final c in cols) r[c.$1]]]);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final api = ref.watch(apiProvider);
    final role = ref.watch(sessionProvider).value?.role ?? '';
    final create = spec.create;
    final canCreate = create != null && serverCan('POST', create.path) && (create.roles == null || create.roles!.contains(role));
    Map<String, dynamic> query(int page) => {
          ...spec.query,
          'page': page,
          for (final e in _filters.entries) if (e.value.isNotEmpty) e.key: e.value,
          if (spec.searchParam != null && _q.isNotEmpty) spec.searchParam!: _q,
        };
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(webTitle(spec.title)), actions: [if (spec.exportColumns != null) IconButton(tooltip: tr('Exporter (CSV)'), icon: const Icon(Icons.ios_share), onPressed: () => _export(query))]),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(create.title),
              onPressed: () async {
                final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DynamicFormPage(title: create.title, fields: create.fields, successMessage: create.successMessage, submit: (body) => api.post(create.path, body: body))));
                if (ok == true && mounted) _reload();
              })
          : null,
      body: Column(children: [
        for (final f in spec.filters)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              for (final o in f.options.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(o.value), selected: _filters[f.param] == o.key, onSelected: (_) {
                    _filters[f.param] = o.key;
                    _reload();
                  }),
                ),
            ]),
          ),
        if (spec.searchParam != null)
          Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search), labelText: tr('Rechercher')), onChanged: (v) {
                _q = v.trim();
                _reload();
              })),
        Expanded(
          child: PagedList(
            key: _k,
            emptyText: spec.emptyText,
            fetch: spec.listIsPlain
                ? (page) async {
                    final d = await api.get<List>(spec.listPath, query: query(page));
                    return (items: [for (final e in d) Map<String, dynamic>.from(e as Map)], meta: <String, dynamic>{'page': 1, 'pages': 1});
                  }
                : (page) => api.list(spec.listPath, query: query(page)),
            itemBuilder: (c, row) {
              Future<void> open() async {
                await Navigator.push(c, MaterialPageRoute(builder: (_) => ModuleDetailPage(spec, row['id'], row: spec.detailFromList ? row : null)));
                if (mounted) _reload();
              }

              if (spec.itemCard != null) return spec.itemCard!(c, row, open);
              return Card(
              child: ListTile(
                title: Text(spec.itemTitle(row)),
                subtitle: spec.itemSubtitle == null ? null : Text(spec.itemSubtitle!(row)),
                trailing: spec.itemTrailing == null ? null : Text(spec.itemTrailing!(row), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: spec.detailPath == null && !spec.detailFromList
                    ? null
                    : () async {
                        await Navigator.push(c, MaterialPageRoute(builder: (_) => ModuleDetailPage(spec, row['id'], row: spec.detailFromList ? row : null)));
                        if (mounted) _reload();
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

/// Détail d'un élément : champs, listes liées, actions.
class ModuleDetailPage extends ConsumerStatefulWidget {
  const ModuleDetailPage(this.spec, this.id, {super.key, this.row});
  final ModuleSpec spec;
  final Object? id;

  /// Ligne de la liste, quand le module n'a pas de route de détail (`detailFromList`).
  final Map<String, dynamic>? row;
  @override
  ConsumerState<ModuleDetailPage> createState() => _ModuleDetailPageState();
}

bool _supported(ActionSpec a) {
  final n = a.needs;
  if (n == null) return serverCan('POST', a.path);
  final i = n.indexOf(' ');
  return serverCan(n.substring(0, i), n.substring(i + 1));
}

class _ModuleDetailPageState extends ConsumerState<ModuleDetailPage> {
  Key _k = UniqueKey();

  /// Après une action : recharge la fiche, ou revient à la liste quand la fiche vient de la liste (ligne devenue périmée).
  void _done() {
    if (widget.row != null) {
      Navigator.pop(context);
    } else {
      setState(() => _k = UniqueKey());
    }
  }

  Future<void> _run(ActionSpec a, Json row) async {
    final api = ref.read(apiProvider);
    final path = a.path.replaceAll('{id}', '${widget.id}');
    if (a.page != null) {
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => a.page!(widget.id)));
      if (ok == true && mounted) _done();
      return;
    }
    if (a.fields.isNotEmpty) {
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DynamicFormPage(title: a.label, fields: a.fields, pathVars: {'id': widget.id}, initialValues: a.prefill ? row : const {}, successMessage: a.successMessage, submit: (body) => api.post(path, body: {...?a.body, ...body, if (a.idKey != null) a.idKey!: widget.id}))));
      if (ok == true && mounted) _done();
      return;
    }
    if (a.confirm != null) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(title: Text(a.label), content: Text(a.confirm!), actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                FilledButton(style: a.destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error) : null, onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer')),
              ]));
      if (yes != true) return;
    }
    try {
      await api.post(path, body: a.body);
      if (!mounted) return;
      showInfo(context, a.successMessage);
      _done();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(webTitle(spec.title))),
      body: AsyncView<Map>(
        key: _k,
        load: () async => widget.row ?? await api.get<Map>(spec.detailPath!.replaceAll('{id}', '${widget.id}')),
        builder: (c, raw) {
          final row = Map<String, dynamic>.from(raw);
          final profile = ref.watch(sessionProvider).value;
          final actions = [for (final a in spec.actions) if (_supported(a) && (a.visible == null || a.visible!(row)) && (a.plan == null || profile == null || profile.has(a.plan!))) a];
          return SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (spec.detailTitle != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(spec.detailTitle!(row), style: Theme.of(c).textTheme.titleLarge)),
            for (final col in spec.detail) KeyValue(col.label, formatValue(lookup(row, col.key), col)),
            for (final s in spec.sections) ...[
              const Divider(height: 28),
              Text(s.title, style: Theme.of(c).textTheme.titleMedium),
              if (((row[s.key] as List?) ?? const []).isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('—')),
              for (final e in ((row[s.key] as List?) ?? const []).cast<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.itemTitle(Map<String, dynamic>.from(e))),
                  subtitle: s.itemSubtitle == null ? null : Text(s.itemSubtitle!(Map<String, dynamic>.from(e))),
                  trailing: s.itemTrailing == null ? null : Text(s.itemTrailing!(Map<String, dynamic>.from(e)), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
            if (actions.isNotEmpty) ...[
              const Divider(height: 28),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in actions)
                  FilledButton.tonalIcon(
                    style: a.destructive ? FilledButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error) : null,
                    onPressed: () => _run(a, row),
                    icon: Icon(a.icon),
                    label: Text(a.label),
                  ),
              ]),
            ],
          ]));
        },
      ),
    );
  }
}

/// Formulaire piloté par des `FieldSpec` ; `submit` reçoit le corps JSON déjà typé.
class DynamicFormPage extends ConsumerStatefulWidget {
  const DynamicFormPage({super.key, required this.title, required this.fields, required this.submit, this.successMessage = 'Enregistré.', this.initialValues = const {}, this.pathVars = const {}, this.showAppBar = true});
  final bool showAppBar;
  final Map<String, dynamic> initialValues;
  final Map<String, Object?> pathVars;
  final String title, successMessage;
  final List<FieldSpec> fields;
  final Future<Object?> Function(Map<String, dynamic> body) submit;
  @override
  ConsumerState<DynamicFormPage> createState() => _DynamicFormPageState();
}

class _DynamicFormPageState extends ConsumerState<DynamicFormPage> {
  final _form = GlobalKey<FormState>();
  final _ctl = <String, TextEditingController>{};
  final _values = <String, Object?>{};
  final _remote = <String, List<Map<String, dynamic>>>{};
  final _lines = <String, List<Map<String, Object?>>>{};   // lignes : par champ, une liste de {clé: contrôleur | valeur}
  bool _loading = true, _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final init = widget.initialValues[f.key] ?? f.initial;
      if (const {FieldType.select, FieldType.pick, FieldType.multi, FieldType.bool, FieldType.date}.contains(f.type)) {
        _values[f.key] = init;
        if (f.type == FieldType.date) _values[f.key] = init == 'today' ? DateTime.now() : (init == null ? null : DateTime.tryParse('$init'));
        if (f.type == FieldType.bool) _values[f.key] = init == true || '$init' == '1';
        if (f.type == FieldType.multi) _values[f.key] = <String>{};
        if (f.type == FieldType.pick) _values[f.key] = init == null ? null : {'id': init, 'label': widget.initialValues['${f.key}_label'] ?? '#$init'};
      } else if (f.type == FieldType.lines) {
        _lines[f.key] = [];
        final given = widget.initialValues[f.key];
        if (given is List && given.isNotEmpty) {
          for (final g in given) {
            _lines[f.key]!.add(_newLine(f, Map<String, dynamic>.from(g as Map)));
          }
        } else {
          _lines[f.key]!.add(_newLine(f, const {}));
        }
      } else {
        _ctl[f.key] = TextEditingController(text: init == null ? '' : '$init');
      }
    }
    _load();
  }

  Map<String, Object?> _newLine(FieldSpec f, Map<String, dynamic> init) {
    final m = <String, Object?>{};
    for (final sf in f.lineFields!) {
      final v = init[sf.key] ?? sf.initial;
      m[sf.key] = sf.type == FieldType.select ? (v == null ? null : '$v') : TextEditingController(text: v == null ? '' : '$v');
    }
    return m;
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    for (final ls in _lines.values) {
      for (final l in ls) {
        for (final v in l.values) {
          if (v is TextEditingController) v.dispose();
        }
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      for (final f in [for (final f in widget.fields) ...[f, ...?f.lineFields]]) {
        if (f.optionsPath != null && f.type != FieldType.pick) {
          var path = f.optionsPath!;
          widget.pathVars.forEach((k, v) => path = path.replaceAll('{$k}', '$v'));
          final d = await api.get<Object>(path, query: f.optionsQuery);
          final list = d is Map ? (d[f.optionsFrom] as List? ?? const []) : d as List;
          _remote[f.key] = [for (final e in list) Map<String, dynamic>.from(e as Map)];
        }
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, String> _choices(FieldSpec f) => f.options ?? {for (final r in _remote[f.key] ?? const []) '${r[f.optionValue]}': '${r[f.optionLabel]}'};

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final body = <String, dynamic>{};
    for (final f in widget.fields) {
      switch (f.type) {
        case FieldType.pick:
          final v = _values[f.key];
          if (v is Map) body[f.key] = v['id'];
        case FieldType.select:
          final v = _values[f.key];
          if (v != null && '$v'.isNotEmpty) body[f.key] = int.tryParse('$v') != null && f.options == null ? int.parse('$v') : v;
        case FieldType.lines:
          final out = <Map<String, dynamic>>[];
          for (final l in _lines[f.key]!) {
            final row = <String, dynamic>{};
            for (final sf in f.lineFields!) {
              final v = l[sf.key];
              if (v is TextEditingController) {
                final t = v.text.trim();
                if (t.isEmpty) continue;
                row[sf.key] = (sf.type == FieldType.number || sf.type == FieldType.integer) ? (num.tryParse(t.replaceAll(',', '.')) ?? t) : t;
              } else if (v != null && '$v'.isNotEmpty) {
                row[sf.key] = int.tryParse('$v') ?? v;
              }
            }
            if (row.isNotEmpty) out.add(row);
          }
          body[f.key] = out;
        case FieldType.multi:
          final sel = (_values[f.key] as Set<String>);
          if (sel.isNotEmpty) body[f.key] = [for (final v in sel) int.tryParse(v) ?? v];
        case FieldType.bool:
          body[f.key] = _values[f.key] == true;
        case FieldType.date:
          final d = _values[f.key];
          if (d is DateTime) body[f.key] = isoDate(d);
        case FieldType.number:
          final n = num.tryParse(_ctl[f.key]!.text.trim().replaceAll(',', '.'));
          if (n != null) body[f.key] = n;
        case FieldType.integer:
          final n = int.tryParse(_ctl[f.key]!.text.trim());
          if (n != null) body[f.key] = n;
        default:
          final t = _ctl[f.key]!.text.trim();
          if (t.isNotEmpty) body[f.key] = t;
      }
    }
    setState(() => _saving = true);
    try {
      await widget.submit(body);
      if (!mounted) return;
      showInfo(context, widget.successMessage);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(FieldSpec f) {
    final req = f.required ? ' *' : '';
    switch (f.type) {
      case FieldType.select:
        final ch = _choices(f);
        return DropdownButtonFormField<String>(
          initialValue: _values[f.key] == null ? null : '${_values[f.key]}',
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('${f.label}$req')),
          items: [for (final e in ch.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
          validator: f.required ? (v) => v == null ? 'Requis' : null : null,
          onChanged: (v) => _values[f.key] = v,
        );
      case FieldType.pick:
        return FormField<Map>(
          initialValue: _values[f.key] as Map?,
          validator: f.required ? (v) => _values[f.key] == null ? 'Requis' : null : null,
          builder: (st) => InkWell(
            onTap: () async {
              final r = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context, isScrollControlled: true, builder: (_) => _PickSheet(api: ref.read(apiProvider), path: f.optionsPath!, label: f.optionLabel, title: f.label, query: f.optionsQuery));
              if (r != null) {
                _values[f.key] = {'id': r[f.optionValue], 'label': r[f.optionLabel]};
                st.didChange(_values[f.key] as Map);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(labelText: tr('${f.label}${f.required ? ' *' : ''}'), errorText: st.errorText, suffixIcon: const Icon(Icons.search)),
              child: Text(_values[f.key] == null ? 'Choisir…' : '${(_values[f.key] as Map)['label']}'),
            ),
          ),
        );
      case FieldType.lines:
        final ls = _lines[f.key]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${f.label}${f.required ? ' *' : ''}', style: Theme.of(context).textTheme.titleSmall),
          for (var i = 0; i < ls.length; i++)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  for (final sf in f.lineFields!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: sf.type == FieldType.select
                          ? DropdownButtonFormField<String>(
                              key: ValueKey('${f.key}-$i-${sf.key}-${ls[i][sf.key]}'),
                              initialValue: ls[i][sf.key] as String?,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: sf.label, isDense: true),
                              items: [for (final e in _choices(sf).entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                              onChanged: (v) => setState(() {
                                ls[i][sf.key] = v;
                                final row = (_remote[sf.key] ?? const []).where((r) => '${r[sf.optionValue]}' == v).firstOrNull;
                                if (row != null && sf.fill != null) {
                                  sf.fill!.forEach((target, from) {
                                    final c = ls[i][target];
                                    if (c is TextEditingController && row[from] != null) c.text = '${row[from]}';
                                  });
                                }
                              }),
                            )
                          : TextFormField(
                              controller: ls[i][sf.key] as TextEditingController,
                              maxLines: sf.type == FieldType.multiline ? 2 : 1,
                              keyboardType: (sf.type == FieldType.number || sf.type == FieldType.integer) ? TextInputType.numberWithOptions(decimal: sf.type == FieldType.number) : null,
                              decoration: InputDecoration(labelText: tr('${sf.label}${sf.required ? ' *' : ''}'), suffixText: sf.suffix, isDense: true),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return sf.required ? 'Requis' : null;
                                if (sf.type == FieldType.number || sf.type == FieldType.integer) {
                                  final n = double.tryParse(t.replaceAll(',', '.'));
                                  if (n == null || n < (sf.min ?? 0)) return 'Valeur invalide';
                                }
                                return null;
                              },
                            ),
                    ),
                  if (ls.length > 1) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() => ls.removeAt(i)), icon: const Icon(Icons.delete_outline), label: const Text('Retirer la ligne'))),
                ]),
              ),
            ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => ls.add(_newLine(f, const {}))), icon: const Icon(Icons.add), label: const Text('Ajouter une ligne'))),
        ]);
      case FieldType.multi:
        final ch = _choices(f);
        return FormField<Set<String>>(
          initialValue: _values[f.key] as Set<String>,
          validator: f.required ? (v) => (_values[f.key] as Set<String>).isEmpty ? 'Choisissez au moins un élément' : null : null,
          builder: (st) => InputDecorator(
            decoration: InputDecoration(labelText: tr('${f.label}${f.required ? ' *' : ''}'), errorText: st.errorText),
            child: Column(children: [
              if (ch.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aucun choix disponible.')),
              if (ch.isNotEmpty)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () {
                          final all = _values[f.key] as Set<String>;
                          all.length == ch.length ? all.clear() : all.addAll(ch.keys);
                          st.didChange(all);
                          setState(() {});
                        },
                        child: const Text('Tout / rien'))),
              for (final e in ch.entries)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.value),
                  value: (_values[f.key] as Set<String>).contains(e.key),
                  onChanged: (on) {
                    final set = _values[f.key] as Set<String>;
                    on == true ? set.add(e.key) : set.remove(e.key);
                    st.didChange(set);
                    setState(() {});
                  },
                ),
            ]),
          ),
        );
      case FieldType.bool:
        return StatefulBuilder(builder: (c, set) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(f.label), value: _values[f.key] == true, onChanged: (v) => set(() => _values[f.key] = v)));
      case FieldType.date:
        return FormField<DateTime>(
          initialValue: _values[f.key] as DateTime?,
          validator: f.required ? (v) => _values[f.key] == null ? 'Requis' : null : null,
          builder: (st) => InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: (_values[f.key] as DateTime?) ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) {
                _values[f.key] = d;
                st.didChange(d);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(labelText: tr('${f.label}$req'), errorText: st.errorText, suffixIcon: const Icon(Icons.event)),
              child: Text(_values[f.key] == null ? 'Choisir…' : fmtDate(isoDate(_values[f.key] as DateTime))),
            ),
          ),
        );
      default:
        final num = f.type == FieldType.number || f.type == FieldType.integer;
        return TextFormField(
          controller: _ctl[f.key],
          maxLines: f.type == FieldType.multiline ? 3 : 1,
          obscureText: f.type == FieldType.password,
          keyboardType: num
              ? TextInputType.numberWithOptions(decimal: f.type == FieldType.number)
              : f.type == FieldType.phone
                  ? TextInputType.phone
                  : f.type == FieldType.email
                      ? TextInputType.emailAddress
                      : null,
          decoration: InputDecoration(labelText: tr('${f.label}$req'), suffixText: f.suffix, helperText: f.hint),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return f.required ? 'Requis' : null;
            if (num) {
              final n = f.type == FieldType.integer ? int.tryParse(t) : double.tryParse(t.replaceAll(',', '.'));
              if (n == null || (f.min != null && n < f.min!)) return 'Valeur invalide';
            }
            if (f.type == FieldType.email && !t.contains('@')) return 'E-mail invalide';
            return null;
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.showAppBar ? AppBar(title: Text(widget.title)) : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorView(_error!, onRetry: _load)
                : Form(
                    key: _form,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 14), child: _field(f)),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                          label: const Text('Enregistrer'),
                        ),
                      ]),
                    ),
                  ),
      );
}


/// Choix d'un élément distant avec recherche (`?q=`) et pagination.
class _PickSheet extends StatefulWidget {
  const _PickSheet({required this.api, required this.path, required this.label, required this.title, this.query});
  final ApiClient api;
  final String path, label, title;
  final Map<String, dynamic>? query;
  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(12), child: TextField(autofocus: true, decoration: InputDecoration(labelText: tr('Rechercher — ${widget.title}'), prefixIcon: const Icon(Icons.search)), onChanged: (v) => setState(() => _q = v.trim()))),
              Expanded(
                child: PagedList(
                  key: ValueKey(_q),
                  emptyText: 'Aucun résultat.',
                  fetch: (page) => widget.api.list(widget.path, query: {...?widget.query, 'page': page, if (_q.isNotEmpty) 'q': _q}),
                  itemBuilder: (c, r) => ListTile(title: Text('${r[widget.label]}'), onTap: () => Navigator.pop(context, r)),
                ),
              ),
            ]),
          ),
        ),
      );
}
