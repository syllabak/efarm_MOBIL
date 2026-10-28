import 'package:flutter/material.dart' hide Text;
import '../../ui/tr_text.dart';
import '../../ui/language_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/server_support.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../ui/common.dart';
import '../comm/account_pages.dart';
import '../vet/vet_repo.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, this.extra = const []});
  final List<Widget> extra;

  Future<void> _logout(BuildContext context, WidgetRef ref, {bool all = false}) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(all ? 'Déconnecter tous les appareils ?' : 'Se déconnecter ?'),
              content: const Text('Les données du cabinet enregistrées sur ce téléphone seront effacées. Les saisies non envoyées seront perdues.'),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer'))],
            ));
    if (ok != true) return;
    final isVet = ref.read(sessionProvider).value?.isVet ?? false;
    await ref.read(sessionProvider.notifier).logout(everywhere: all);
    if (isVet) await VetRepo.wipeAll();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).value!;
    final api = ref.watch(apiProvider);
    final lic = p.licence;
    return ListView(children: [
      Builder(builder: (c) {
        final name = p.fullName.isEmpty ? p.email : p.fullName;
        final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
        final role = p.isFarm ? p.role : (p.isOwnerVet ? 'Titulaire' : 'Collaborateur · ${p.raw['profil']}');
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [Theme.of(c).appBarTheme.backgroundColor ?? efarmDeep, Theme.of(c).colorScheme.primary])),
          child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: Colors.white24, child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                Text(p.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 12))),
              ]),
            ),
          ]),
        );
      }),
      const LanguageTile(),
      if (p.companyName != null) ListTile(leading: const Icon(Icons.business), title: Text(p.companyName!), subtitle: Text(p.allSites ? 'Tous les sites' : 'Site n° ${p.siteId}')),
      if (p.cabinetOwner != null) ListTile(leading: const Icon(Icons.local_hospital_outlined), title: Text('Cabinet de ${p.cabinetOwner}')),
      if (lic != null)
        ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: Text('Licence ${lic['statut']}'),
            subtitle: Text(lic['date_expiration'] == null ? 'Sans échéance' : 'Expire le ${fmtDate(lic['date_expiration'])} (${lic['jours_restants']} j)')),
      if (p.isFarm)
        serverCan('GET', '/profile/2fa')
            ? ListTile(leading: const Icon(Icons.security), title: Text('Double authentification : ${p.twoFactor ? 'activée' : 'désactivée'}'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TwoFactorPage())))
            : ListTile(leading: const Icon(Icons.security), title: Text('Double authentification : ${p.twoFactor ? 'activée' : 'désactivée'}'), subtitle: const Text('À gérer depuis le site web.')),
      if (p.isFarm && serverCan('POST', '/profile')) ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Modifier mon profil'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage()))),
      if (p.isFarm && serverCan('POST', '/profile/password')) ListTile(leading: const Icon(Icons.password), title: const Text('Changer le mot de passe'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordPage()))),
      ...extra,
      const Divider(),
      ListTile(
        leading: const Icon(Icons.devices),
        title: const Text('Appareils connectés'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Appareils connectés')),
              body: AsyncView<List>(
                load: () => api.get<List>('/devices'),
                builder: (c, rows) => ListView(children: [
                  for (final d in rows)
                    ListTile(
                      leading: Icon((d as Map)['plateforme'] == 'ios' ? Icons.phone_iphone : Icons.phone_android),
                      title: Text('${d['appareil'] ?? 'Appareil'}${d['courant'] == true ? ' (cet appareil)' : ''}'),
                      subtitle: Text('Connecté le ${fmtDateTime(d['connecte_le'])}\nDernier usage ${fmtDateTime(d['dernier_usage'])}'),
                      isThreeLine: true,
                    ),
                ]),
              ),
            ))),
      ),
      ListTile(leading: const Icon(Icons.logout), title: const Text('Se déconnecter'), onTap: () => _logout(context, ref)),
      ListTile(leading: const Icon(Icons.phonelink_erase), title: const Text('Déconnecter tous les appareils'), onTap: () => _logout(context, ref, all: true)),
    ]);
  }
}
