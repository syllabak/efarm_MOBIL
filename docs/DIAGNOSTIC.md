# Diagnostic complet — EFarm360 web (`efarm360`) et application mobile (`efarm_MOBIL`)

Date : 21/10/2026. Méthode : lecture du code des deux dépôts, inventaire des 594 routes web (hors API mobile) et des 198 routes de l'API mobile,
comparaison avec les écrans de l'application, essais en local (PHP 8.3 + MariaDB) de la connexion de l'API, tests et analyse statique du Flutter.
Rien n'a été exécuté contre votre base de production.

Légende : ✅ fait · 🟡 partiel · ❌ absent · 🔒 demande d'abord une route serveur (le site web ne l'expose pas dans l'API mobile).

---

## 1. Résumé

| | Web (`efarm360`) | Mobile (`efarm_MOBIL`) |
|---|---|---|
| Taille | 95 contrôleurs, 73 services, 208 vues, ≈ 42 000 lignes PHP, 594 routes web + 198 routes API mobile | 33 fichiers Dart, ≈ 7 900 lignes, 13 fichiers de test (55 tests) |
| État | En production (OVH mutualisé, MySQL) | Compile et passe les tests ; **jamais exécuté sur un appareil contre votre serveur** |
| Plateformes | Navigateur (PWA) | Android, iOS, Windows, Web |

**Conclusion** : l'application couvre l'essentiel des écrans « métier » de la ferme et du cabinet vétérinaire, mais elle n'a pas encore été validée
de bout en bout parce que la connexion à l'API a échoué sur le serveur en ligne (trois causes côté web, voir §3). Les écarts restants avec le web
sont surtout : multilingue, exports/imports, pièces jointes, graphiques, paramètres de la société et plusieurs écrans du cabinet.

---

## 2. Diagnostic du site web (`efarm360`)

### 2.1 Problèmes trouvés qui bloquent ou fragilisent l'application mobile

