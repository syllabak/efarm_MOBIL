import 'package:flutter/material.dart' hide Text;
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:intl/intl.dart';

import '../../ui/common.dart';
import 'vet_repo.dart';

const especes = {
  'bovin': 'Bovin', 'ovin': 'Ovin', 'caprin': 'Caprin', 'porcin': 'Porcin', 'volaille': 'Volaille',
  'equin': 'Équin / âne', 'chien': 'Chien', 'chat': 'Chat', 'autre': 'Autre',
};
const sexes = {'m': 'Mâle', 'f': 'Femelle', 'inconnu': 'Non précisé'};
const typesSoin = {'vaccination': 'Vaccination', 'deparasitage': 'Déparasitage', 'traitement': 'Traitement', 'autre': 'Autre soin'};
const statutsRdv = {'prevu': 'Prévu', 'confirme': 'Confirmé', 'fait': 'Honoré', 'annule': 'Annulé'};

String nowStamp() => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

/// Sélection d'un client dans la copie locale, avec recherche.
Future<Map<String, dynamic>?> pickClient(BuildContext context, VetRepo repo) => showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Picker(title: 'Client', items: repo.clients, label: (c) => '${c['nom']}', sub: (c) => '${c['telephone'] ?? c['contact'] ?? ''}'),
    );

Future<Map<String, dynamic>?> pickPatient(BuildContext context, List<Map<String, dynamic>> patients) => showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Picker(title: 'Patient', items: patients, label: (c) => '${c['nom']}', sub: (c) => especes['${c['espece']}'] ?? ''),
    );

class _Picker extends StatefulWidget {
  const _Picker({required this.title, required this.items, required this.label, required this.sub});
  final String title;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) label, sub;
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final list = [for (final i in widget.items) if (widget.label(i).toLowerCase().contains(_q.toLowerCase())) i];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(autofocus: true, decoration: InputDecoration(labelText: tr('Rechercher — ${widget.title}'), prefixIcon: const Icon(Icons.search)), onChanged: (v) => setState(() => _q = v))),
            Expanded(
              child: list.isEmpty
                  ? const EmptyView('Aucun résultat.')
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => ListTile(title: Text(widget.label(list[i])), subtitle: Text(widget.sub(list[i])), onTap: () => Navigator.pop(context, list[i]))),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Base commune des formulaires de saisie vétérinaire.
abstract class _FormState<T extends StatefulWidget> extends State<T> {
  final form = GlobalKey<FormState>();
  bool saving = false;

  String get title;
  List<Widget> fields(BuildContext context);
  Future<void> submit();

  Future<void> _save() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      await submit();
      if (!mounted) return;
      showInfo(context, 'Enregistré. Envoi dès que le réseau est disponible.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            for (final f in fields(context)) Padding(padding: const EdgeInsets.only(bottom: 12), child: f),
            FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
          ]),
        ),
      );
}

String? _req(String? v) => (v ?? '').trim().isEmpty ? 'Requis' : null;
String? _nb(String? v) {
  final t = (v ?? '').trim().replaceAll(',', '.');
  return t.isEmpty || double.tryParse(t) != null ? null : 'Nombre invalide';
}

String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
num? _num(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));

Future<DateTime?> _pickDate(BuildContext c, DateTime? initial, {DateTime? first, DateTime? last}) =>
    showDatePicker(context: c, initialDate: initial ?? DateTime.now(), firstDate: first ?? DateTime(2000), lastDate: last ?? DateTime(2100));

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onPick, this.onClear});
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: value != null && onClear != null ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear) : const Icon(Icons.event)),
        child: InkWell(onTap: onPick, child: Text(value == null ? 'Choisir…' : DateFormat('dd/MM/yyyy').format(value!))),
      );
}

