import 'package:flutter/material.dart' hide Text;
import '../../ui/web_menu.dart';
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';

/// « Configuration des alertes » du site web : seuils d'avertissement et critique par type d'alerte et par site.
/// Un champ laissé vide revient à la valeur par défaut, comme sur le web.
class ThresholdsPage extends ConsumerStatefulWidget {
  const ThresholdsPage({super.key});
  @override
  ConsumerState<ThresholdsPage> createState() => _ThresholdsPageState();
}

class _ThresholdsPageState extends ConsumerState<ThresholdsPage> {
  int? _site;
  Key _k = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final p = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(webTitle('Seuils d\'alerte'))),
      body: AsyncView<List>(
        load: () => api.get<List>('/farm/sites'),
        builder: (c, sites) {
          if (sites.isEmpty) return const EmptyView('Aucun site.');
          final fixed = p?.siteId ?? (sites.length == 1 ? (sites.first as Map)['id'] as int? : null);
          final site = fixed ?? _site;
          return Column(children: [
            if (fixed == null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<int>(
                  initialValue: _site,
                  decoration: InputDecoration(labelText: tr('Site')),
                  items: [for (final s in sites) DropdownMenuItem(value: (s as Map)['id'] as int, child: Text('${s['nom']}'))],
                  onChanged: (v) => setState(() {
                    _site = v;
                    _k = UniqueKey();
                  }),
                ),
              ),
            Expanded(
              child: site == null
                  ? const EmptyView('Choisissez un site pour régler ses seuils.')
                  : AsyncView<Map>(key: _k, load: () => api.get<Map>('/alerts/thresholds', query: {'site_id': site}), builder: (c, d) => _Editor(site: site, types: (d['types'] as List).cast<Map>())),
            ),
          ]);
        },
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.site, required this.types});
  final int site;
  final List<Map> types;
  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _w = <String, TextEditingController>{}, _c = <String, TextEditingController>{};
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  String _txt(Object? v) => v == null ? '' : fmtNum(v, digits: v is int || v == (v as num).roundToDouble() ? 0 : 2).replaceAll(' ', '').replaceAll(' ', '');

  @override
  void initState() {
    super.initState();
    for (final t in widget.types) {
      _w['${t['type']}'] = TextEditingController(text: _txt(t['warning']));
      _c['${t['type']}'] = TextEditingController(text: _txt(t['critique']));
    }
  }

  @override
  void dispose() {
    for (final x in [..._w.values, ..._c.values]) {
      x.dispose();
    }
    super.dispose();
  }

  num? _num(String s) => num.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final seuils = <String, dynamic>{};
      for (final k in _w.keys) {
        final w = _w[k]!.text.trim(), c = _c[k]!.text.trim();
        seuils[k] = (w.isEmpty || c.isEmpty) ? null : {'warning': _num(w), 'critique': _num(c)};
      }
      await ref.read(apiProvider).post('/alerts/thresholds', body: {'site_id': widget.site, 'seuils': seuils});
      if (mounted) showInfo(context, 'Seuils enregistrés.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _valid(String? v) => (v == null || v.trim().isEmpty || _num(v) != null) ? null : 'Nombre attendu';

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Text('Laissez vide pour utiliser la valeur par défaut (indiquée sous chaque champ).', style: Theme.of(context).textTheme.bodySmall),
          for (final t in widget.types)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['label']}${'${t['unite']}'.isEmpty ? '' : ' (${t['unite']})'}', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _w['${t['type']}'], keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _valid, decoration: InputDecoration(labelText: tr('Avertissement'), helperText: tr('défaut ${_txt(t['defaut_warning'])}')))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _c['${t['type']}'], keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _valid, decoration: InputDecoration(labelText: tr('Critique'), helperText: tr('défaut ${_txt(t['defaut_critique'])}')))),
                  ]),
                ]),
              ),
            ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'))),
        ]),
      );
}
