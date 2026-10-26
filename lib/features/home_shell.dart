import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import '../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/server_support.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/sidebar.dart';
import '../core/i18n.dart';
import 'commerce/commerce_pages.dart';
import 'farm/farm_pages.dart';
import 'farm/dashboard.dart';
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
  static const _titles = ['🐓 EFarm360', '🐣 Élevage & Lots', '📋 Rapport journalier', '📦 Stock', '📂 Menu'];

  void _goto(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[FarmHome(onGoto: _goto), ModuleListPage(lotsSpec, embedded: true), const RapportsPage(), const StockPage(), FarmMore(onTab: _goto, tab: _i)];
    final content = Column(children: [const OfflineBanner(), Expanded(child: IndexedStack(index: _i, children: pages))]);
    // Écran large (tablette, bureau) : menu latéral permanent comme sur le site web
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        appBar: AppBar(title: Text(_titles[_i])),
        body: Row(children: [SizedBox(width: 260, child: FarmMore(onTab: _goto, tab: _i)), Expanded(child: content)]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_i])),
      drawer: Drawer(width: 280, backgroundColor: efarmDeep, child: FarmMore(onTab: (i) {
        Navigator.pop(context);
        _goto(i);
      }, tab: _i, inDrawer: true)),
      body: content,
      bottomNavigationBar: NavigationBar(selectedIndex: _i, onDestinationSelected: _goto, destinations: [
        NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: tr('Accueil')),
        NavigationDestination(icon: const Icon(Icons.egg_alt_outlined), selectedIcon: const Icon(Icons.egg_alt), label: tr('Lots')),
        NavigationDestination(icon: const Icon(Icons.assignment_outlined), selectedIcon: const Icon(Icons.assignment), label: tr('Rapports')),
        NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: tr('Stock')),
        NavigationDestination(icon: const Icon(Icons.menu), label: tr('Plus')),
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

/// Menu latéral du site web (Principal / Gestion / Administration) : mêmes libellés, mêmes emojis, même ordre.
/// Les entrées reflètent l'offre de la société, les rôles et les routes réellement présentes sur le serveur.
class FarmMore extends ConsumerWidget {
  const FarmMore({super.key, this.onTab, this.tab = -1, this.inDrawer = false});

  /// Bascule vers un onglet de la barre du bas (0 accueil, 1 lots, 2 rapports, 3 stock).
  final void Function(int)? onTab;
  final int tab;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).value;
    if (p == null) return const SizedBox.shrink();
    void open(Widget Function() page) {
      if (inDrawer) Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page()));
    }

    // (rang, entrée) : classées dans l'ordre du menu du site web
    final rows = <(int, SideItem)>[];
    void add(String title, Widget Function() page) {
      final m = _webMenu[title] ?? ('Gestion', '📄', title, 500);
      rows.add((m.$4, SideItem(m.$1, m.$2, m.$3, () => open(page))));
    }

    void tabItem(int index, String section, String emoji, String label, int rank) => rows.add((rank, SideItem(section, emoji, label, () => onTab?.call(index), active: tab == index)));

    tabItem(0, 'Principal', '📊', 'Tableau de bord', 0);
    tabItem(2, 'Principal', '📋', 'Rapport journalier', 20);
    tabItem(1, 'Principal', '🐣', 'Élevage & Lots', 30);
    tabItem(3, 'Gestion', '📦', 'Stock', 130);
    if (serverGets('/alerts')) add('Alertes', () => const AlertsPage());
    if (p.has('vente') && serverGets('/sales')) {
      add('Ventes', () => const VentesPage());
      add('Clients', () => const ClientsVentePage());
    }
    if (serverGets('/finance/summary') && const {'admin', 'siege', 'responsable'}.contains(p.role)) add('Finance et dépenses', () => const FinancePage());
    for (final m in farmModuleGroups.values.expand((l) => l)) {
      if (serverGets(m.listPath) && (m.roles == null || m.roles!.contains(p.role)) && (m.plan == null || p.has(m.plan!))) add(m.title, () => ModuleListPage(m));
    }
    for (final e in farmExtraEntries) {
      if (serverGets(e.route) && (e.roles == null || e.roles!.contains(p.role)) && (e.plan == null || p.has(e.plan!))) add(e.title, e.builder);
    }
    add('Sites', () => const SitesPage());
    add('Mon compte', () => Scaffold(appBar: AppBar(title: const Text('Mon compte')), body: const ProfilePage()));
    rows.sort((x, y) => x.$1.compareTo(y.$1));
    const order = ['Principal', 'Gestion', 'Administration'];
    final items = [for (final sec in order) ...rows.where((r) => r.$2.section == sec).map((r) => r.$2)];
    return SidebarMenu(
      title: p.companyName ?? 'EFarm360',
      subtitle: tr('Espace ferme'),
      items: items,
      userName: p.fullName.isEmpty ? p.email : p.fullName,
      onProfile: () => open(() => Scaffold(appBar: AppBar(title: const Text('Mon compte')), body: const ProfilePage())),
    );
  }
}