// ── Client ───────────────────────────────────────────────────────────
class ClientForm extends StatefulWidget {
  const ClientForm({super.key, required this.repo});
  final VetRepo repo;
  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends _FormState<ClientForm> {
  final nom = TextEditingController(), contact = TextEditingController(), tel = TextEditingController(), email = TextEditingController(), adresse = TextEditingController(), notes = TextEditingController();
  @override
  String get title => 'Nouveau client';
  @override
  List<Widget> fields(BuildContext context) => [
        TextFormField(controller: nom, decoration: InputDecoration(labelText: tr('Nom / exploitation *')), validator: _req, textCapitalization: TextCapitalization.words),
        TextFormField(controller: contact, decoration: InputDecoration(labelText: tr('Personne à contacter'))),
        TextFormField(controller: tel, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('Téléphone'))),
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('E-mail')), validator: (v) => (v ?? '').isEmpty || v!.contains('@') ? null : 'E-mail invalide'),
        TextFormField(controller: adresse, decoration: InputDecoration(labelText: tr('Adresse'))),
        TextFormField(controller: notes, maxLines: 3, decoration: InputDecoration(labelText: tr('Notes'))),
      ];
  @override
  Future<void> submit() => widget.repo.enqueue('client.creer', {
        'nom': nom.text.trim(), 'contact': _text(contact), 'telephone': _text(tel), 'email': _text(email), 'adresse': _text(adresse), 'notes': _text(notes),
      }..removeWhere((k, v) => v == null));
}

