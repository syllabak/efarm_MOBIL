import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session.dart';
import '../ui/common.dart';
import 'commerce/commerce_pages.dart';
import 'farm/farm_pages.dart';
import 'farm/ops_pages.dart';
import 'profile/profile_page.dart';
import 'vet/vet_pages.dart';
import 'vet/vet_repo.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).value!;
    return p.isFarm ? const _FarmShell() : const _VetShell();
  }
}

class _FarmShell extends StatefulWidget {
  const _FarmShell();
  @override
  State<_FarmShell> createState() => _FarmShellState();
}

class _FarmShellState extends State<_FarmShell> {
  int _i = 0;
  static const _titles = ['Accueil', 'Lots', 'Rapports', 'Stock', 'Plus'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[FarmHome(onGoto: (i) => setState(() => _i = i)), const LotsPage(), const RapportsPage(), const StockPage(), const FarmMore()];
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_i])),
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: _i, onDestinationSelected: (i) => setState(() => _i = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
        NavigationDestination(icon: Icon(Icons.egg_alt_outlined), selectedIcon: Icon(Icons.egg_alt), label: 'Lots'),
        NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Rapports'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Stock'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Plus'),
      ]),
    );
  }
}

/// Modules secondaires de la ferme ; la finance suit les rôles du web (admin, siège, responsable).
class FarmMore extends ConsumerWidget {
  const FarmMore({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).value!;
    Widget tile(IconData i, String t, Widget Function() page) => ListTile(leading: Icon(i), title: Text(t), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page())));
    return ListView(children: [
      tile(Icons.notifications_outlined, 'Alertes', () => const AlertsPage()),
      tile(Icons.point_of_sale, 'Ventes', () => const VentesPage()),
      tile(Icons.people_outline, 'Clients', () => const ClientsVentePage()),
      if (const {'admin', 'siege', 'responsable'}.contains(p.role)) tile(Icons.account_balance_wallet_outlined, 'Finance et dépenses', () => const FinancePage()),
      tile(Icons.location_city_outlined, 'Sites', () => const SitesPage()),
      const Divider(),
      tile(Icons.person_outline, 'Mon compte', () => Scaffold(appBar: AppBar(title: const Text('Mon compte')), body: const ProfilePage())),
    ]);
  }
}

class _VetShell extends ConsumerStatefulWidget {
  const _VetShell();
  @override
  ConsumerState<_VetShell> createState() => _VetShellState();
}

class _VetShellState extends ConsumerState<_VetShell> {
  int _i = 0;
  static const _titles = ['Accueil', 'Clients', 'Patients', 'Rendez-vous', 'Compte'];

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(vetRepoProvider);
    return repoAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(e, onRetry: () => ref.invalidate(vetRepoProvider))),
      data: (repo) {
        final p = ref.watch(sessionProvider).value!;
        final pages = <Widget>[
          VetHome(repo: repo, onGoto: (i) => setState(() => _i = i)),
          ClientsPage(repo: repo),
          PatientsPage(repo: repo),
          RdvPage(repo: repo),
          ProfilePage(extra: [
            if (p.can('stock') || p.can('clinique'))
              ListTile(leading: const Icon(Icons.medication_outlined), title: const Text('Pharmacie'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProduitsPage(repo: repo)))),
            ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Synchronisation'),
                subtitle: ListenableBuilder(listenable: repo, builder: (_, _) => Text('${repo.pendingCount} saisie(s) en attente')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SyncPage(repo: repo)))),
          ]),
        ];
        return Scaffold(
          appBar: AppBar(title: Text(_titles[_i]), actions: [
            ListenableBuilder(
                listenable: repo,
                builder: (_, _) => IconButton(
                    tooltip: 'Synchroniser',
                    icon: repo.syncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Badge(isLabelVisible: repo.pendingCount > 0, label: Text('${repo.pendingCount}'), child: const Icon(Icons.sync)),
                    onPressed: repo.syncing ? null : repo.sync)),
          ]),
          body: IndexedStack(index: _i, children: pages),
          bottomNavigationBar: NavigationBar(selectedIndex: _i, onDestinationSelected: (i) => setState(() => _i = i), destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clients'),
            NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Patients'),
            NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'RDV'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Compte'),
          ]),
        );
      },
    );
  }
}
