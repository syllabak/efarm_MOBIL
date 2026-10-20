import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';

const _causes = {
  'maladie': 'Maladie',
  'accident': 'Accident',
  'predation': 'Prédation',
  'chaleur': 'Stress thermique',
  'ecrasement': 'Écrasement',
  'autre': 'Autre',
};

/// Saisie du rapport journalier (équivalent de la page web « Rapport journalier »).
class RapportForm extends ConsumerStatefulWidget {
  const RapportForm({super.key, this.lotId});
  final int? lotId;
  @override
  ConsumerState<RapportForm> createState() => _RapportFormState();
}

class _RapportFormState extends ConsumerState<RapportForm> {
  final _form = GlobalKey<FormState>();
  List<Map<String, dynamic>> _lots = [];
  Map<String, dynamic>? _lot;
  Object? _loadError;
  bool _loading = true, _saving = false;
  DateTime _date = DateTime.now();
  final _mort = TextEditingController(text: '0');
  final _sacs = TextEditingController();
  final _vivants = TextEditingController();
  final _eau = TextEditingController();
  final _tmin = TextEditingController();
  final _tmax = TextEditingController();
  final _poids = TextEditingController();
  final _incidents = TextEditingController();
  final _obs = TextEditingController();
  final _oeufs = TextEditingController();
  final _casses = TextEditingController();
  final _declasses = TextEditingController();
  final _causes_ = <({String cause, TextEditingController qte})>[];
  bool _vivantsManuel = false;

  bool get _pondeuse => _lot?['type_production'] == 'pondeuse';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = await ref.read(apiProvider).list('/farm/lots', query: {'statut': 'actif', 'per_page': 100});
      _lots = r.items;
      _lot = _lots.where((l) => l['id'] == widget.lotId).firstOrNull ?? _lots.firstOrNull;
      _recompute();
    } catch (e) {
      _loadError = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _recompute() {
    if (_vivantsManuel || _lot == null) return;
    final m = int.tryParse(_mort.text) ?? 0;
    _vivants.text = '${((_lot!['nb_actuel'] as num).toInt() - m).clamp(0, 1 << 30)}';
  }

  @override
  void dispose() {
    for (final c in [_mort, _sacs, _vivants, _eau, _tmin, _tmax, _poids, _incidents, _obs, _oeufs, _casses, _declasses]) {
      c.dispose();
    }
    for (final c in _causes_) {
      c.qte.dispose();
    }
    super.dispose();
  }

  String? _num(String? v, {bool required = false, bool integer = false}) {
    final t = (v ?? '').trim().replaceAll(',', '.');
    if (t.isEmpty) return required ? 'Requis' : null;
    final n = integer ? int.tryParse(t) : double.tryParse(t);
    if (n == null || n < 0) return 'Valeur invalide';
    return null;
  }

  num? _n(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false) || _lot == null) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'lot_id': _lot!['id'],
        'date_rapport': isoDate(_date),
        'mortalite_jour': _n(_mort)?.toInt() ?? 0,
        'sacs_consommes': _n(_sacs) ?? 0,
        'nb_tetes_vivantes': _n(_vivants)?.toInt(),
        if (_n(_eau) != null) 'eau_litres': _n(_eau),
        if (_n(_tmin) != null) 'temperature_min': _n(_tmin),
        if (_n(_tmax) != null) 'temperature_max': _n(_tmax),
        if (_n(_poids) != null) 'poids_moyen': _n(_poids),
        if (_incidents.text.trim().isNotEmpty) 'incidents': _incidents.text.trim(),
        if (_obs.text.trim().isNotEmpty) 'observations': _obs.text.trim(),
        'causes_mortalite': [
          for (final c in _causes_)
            if ((int.tryParse(c.qte.text) ?? 0) > 0) {'cause': c.cause, 'quantite': int.parse(c.qte.text)}
        ],
        if (_pondeuse && _oeufs.text.trim().isNotEmpty) ...{
          'oeufs_ramasses': _n(_oeufs)?.toInt(),
          'oeufs_casses': _n(_casses)?.toInt() ?? 0,
          'oeufs_declasses': _n(_declasses)?.toInt() ?? 0,
        },
      };
      await ref.read(apiProvider).post('/farm/rapports', body: body);
      if (!mounted) return;
      showInfo(context, 'Rapport soumis.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, {bool required = false, bool integer = false, String? suffix, void Function(String)? onChanged}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: suffix),
          validator: (v) => _num(v, required: required, integer: integer),
          onChanged: onChanged,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport journalier')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? ErrorView(_loadError!, onRetry: _load)
              : _lots.isEmpty
                  ? const EmptyView('Aucun lot actif.')
                  : Form(
                      key: _form,
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        DropdownButtonFormField<int>(
                          initialValue: _lot!['id'] as int,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Lot'),
                          items: [for (final l in _lots) DropdownMenuItem(value: l['id'] as int, child: Text('${l['code']} · ${fmtNum(l['nb_actuel'])} têtes', overflow: TextOverflow.ellipsis))],
                          onChanged: (id) => setState(() {
                            _lot = _lots.firstWhere((l) => l['id'] == id);
                            _vivantsManuel = false;
                            _recompute();
                          }),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(4)),
                          leading: const Icon(Icons.event),
                          title: Text(fmtDate(isoDate(_date))),
                          subtitle: const Text('Date du rapport'),
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now());
                            if (d != null) setState(() => _date = d);
                          },
                        ),
                        const SizedBox(height: 16),
                        _field(_mort, 'Mortalité du jour', required: true, integer: true, suffix: 'têtes', onChanged: (_) => setState(_recompute)),
                        for (var i = 0; i < _causes_.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _causes_[i].cause,
                                  decoration: const InputDecoration(labelText: 'Cause'),
                                  items: [for (final e in _causes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                                  onChanged: (v) => _causes_[i] = (cause: v!, qte: _causes_[i].qte),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                  width: 90,
                                  child: TextFormField(controller: _causes_[i].qte, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nb'))),
                              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _causes_.removeAt(i).qte.dispose())),
                            ]),
                          ),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                                onPressed: () => setState(() => _causes_.add((cause: 'maladie', qte: TextEditingController()))),
                                icon: const Icon(Icons.add),
                                label: const Text('Détailler les causes de mortalité'))),
                        const SizedBox(height: 8),
                        _field(_vivants, 'Têtes vivantes', required: true, integer: true, onChanged: (_) => _vivantsManuel = true),
                        _field(_sacs, 'Aliment consommé', required: true, suffix: 'sacs'),
                        _field(_eau, 'Eau consommée', suffix: 'L'),
                        Row(children: [
                          Expanded(child: _field(_tmin, 'Temp. min', suffix: '°C')),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_tmax, 'Temp. max', suffix: '°C')),
                        ]),
                        _field(_poids, 'Poids moyen', suffix: 'kg'),
                        if (_pondeuse) ...[
                          Text('Production d\'œufs', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          _field(_oeufs, 'Œufs ramassés', integer: true),
                          Row(children: [
                            Expanded(child: _field(_casses, 'Cassés', integer: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _field(_declasses, 'Déclassés', integer: true)),
                          ]),
                        ],
                        TextFormField(controller: _incidents, maxLines: 2, decoration: const InputDecoration(labelText: 'Incidents')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _obs, maxLines: 3, decoration: const InputDecoration(labelText: 'Observations')),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                          label: const Text('Soumettre le rapport'),
                        ),
                        const SizedBox(height: 8),
                        Text('Un rapport soumis ne peut plus être modifié depuis l\'application.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
    );
  }
}