// ── Patient ──────────────────────────────────────────────────────────
class PatientForm extends StatefulWidget {
  const PatientForm({super.key, required this.repo, this.client});
  final VetRepo repo;
  final Map<String, dynamic>? client;
  @override
  State<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends _FormState<PatientForm> {
  Map<String, dynamic>? client;
  final nom = TextEditingController(), race = TextEditingController(), ident = TextEditingController(), poids = TextEditingController(), notes = TextEditingController(), effectif = TextEditingController(text: '1');
  String espece = 'bovin', sexe = 'inconnu', type = 'individuel';
  DateTime? naissance;
  @override
  void initState() {
    super.initState();
    client = widget.client;
  }

  @override
  String get title => 'Nouveau patient';
  @override
  List<Widget> fields(BuildContext context) => [
        InputDecorator(
          decoration: InputDecoration(labelText: tr('Propriétaire *')),
          child: InkWell(
            onTap: () async {
              final c = await pickClient(context, widget.repo);
              if (c != null) setState(() => client = c);
            },
            child: Text(client == null ? 'Choisir un client…' : '${client!['nom']}'),
          ),
        ),
        SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'individuel', label: Text('Animal')), ButtonSegment(value: 'groupe', label: Text('Troupeau / bande'))],
            selected: {type},
            onSelectionChanged: (s) => setState(() => type = s.first)),
        TextFormField(controller: nom, decoration: InputDecoration(labelText: type == 'groupe' ? 'Nom du groupe *' : 'Nom *'), validator: _req),
        if (type == 'groupe') TextFormField(controller: effectif, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Effectif'))),
        DropdownButtonFormField<String>(initialValue: espece, decoration: InputDecoration(labelText: tr('Espèce')), items: [for (final e in especes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => espece = v!),
        TextFormField(controller: race, decoration: InputDecoration(labelText: tr('Race'))),
        DropdownButtonFormField<String>(initialValue: sexe, decoration: InputDecoration(labelText: tr('Sexe')), items: [for (final e in sexes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => sexe = v!),
        _DateField(label: tr('Date de naissance'), value: naissance, onPick: () async {
          final d = await _pickDate(context, naissance, last: DateTime.now());
          if (d != null) setState(() => naissance = d);
        }, onClear: () => setState(() => naissance = null)),
        TextFormField(controller: ident, decoration: InputDecoration(labelText: tr('Identification (boucle, puce…)'))),
        TextFormField(controller: poids, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Poids'), suffixText: 'kg'), validator: _nb),
        TextFormField(controller: notes, maxLines: 3, decoration: InputDecoration(labelText: tr('Notes'))),
      ];
  @override
  Future<void> submit() async {
    if (client == null) throw StateError('Choisissez le propriétaire.');
    await widget.repo.enqueue('patient.creer', {
      ...idOrRef('client', client!['id']),
      'nom': nom.text.trim(), 'type': type, if (type == 'groupe') 'effectif': int.tryParse(effectif.text) ?? 1,
      'espece': espece, 'sexe': sexe, 'race': _text(race), 'identification': _text(ident), 'poids_kg': _num(poids), 'notes': _text(notes),
      if (naissance != null) 'date_naissance': isoDate(naissance!),
    }..removeWhere((k, v) => v == null));
  }
}

// ── Consultation ─────────────────────────────────────────────────────
class ConsultationForm extends StatefulWidget {
  const ConsultationForm({super.key, required this.repo, required this.patient});
  final VetRepo repo;
  final Map<String, dynamic> patient;
  @override
  State<ConsultationForm> createState() => _ConsultationFormState();
}

class _ConsultationFormState extends _FormState<ConsultationForm> {
  final motif = TextEditingController(), anamnese = TextEditingController(), examen = TextEditingController(), temp = TextEditingController(), poids = TextEditingController(),
      diag = TextEditingController(), trait = TextEditingController(), obs = TextEditingController();
  DateTime? prochaine;
  final moment = DateTime.now();
  @override
  String get title => 'Consultation — ${widget.patient['nom']}';
  @override
  List<Widget> fields(BuildContext context) => [
        TextFormField(controller: motif, decoration: InputDecoration(labelText: tr('Motif *')), validator: _req),
        TextFormField(controller: anamnese, maxLines: 3, decoration: InputDecoration(labelText: tr('Anamnèse'))),
        TextFormField(controller: examen, maxLines: 3, decoration: InputDecoration(labelText: tr('Examen clinique'))),
        Row(children: [
          Expanded(child: TextFormField(controller: temp, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Température'), suffixText: '°C'), validator: _nb)),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: poids, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Poids'), suffixText: 'kg'), validator: _nb)),
        ]),
        TextFormField(controller: diag, maxLines: 2, decoration: InputDecoration(labelText: tr('Diagnostic'))),
        TextFormField(controller: trait, maxLines: 3, decoration: InputDecoration(labelText: tr('Traitement'))),
        TextFormField(controller: obs, maxLines: 2, decoration: InputDecoration(labelText: tr('Observations'))),
        _DateField(label: tr('Prochaine visite'), value: prochaine, onPick: () async {
          final d = await _pickDate(context, prochaine, first: DateTime.now());
          if (d != null) setState(() => prochaine = d);
        }, onClear: () => setState(() => prochaine = null)),
      ];
  @override
  Future<void> submit() => widget.repo.enqueue('consultation.creer', {
        ...idOrRef('patient', widget.patient['id']),
        // Heure de la consultation = celle de la saisie sur l'appareil, pas celle de l'envoi
        'date_consultation': DateFormat('yyyy-MM-dd HH:mm:ss').format(moment),
        'motif': motif.text.trim(), 'anamnese': _text(anamnese), 'examen': _text(examen), 'temperature': _num(temp), 'poids_kg': _num(poids),
        'diagnostic': _text(diag), 'traitement': _text(trait), 'observations': _text(obs), if (prochaine != null) 'prochaine_visite': isoDate(prochaine!),
      }..removeWhere((k, v) => v == null));
}

// ── Soin / vaccin ────────────────────────────────────────────────────
class SoinForm extends StatefulWidget {
  const SoinForm({super.key, required this.repo, required this.patient});
  final VetRepo repo;
  final Map<String, dynamic> patient;
  @override
  State<SoinForm> createState() => _SoinFormState();
}

class _SoinFormState extends _FormState<SoinForm> {
  final libelle = TextEditingController(), lot = TextEditingController(), notes = TextEditingController();
  String type = 'vaccination';
  DateTime date = DateTime.now();
  DateTime? rappel;
  @override
  String get title => 'Soin — ${widget.patient['nom']}';
  @override
  List<Widget> fields(BuildContext context) => [
        DropdownButtonFormField<String>(initialValue: type, decoration: InputDecoration(labelText: tr('Type')), items: [for (final e in typesSoin.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => type = v!),
        TextFormField(controller: libelle, decoration: InputDecoration(labelText: tr('Libellé * (produit, acte)')), validator: _req),
        TextFormField(controller: lot, decoration: InputDecoration(labelText: tr('N° de lot'))),
        _DateField(label: tr('Date de l\'acte'), value: date, onPick: () async {
          final d = await _pickDate(context, date, last: DateTime.now());
          if (d != null) setState(() => date = d);
        }),
        _DateField(label: tr('Rappel le'), value: rappel, onPick: () async {
          final d = await _pickDate(context, rappel ?? date.add(const Duration(days: 30)), first: date);
          if (d != null) setState(() => rappel = d);
        }, onClear: () => setState(() => rappel = null)),
        TextFormField(controller: notes, maxLines: 2, decoration: InputDecoration(labelText: tr('Notes'))),
      ];
  @override
  Future<void> submit() => widget.repo.enqueue('soin.creer', {
        ...idOrRef('patient', widget.patient['id']),
        'type': type, 'libelle': libelle.text.trim(), 'numero_lot': _text(lot), 'date_acte': isoDate(date), 'notes': _text(notes), if (rappel != null) 'rappel_le': isoDate(rappel!),
      }..removeWhere((k, v) => v == null));
}

// ── Rendez-vous ──────────────────────────────────────────────────────
class RdvForm extends StatefulWidget {
  const RdvForm({super.key, required this.repo, this.client, this.patient});
  final VetRepo repo;
  final Map<String, dynamic>? client, patient;
  @override
  State<RdvForm> createState() => _RdvFormState();
}

class _RdvFormState extends _FormState<RdvForm> {
  Map<String, dynamic>? client, patient;
  final motif = TextEditingController(), notes = TextEditingController(), duree = TextEditingController(text: '30');
  DateTime day = DateTime.now();
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
  @override
  void initState() {
    super.initState();
    client = widget.client ?? (widget.patient != null ? widget.repo.client(widget.patient!['client_id']) : null);
    patient = widget.patient;
  }

  @override
  String get title => 'Nouveau rendez-vous';
  @override
  List<Widget> fields(BuildContext context) => [
        InputDecorator(
          decoration: InputDecoration(labelText: tr('Client *')),
          child: InkWell(
            onTap: () async {
              final c = await pickClient(context, widget.repo);
              if (c != null) {
                setState(() {
                  client = c;
                  if (patient != null && patient!['client_id'] != c['id']) patient = null;
                });
              }
            },
            child: Text(client == null ? 'Choisir un client…' : '${client!['nom']}'),
          ),
        ),
        InputDecorator(
          decoration: InputDecoration(labelText: tr('Patient (facultatif)'), suffixIcon: patient != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => patient = null)) : null),
          child: InkWell(
            onTap: client == null
                ? null
                : () async {
                    final p = await pickPatient(context, [for (final x in widget.repo.patients) if (x['client_id'] == client!['id']) x]);
                    if (p != null) setState(() => patient = p);
                  },
            child: Text(patient == null ? 'Choisir…' : '${patient!['nom']}'),
          ),
        ),
        _DateField(label: tr('Jour'), value: day, onPick: () async {
          final d = await _pickDate(context, day, first: DateTime.now().subtract(const Duration(days: 1)));
          if (d != null) setState(() => day = d);
        }),
        InputDecorator(
          decoration: InputDecoration(labelText: tr('Heure'), suffixIcon: Icon(Icons.schedule)),
          child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: time);
                if (t != null) setState(() => time = t);
              },
              child: Text(time.format(context))),
        ),
        TextFormField(controller: duree, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Durée'), suffixText: 'min')),
        TextFormField(controller: motif, decoration: InputDecoration(labelText: tr('Motif'))),
        TextFormField(controller: notes, maxLines: 2, decoration: InputDecoration(labelText: tr('Notes'))),
      ];
  @override
  Future<void> submit() async {
    if (client == null) throw StateError('Choisissez le client.');
    final debut = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    await widget.repo.enqueue('rdv.creer', {
      ...idOrRef('client', client!['id']),
      if (patient != null) ...idOrRef('patient', patient!['id']),
      'debut': DateFormat('yyyy-MM-dd HH:mm:ss').format(debut),
      'duree_min': int.tryParse(duree.text) ?? 30,
      'motif': _text(motif), 'notes': _text(notes),
    }..removeWhere((k, v) => v == null));
  }
}