/// Clé = titre dans l'application → (section, emoji, libellé, rang) du menu latéral du site web.
const _webMenu = <String, (String, String, String, int)>{
  'Messagerie': ('Principal', '💬', 'Messagerie', 10),
  'Poules pondeuses': ('Principal', '🐓', 'Poules pondeuses', 40),
  'Troupeau bovin': ('Principal', '🐄', 'Bovins', 50),
  'Bovins — tableau de bord': ('Principal', '📈', 'Bovins — tableau de bord', 51),
  'Traite (lait)': ('Principal', '🥛', 'Traite (lait)', 52),
  'Embouche bovine': ('Principal', '🥩', 'Embouche bovine', 60),
  'Couvoir et incubation': ('Principal', '🥚', 'Couvoir & Incubation', 70),
  'Capteurs': ('Principal', '📡', 'Capteurs IoT', 80),
  'Ambiance (capteurs)': ('Principal', '🌡️', 'Ambiance du bâtiment', 81),
  'Comparer les bandes': ('Principal', '📊', 'Performances bande', 90),
  'Alertes': ('Principal', '🔔', 'Alertes', 100),
  'Ventes': ('Gestion', '🛒', 'Ventes commerciales', 110),
  'Clients': ('Gestion', '👥', 'Clients', 120),
  'Finance et dépenses': ('Gestion', '💰', 'Finance & ROI', 140),
  'ROI et performance': ('Gestion', '📈', 'ROI et performance', 141),
  'Contrôle des chiffres': ('Gestion', '✅', 'Contrôle des chiffres', 142),
  'Investissements': ('Gestion', '🏗️', 'Investissements', 143),
  'Fournisseurs': ('Gestion', '🚚', 'Fournisseurs', 150),
  'Employés': ('Gestion', '👷', 'Employés', 160),
  'Paie': ('Gestion', '💵', 'RH & Paie', 161),
  'Mes vétérinaires': ('Gestion', '🩺', 'Vétérinaires', 170),
  'Documents du vétérinaire': ('Gestion', '📄', 'Documents du vétérinaire', 171),
  'Messages des vétérinaires': ('Gestion', '💬', 'Messages des vétérinaires', 172),
  'Formation': ('Gestion', '🎓', 'Formation', 180),
  'Aide et support': ('Gestion', '🛟', 'Aide et support', 190),
  'Parrainage': ('Gestion', '🎁', 'Parrainage', 200),
  'Écritures comptables': ('Gestion', '📊', 'Export comptable', 210),
  'Seuils d\'alerte': ('Gestion', '⚙️', 'Seuils d\'alerte', 240),
  'Sites': ('Administration', '🏭', 'Sites & Fermes', 300),
  'Mon compte': ('Administration', '👤', 'Mon compte', 310),
};

class _VetShell extends ConsumerStatefulWidget {
  const _VetShell();
  @override
  ConsumerState<_VetShell> createState() => _VetShellState();
}

