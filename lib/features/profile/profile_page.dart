import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
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
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(p.fullName.isEmpty ? p.email : p.fullName),
        subtitle: Text('${p.email}\n${p.isFarm ? p.role : (p.isOwnerVet ? 'Titulaire' : 'Collaborateur · ${p.raw['profil']}')}'),
        isThreeLine: true,
      ),
      if (p.companyName != null) ListTile(leading: const Icon(Icons.business), title: Text(p.companyName!), subtitle: Text(p.allSites ? 'Tous les sites' : 'Site n° ${p.siteId}')),
      if (p.cabinetOwner != null) ListTile(leading: const Icon(Icons.local_hospital_outlined), title: Text('Cabinet de ${p.cabinetOwner}')),
      if (lic != null)
        ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: Text('Licence ${lic['statut']}'),
            subtitle: Text(lic['date_expiration'] == null ? 'Sans échéance' : 'Expire le ${fmtDate(lic['date_expiration'])} (${lic['jours_restants']} j)')),
      if (p.isFarm) ListTile(leading: const Icon(Icons.security), title: Text('Double authentification : ${p.twoFactor ? 'activée' : 'désactivée'}'), subtitle: const Text('À gérer depuis le site web.')),
      if (p.isFarm) ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Modifier mon profil'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage()))),
      if (p.isFarm) ListTile(leading: const Icon(Icons.password), title: const Text('Changer le mot de passe'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordPage()))),
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