| # | Problème | Effet | Correctif | État |
|---|---|---|---|---|
| W1 | **Décalage d'heure PHP / MySQL** : l'expiration des jetons est écrite avec `date()` (PHP, Africa/Dakar) mais comparée à `NOW()` (MySQL) dans `ApiMobileService::jeton()` | Connexion en **erreur 500** (`contexte(): Argument #1 must be of type array, null given`) ; reproduit en local avec MySQL décalé de +2 h | 1 ligne : comparer à `date('Y-m-d H:i:s')` (commit 674e868, branche `claude/loving-faraday-c9jj8j`) | Prêt, **à fusionner et déployer** |
| W2 | **En-tête `Authorization` non transmis à PHP** (aucune règle dans `.htaccess`) | Probable : la connexion réussit puis l'app est ramenée à l'écran de connexion (401 `non_authentifie`) | Ajouter `RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]` dans `.htaccess` | **À faire** (non vérifié sur votre serveur) |
| W3 | **Aucun en-tête CORS** | L'app lancée dans Chrome est bloquée (« Connexion impossible ») ; sans effet sur Android/iOS/Windows | Répondre aux `OPTIONS` et envoyer `Access-Control-Allow-Origin` pour `/api/mobile/` | Décision à prendre (voir §7) |
| W4 | `schema.sql` est ancien : tables `societes`, colonnes `societe_id`, `two_factor_*`, `licences`… créées ailleurs (à l'exécution) | Impossible de recréer la base de test à partir du dépôt ; risque de différence entre le code et la base en ligne | Générer un schéma de référence à jour | À faire |
| W5 | Erreurs masquées en production (« Erreur interne — Réessayez. ») et `App::run()` n'écrit pas l'exception dans le journal | Diagnostic très difficile (il a fallu un fichier de test temporaire) | Journaliser `$e` dans `storage/logs/php_errors.log` avant d'afficher la page générique | À faire |
| W6 | L'API mobile (198 routes) **n'a jamais tourné sur la base réelle** ; testée seulement avec un schéma minimal | D'autres erreurs sont probables après la connexion | Tests d'intégration sur une copie de la base | À faire |

### 2.2 Sécurité (à traiter indépendamment de l'application)

- `config/app.php` contient en clair les clés **Paytech** (`PAYTECH_API_KEY`, `PAYTECH_API_SECRET`) et `config/database.php` contient en clair l'hôte, l'utilisateur et le **mot de passe MySQL** : tout est dans l'historique GitHub. Régénérer ces secrets et les passer en variables d'environnement.
- Les captures partagées pendant les essais montraient un mot de passe de compte : à changer.
- `diag_api_login.php` (fichier de diagnostic) doit être **supprimé du serveur** après usage.

### 2.3 Ce que le web propose que l'API mobile n'expose pas (🔒)

Exports PDF/Excel/CSV, imports (modèles + fichiers), pièces jointes (messagerie, support, documents vétérinaires), clés API et webhooks, création/édition de sites et de société, seuils d'alerte,
notifications push (clés VAPID), corbeille, journal d'audit, rapport hebdomadaire et PDF, facture PDF, étiquettes, scanner de codes-barres, inventaire, documentation et formation du cabinet, migration de données.

---

## 3. Diagnostic de l'application mobile (`efarm_MOBIL`)

### 3.1 Qualité technique

- ✅ 55 tests (client HTTP, jetons, modules, vétérinaire hors ligne, menus, contrat OpenAPI), `flutter analyze` sans erreur ni avertissement.
- ✅ Architecture : cadre générique de modules (`ModuleSpec`) + écrans sur mesure ; jetons en stockage sécurisé ; copie locale chiffrée du cabinet ; lecture hors ligne de la ferme.
- ✅ Détection automatique des fonctions du serveur par `/openapi.json` (un module n'apparaît que si la route existe).
- 🟡 Compatibilité : Flutter 3.44 / Dart 3.12 ; web via SQLite WebAssembly.
- ❌ **Aucun essai sur appareil ni contre le serveur réel** : tous les écrans sont validés par tests avec un faux serveur uniquement.
- ❌ Pas d'icône ni de nom d'application personnalisés, pas de signature de publication (keystore à créer), pas de notifications push.
- ❌ Un seul langage : français (le web propose fr, en, pt, es, ar — fichiers `database/lang/*.json`).
- 🟡 Accessibilité : non auditée (tailles de texte, contraste, lecteur d'écran).

### 3.2 Écart fonctionnel — ferme

| Page web | Mobile | Note |
|---|---|---|
| Tableau de bord global / par site | 🟡 | 4 indicateurs ; manquent mortalité du jour, alertes de stock, graphique mortalité 30 jours, alertes récentes, finances du mois, tableau par site |
| Rapport journalier | ✅ | Hebdomadaire et PDF ❌🔒 |
| Élevage / lots, fiche d'un lot | ✅ | Performance, bande, prévisions ✅ |
| Comparer les bandes, bande | ✅ | Dépenses et rapport d'une bande ❌ |
| Ponte, couvoir, embouche, IoT | ✅ | Exports embouche ❌🔒 |
| Bovins (troupeau, fiche, lait, pesée, événements, sorties) | ✅ | Reproduction, alimentation, carnet de santé, rapport, import/export ❌ |
| Ventes, clients, encaissements, annulation | ✅ | Modifier une vente, archives, facture PDF ❌🔒 |
| Stock, alertes de stock, mouvements | ✅ | Exports ❌🔒 |
| Finance : dépenses, investissements | ✅ | Règles, contrôle, ROI ❌ |
| Fournisseurs, employés, paie | ✅ | Activer/désactiver ✅ |
| Comptabilité | 🟡 | Écritures ✅, export ❌🔒 |
| Alertes | ✅ | Seuils et historique ❌🔒 |
| Messagerie, support, formation, parrainage | ✅ | Pièces jointes ❌🔒, guides de formation ❌ |
| Sites | 🟡 | Liste ✅ ; création/édition ❌🔒 |
| Profil | 🟡 | Édition + mot de passe ✅ ; double authentification ❌ |
| Import, corbeille, audit, paramètres, clés API, webhooks, société | ❌🔒 | |
| Prévisions | ✅ | |

### 3.3 Écart fonctionnel — cabinet vétérinaire

| Page web | Mobile | Note |
|---|---|---|
| Tableau de bord du cabinet | ✅ | Indicateurs, rendez-vous du jour, rappels, dernières consultations |
| Clients, patients, rendez-vous, consultations, soins | ✅ | **Modifier/supprimer un client ❌** (route existe) |
| Devis, factures, ordonnances (création, modification, statuts) | ✅ | |
| Catalogue, fournisseurs | ✅ | Modifier/supprimer ✅ |
| Pharmacie (stock, lots, péremptions, mouvements) | ✅ | Étiquettes, scanner ❌🔒 |
| Commandes fournisseurs | ✅ | Suggestions de réapprovisionnement ❌ |
| Comptabilité, dépenses | 🟡 | Supprimer une dépense ou un paiement ❌ (route existe) |
| Vente au comptoir | ✅ | |
| Fermes suivies, documents sanitaires, messagerie ferme | ✅ | Répondre à une demande de ferme ❌ (route existe) |
| Hors ligne | ✅ | Synchronisation avec file d'attente |
| Inventaire, étiquettes, scanner, données (import/export), migration | ❌🔒 | |
| Documentation, formation, parrainage du cabinet | ❌🔒 | |
| Équipe du cabinet | exclu | Gestion = partie administration |

### 3.4 Écart de design

| Élément | Web | Mobile | Action |
|---|---|---|---|
| Couleurs | vert profond `#14532D`, vert `#15803D`, cyan pour le cabinet | ✅ repris | Appliquer le cyan aussi aux écrans du cabinet (barre, boutons) |
| Navigation | menu latéral | barre du bas (5 onglets) + menu « Plus » dans l'ordre du web | Adapter |
| Cartes / indicateurs | cartes blanches arrondies, filet coloré à gauche, icône et valeur | ✅ | |
| Titres de rubriques | emoji (📊 🐣 💰 🩺) | 🟡 seulement l'accueil du cabinet | Généraliser |
| Graphiques | courbes et histogrammes (Chart.js) | ❌ | Ajouter une bibliothèque de graphiques |
| Tableaux | tableaux à colonnes triables | listes en cartes | Choix mobile assumé |
| Langues | 5 | 1 | Internationalisation à faire |
| Mode sombre | non | oui (automatique) | |
| Formulaires | longues pages | formulaires générés par champ | À revoir page par page |

---

## 4. Feuille de route proposée

**P0 — rendre l'application utilisable (dépend du serveur)**
1. Fusionner et déployer W1 ; ajouter la règle `Authorization` (W2) ; journaliser les exceptions (W5).
2. Premier test complet sur Windows ou Android : connexion, tableau de bord, lots, stock, rapports, puis cabinet.
3. Corriger ce que ce test révèle (erreurs SQL probables, W6).

**P1 — compléter sans toucher au site (routes déjà présentes)**
- Vétérinaire : modifier/supprimer client, supprimer dépense/paiement, répondre à une demande de ferme, suggestions de commandes.
- Ferme : finance (règles, contrôle, ROI) quand les routes existent, double authentification, FAQ du support, messages directs du chat.
- Design : emoji et couleur du cabinet partout, tableau de bord enrichi avec graphiques.

**P2 — nécessite d'ajouter des routes à l'API mobile du site**
- Exports et partage de fichiers (PDF/Excel), pièces jointes, imports, seuils d'alerte, création de sites, paramètres, scanner de codes-barres (caméra), étiquettes, inventaire, documentation et formation du cabinet.

**P3 — transversal**
- Internationalisation (fr, en, pt, es, ar avec écriture de droite à gauche), notifications push, icône et nom de l'application, signature de publication, audit d'accessibilité, tests sur appareils.

## 5. Décisions attendues de votre part

1. **Autoriser ou non** les modifications du site `efarm360` : W1 est déjà préparé ; W2, W3, W5 et les routes P2 ne peuvent être faits que là.
2. Confirmer la **priorité** : valider d'abord le fonctionnement sur appareil (P0), ou enrichir encore l'application (P1/P2).
3. **Langues** à prendre en charge en premier sur mobile.
4. Fournir le **logo** et le nom définitif de l'application.