class _VetShellState extends ConsumerState<_VetShell> {
  int _i = 0;
  static const _titles = ['🩺 Accueil', '👥 Clients', '🐾 Patients', '📅 Rendez-vous', '👤 Compte'];

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(vetRepoProvider);
    return repoAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(e, onRetry: () => ref.invalidate(vetRepoProvider))),
      data: (repo) {
        final p = ref.watch(sessionProvider).value!;
        final full = serverGets('/vet/documents'); // cabinet complet : routes pas encore déployées
        // Rubriques du cabinet (les mêmes dans le menu latéral et dans l'onglet Compte)
        final cab = <(String, String, IconData, Widget Function())>[
          if (full && p.can('documents')) ('🧾', 'Devis et factures', Icons.receipt_long_outlined, () => const DocumentsPage()),
          if (full && p.can('ordonnances')) ('💊', 'Ordonnances', Icons.description_outlined, () => const OrdonnancesPage()),
          if (full && p.can('profil')) ('🏥', 'Mon cabinet', Icons.business_outlined, () => const CabinetProfilePage()),
          if (full && p.can('fermes')) ('🏭', 'Mes fermes', Icons.agriculture, () => const VetFarmsPage()),
          if (full && p.can('fermes')) ('💬', 'Messages des fermes', Icons.forum_outlined, () => RelationConversationsPage(listPath: '/vet/messages', threadBase: '/vet/messages', mySens: 'veto', title: 'Messages des fermes', name: (r) => '${r['nom']}')),
          if (full && p.can('stock')) ('🧪', 'Pharmacie (stock, lots, péremptions)', Icons.medication_outlined, () => const PharmacyPage()),
          if (full && p.can('stock') && serverCan('POST', '/vet/inventory')) ('📋', 'Inventaire', Icons.fact_check_outlined, () => const InventoryPage()),
          if (full && p.can('stock')) ('🏷️', 'Catalogue', Icons.inventory_outlined, () => ModuleListPage(vetCatalogueModule)),
          if (full && p.can('achats')) ('📦', 'Commandes fournisseurs', Icons.shopping_cart_outlined, () => ModuleListPage(vetOrdersModule)),
          if (full && p.can('achats') && serverGets('/vet/orders/suggestions')) ('🔄', 'Réapprovisionnement', Icons.shopping_cart_checkout, () => const OrderSuggestionsPage()),
          if (full && p.can('achats')) ('🚚', 'Fournisseurs', Icons.local_shipping_outlined, () => ModuleListPage(vetSuppliersModule)),
          if (full && p.can('compta') && serverGets('/vet/finance')) ('💰', 'Tableau financier', Icons.insights_outlined, () => const VetFinancePage()),
          if (full && p.can('compta')) ('📊', 'Comptabilité', Icons.account_balance_wallet_outlined, () => const VetAccountingPage()),
          if ((!full || !p.can('stock')) && p.can('clinique')) ('🧪', 'Produits', Icons.medication_outlined, () => ProduitsPage(repo: repo)),
        ];
        void open(Widget Function() page, {bool drawer = false}) {
          if (drawer) Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => page()));
        }

        final pages = <Widget>[
          VetHome(repo: repo, onGoto: (i) => setState(() => _i = i)),
          ClientsPage(repo: repo),
          PatientsPage(repo: repo),
          RdvPage(repo: repo),
          ProfilePage(extra: [
            for (final c in cab) ListTile(leading: Icon(c.$3), title: Text(c.$2), trailing: const Icon(Icons.chevron_right), onTap: () => open(c.$4)),
            ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Synchronisation'),
                subtitle: ListenableBuilder(listenable: repo, builder: (_, _) => Text('${repo.pendingCount} saisie(s) en attente')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(() => SyncPage(repo: repo))),
          ]),
        ];
        void tab(int i) {
          Navigator.pop(context);
          setState(() => _i = i);
        }

        final drawer = Drawer(
          width: 280,
          backgroundColor: efarmCyanDeep,
          child: SidebarMenu(
            vet: true,
            logo: '🩺',
            title: 'Espace Vétérinaire',
            subtitle: p.cabinetOwner ?? '',
            userName: p.fullName.isEmpty ? p.email : p.fullName,
            onProfile: () => tab(4),
            items: [
              SideItem('Principal', '📊', 'Accueil', () => tab(0), active: _i == 0),
              SideItem('Principal', '👥', 'Clients', () => tab(1), active: _i == 1),
              SideItem('Principal', '🐾', 'Patients', () => tab(2), active: _i == 2),
              SideItem('Principal', '📅', 'Rendez-vous', () => tab(3), active: _i == 3),
              for (final c in cab) SideItem('Mon cabinet', c.$1, c.$2, () => open(c.$4, drawer: true)),
              SideItem('Mon cabinet', '🔄', 'Synchronisation', () => open(() => SyncPage(repo: repo), drawer: true), badge: repo.pendingCount),
              SideItem('Compte', '👤', 'Mon profil', () => tab(4), active: _i == 4),
            ],
          ),
        );
        return Theme(data: buildTheme(Theme.of(context).brightness, vet: true), child: Scaffold(
          drawer: drawer,
          appBar: AppBar(title: Text(_titles[_i]), actions: [
            ListenableBuilder(
                listenable: repo,
                builder: (_, _) => IconButton(
                    tooltip: tr('Synchroniser'),
                    icon: repo.syncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Badge(isLabelVisible: repo.pendingCount > 0, label: Text('${repo.pendingCount}'), child: const Icon(Icons.sync)),
                    onPressed: repo.syncing ? null : repo.sync)),
          ]),
          body: IndexedStack(index: _i, children: pages),
          bottomNavigationBar: NavigationBar(selectedIndex: _i, onDestinationSelected: (i) => setState(() => _i = i), destinations: [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: tr('Accueil')),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: tr('Clients')),
            NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: tr('Patients')),
            NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: tr('RDV')),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: tr('Compte')),
          ]),
        ));
      },
    );
  }
}
