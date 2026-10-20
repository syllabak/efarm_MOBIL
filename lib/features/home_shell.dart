import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/server_support.dart';
import '../core/session.dart';
import '../ui/common.dart';
import 'commerce/commerce_pages.dart';
import 'farm/farm_pages.dart';
import 'farm/ops_pages.dart';
import 'modules/module_pages.dart';
import 'modules/registry.dart';
import 'modules/registry_elevage.dart';
import 'profile/profile_page.dart';
import 'vet/vet_docs_pages.dart';
import 'comm/account_pages.dart';
import 'vet/relation_pages.dart';
import 'vet/vet_manage.dart';
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
  static const _titles = ['Tableau de bord', 'Lots', 'Rapports', 'Stock', 'Plus'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[FarmHome(onGoto: (i) => setState(() => _i = i)), ModuleListPage(lotsSpec, embedded: true), const RapportsPage(), const StockPage(), const FarmMore()];
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_i])),
      body: Column(children: [const OfflineBanner(), Expanded(child: IndexedStack(index: _i, children: pages))]),
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

/// Bandeau affiché quand les données viennent de la copie locale (réseau coupé).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ValueListenableBuilder<DateTime?>(
        valueListenable: ref.watch(apiProvider).offlineSince,
        builder: (c, since, _) => since == null
            ? const SizedBox.shrink()
            : Material(
                color: Theme.of(c).colorScheme.tertiaryContainer,
                child: ListTile(dense: true, leading: const Icon(Icons.cloud_off), title: const Text('Hors ligne — dernières données enregistrées'), subtitle: const Text('La consultation reste possible, la saisie demande le réseau.')),
              ),
      );
}

/// Modules secondaires de la ferme ; la finance suit les rôles du web (admin, siège, responsable).
class FarmMore extends ConsumerWidget {
  const FarmMore({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).value;
    if (p == null) return const SizedBox.shrink();
    Widget tile(IconData i, String t, Widget Function() page) => ListTile(leading: Icon(i), title: Text(t), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page())));
    // (titre, entrée) : triées dans l'ordre du menu latéral du site web
    final items = <(String, Widget)>[
      if (serverGets('/alerts')) ('Alertes', tile(Icons.notifications_outlined, 'Alertes', () => const AlertsPage())),
      if (p.has('vente') && serverGets('/sales')) ('Ventes', tile(Icons.point_of_sale, 'Ventes', () => const VentesPage())),
      if (p.has('vente') && serverGets('/sales')) ('Clients', tile(Icons.people_outline, 'Clients', () => const ClientsVentePage())),
      if (serverGets('/finance/summary') && const {'admin', 'siege', 'responsable'}.contains(p.role)) ('Finance', tile(Icons.account_balance_wallet_outlined, 'Finance et dépenses', () => const FinancePage())),
      ('Sites', tile(Icons.location_city_outlined, 'Sites', () => const SitesPage())),
      for (final m in farmModuleGroups.values.expand((l) => l))
        if (serverGets(m.listPath) && (m.roles == null || m.roles!.contains(p.role)) && (m.plan == null || p.has(m.plan!))) (m.title, tile(m.icon, m.title, () => ModuleListPage(m))),
      for (final e in farmExtraEntries)
        if (serverGets(e.route) && (e.roles == null || e.roles!.contains(p.role)) && (e.plan == null || p.has(e.plan!))) (e.title, tile(e.icon, e.title, e.builder)),
    ]..sort((x, y) => _webRank(x.$1).compareTo(_webRank(y.$1)));
    return ListView(children: [
      ...items.map((e) => e.$2),
      const Divider(),
      tile(Icons.person_outline, 'Mon compte', () => Scaffold(appBar: AppBar(title: const Text('Mon compte')), body: const ProfilePage())),
    ]);
  }
}

/// Ordre du menu latéral du site web (mots-clés des titres) ; « Sites » reste en dernier.
const _webOrder = ['messag', 'rapport', 'élevage', 'ponte', 'poule', 'bovin', 'embouche', 'couvoir', 'capteur', 'iot', 'alerte', 'vente', 'client', 'stock', 'finance', 'fournisseur', 'employ', 'paie', 'vétérinaire', 'formation', 'support', 'parrain', 'compta', 'écriture', 'import', 'investiss'];

int _webRank(String title) {
  if (title == 'Sites') return 1000;
  final i = _webOrder.indexWhere(title.toLowerCase().contains);
  return i < 0 ? 999 : i;
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
        final full = serverGets('/vet/documents'); // cabinet complet : routes pas encore déployées
        final pages = <Widget>[
          VetHome(repo: repo, onGoto: (i) => setState(() => _i = i)),
          ClientsPage(repo: repo),
          PatientsPage(repo: repo),
          RdvPage(repo: repo),
          ProfilePage(extra: [
            if (full && p.can('documents')) ListTile(leading: const Icon(Icons.receipt_long_outlined), title: const Text('Devis et factures'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsPage()))),
            if (full && p.can('ordonnances')) ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Ordonnances'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdonnancesPage()))),
            if (full && p.can('profil')) ListTile(leading: const Icon(Icons.business_outlined), title: const Text('Mon cabinet'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CabinetProfilePage()))),
            if (full && p.can('fermes')) ListTile(leading: const Icon(Icons.agriculture), title: const Text('Mes fermes'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VetFarmsPage()))),
            if (full && p.can('fermes')) ListTile(leading: const Icon(Icons.forum_outlined), title: const Text('Messages des fermes'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RelationConversationsPage(listPath: '/vet/messages', threadBase: '/vet/messages', mySens: 'veto', title: 'Messages des fermes', name: (r) => '${r['nom']}')))),
            if (full && p.can('stock')) ListTile(leading: const Icon(Icons.medication_outlined), title: const Text('Pharmacie (stock, lots, péremptions)'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyPage()))),
            if (full && p.can('stock')) ListTile(leading: const Icon(Icons.inventory_outlined), title: const Text('Catalogue'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModuleListPage(vetCatalogueModule)))),
            if (full && p.can('achats')) ListTile(leading: const Icon(Icons.shopping_cart_outlined), title: const Text('Commandes fournisseurs'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModuleListPage(vetOrdersModule)))),
            if (full && p.can('achats')) ListTile(leading: const Icon(Icons.local_shipping_outlined), title: const Text('Fournisseurs'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModuleListPage(vetSuppliersModule)))),
            if (full && p.can('compta')) ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: const Text('Comptabilité'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VetAccountingPage()))),
            if ((!full || !p.can('stock')) && p.can('clinique'))
              ListTile(leading: const Icon(Icons.medication_outlined), title: const Text('Produits'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProduitsPage(repo: repo)))),
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
