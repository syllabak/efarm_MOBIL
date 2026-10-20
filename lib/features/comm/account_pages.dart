import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import '../modules/data_view.dart';
import '../modules/module_pages.dart';
import '../modules/spec.dart';

// ── Formation ────────────────────────────────────────────────────────
class TrainingPage extends ConsumerWidget {
  const TrainingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Formation')),
      body: AsyncView<List>(
        load: () => api.get<List>('/training'),
        builder: (c, rows) => rows.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: EmptyView('Aucune formation disponible.', icon: Icons.school_outlined))])
            : ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                for (final f in rows.cast<Map>())
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text('${f['titre']}'),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (f['description'] != null) Text('${f['description']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: ((f['progression']['pourcentage'] as num) / 100).toDouble()),
                        Text('${f['progression']['termines']}/${f['progression']['total']} cours terminés', style: Theme.of(c).textTheme.bodySmall),
                      ]),
                      isThreeLine: true,
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => FormationDetailPage(id: f['id'] as int))),
                    ),
                  ),
              ]),
      ),
    );
  }
}

class FormationDetailPage extends ConsumerStatefulWidget {
  const FormationDetailPage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<FormationDetailPage> createState() => _FormationDetailPageState();
}

class _FormationDetailPageState extends ConsumerState<FormationDetailPage> {
  Key _k = UniqueKey();
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Formation')),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/training/${widget.id}'),
        builder: (c, f) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(8), children: [
          Padding(padding: const EdgeInsets.all(8), child: Text('${f['titre']}', style: Theme.of(c).textTheme.titleLarge)),
          for (final s in (f['sections'] as List).cast<Map>())
            ExpansionTile(
              initiallyExpanded: true,
              title: Text('${s['titre']}'),
              children: [
                for (final k in (s['cours'] as List).cast<Map>())
                  ListTile(
                    leading: Icon(k['statut'] == 'termine' ? Icons.check_circle : (k['statut'] == 'en_cours' ? Icons.play_circle_outline : Icons.radio_button_unchecked), color: k['statut'] == 'termine' ? Colors.green : null),
                    title: Text('${k['titre']}'),
                    trailing: k['duree_estimee_min'] != null ? Text('${k['duree_estimee_min']} min') : null,
                    onTap: () async {
                      await Navigator.push(c, MaterialPageRoute(builder: (_) => CoursePage(id: k['id'] as int)));
                      if (mounted) setState(() => _k = UniqueKey());
                    },
                  ),
              ],
            ),
        ]),
      ),
    );
  }
}

class CoursePage extends ConsumerStatefulWidget {
  const CoursePage({super.key, required this.id});
  final int id;
  @override
  ConsumerState<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends ConsumerState<CoursePage> {
  Key _k = UniqueKey();

  Future<void> _watch(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showInfo(context, 'Impossible d\'ouvrir la vidéo.');
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cours')),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/training/courses/${widget.id}'),
        builder: (c, d) {
          final video = Map<String, dynamic>.from(d['video'] as Map? ?? {});
          final url = video['url'] as String?;
          final done = d['statut'] == 'termine';
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
            Text('${d['formation_titre']} › ${d['section_titre']}', style: Theme.of(c).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text('${d['titre']}', style: Theme.of(c).textTheme.titleLarge),
            if (d['description'] != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${d['description']}')),
            if (url != null) FilledButton.icon(onPressed: () => _watch(url), icon: const Icon(Icons.play_arrow), label: const Text('Regarder la vidéo')) else const Text('Aucune vidéo n\'est encore associée à ce cours.'),
            const SizedBox(height: 12),
            if (done)
              const ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Cours terminé'))
            else
              OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await api.post('/training/courses/${widget.id}/done');
                      if (mounted) setState(() => _k = UniqueKey());
                    } catch (e) {
                      if (mounted) showError(context, e);
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Marquer comme terminé')),
          ]);
        },
      ),
    );
  }
}

// ── Parrainage ───────────────────────────────────────────────────────
class ReferralPage extends ConsumerStatefulWidget {
  const ReferralPage({super.key});
  @override
  ConsumerState<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends ConsumerState<ReferralPage> {
  Key _k = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Parrainage')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.send),
        label: const Text('Inviter'),
        onPressed: () async {
          final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => DynamicFormPage(title: 'Inviter des éleveurs', successMessage: 'Invitations envoyées.', submit: (b) => api.post('/referral/invite', body: b), fields: const [
                        FieldSpec('emails', 'Adresses e-mail', type: FieldType.multiline, required: true, hint: 'Séparées par des virgules ou des retours à la ligne (30 maximum)'),
                      ])));
          if (ok == true && mounted) setState(() => _k = UniqueKey());
        },
      ),
      body: AsyncView<Map>(
        key: _k,
        load: () => api.get<Map>('/referral'),
        builder: (c, d) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DataTree(d),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Compte Mobile Money pour la commission'),
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                    c,
                    MaterialPageRoute(
                        builder: (_) => DynamicFormPage(title: 'Versement de la commission', successMessage: 'Compte enregistré.', submit: (b) => api.post('/referral/payout', body: b), fields: const [
                              FieldSpec('operateur', 'Opérateur', required: true, hint: 'Wave, Orange Money…'),
                              FieldSpec('numero', 'Numéro', type: FieldType.phone, required: true),
                              FieldSpec('titulaire', 'Titulaire du compte', required: true),
                            ])));
                if (ok == true && mounted) setState(() => _k = UniqueKey());
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Mon profil (modification, mot de passe) ──────────────────────────
class ProfileEditPage extends ConsumerWidget {
  const ProfileEditPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: AsyncView<Map>(
      load: () => api.get<Map>('/profile'),
      builder: (c, u) => DynamicFormPage(
        title: 'Mon profil',
        showAppBar: false,
        successMessage: 'Profil mis à jour.',
        initialValues: Map<String, dynamic>.from(u),
        submit: (b) async {
          final r = await api.post('/profile', body: b);
          ref.invalidate(sessionProvider);
          return r;
        },
        fields: const [
          FieldSpec('prenom', 'Prénom', required: true),
          FieldSpec('nom', 'Nom', required: true),
          FieldSpec('telephone', 'Téléphone', type: FieldType.phone),
        ],
      ),
    ));
  }
}

class PasswordPage extends ConsumerWidget {
  const PasswordPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return DynamicFormPage(
      title: 'Changer le mot de passe',
      successMessage: 'Mot de passe changé. Les autres appareils sont déconnectés.',
      submit: (b) => api.post('/profile/password', body: b),
      fields: const [
        FieldSpec('actuel', 'Mot de passe actuel', type: FieldType.password, required: true),
        FieldSpec('nouveau', 'Nouveau mot de passe', type: FieldType.password, required: true, hint: '6 caractères au moins'),
        FieldSpec('confirmation', 'Confirmer le nouveau mot de passe', type: FieldType.password, required: true),
      ],
    );
  }
}
