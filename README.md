# EFarm360 — application mobile (Flutter)

Application Android / iOS d'[EFarm360](https://github.com/syllabak/efarm360). Elle parle uniquement à l'**API mobile** du site web
(`/api/mobile/v1`, 198 routes : voir `docs/api/mobile-v1.md` et `openapi.json` dans le dépôt `efarm360`) : aucune base de données ni règle métier dupliquée,
les droits, l'offre de la société et la licence sont ceux du serveur. Le menu masque les modules que l'offre n'inclut pas (`profile.fonctions`).

Serveur par défaut : `https://efarm360.danov.sn` (modifiable dans « Options avancées » de l'écran de connexion).
Branche principale : `main`.

## Lancer

```bash
flutter pub get
flutter run
flutter analyze && flutter test      # 69 tests
```

## Deux profils, un seul écran de connexion

- **Exploitation (fermier)** — onglets Accueil, Lots, Rapports, Stock, Plus.
- **Vétérinaire** (titulaire ou collaborateur, droits par rubrique) — onglets Accueil, Clients, Patients, RDV, Compte. La clinique fonctionne **hors ligne**.

Connexion : e-mail ou téléphone + mot de passe, code à usage unique (e-mail / SMS), double authentification, choix de société si plusieurs.
Jetons dans le stockage sécurisé, rafraîchissement automatique avec rotation.

## Design et langues (comme le site web)

- **Thème** du site : fond `#f8f9fa`, cartes blanches arrondies, boutons vert 600, barre vert 900 ; **cyan** pour tout l'espace vétérinaire.
- **Menu latéral** identique au web (dégradé vert, sections Principal / Gestion / Administration, emojis, ordre) : tiroir sur téléphone, permanent à partir de 900 px ; onglet « Plus » = même menu.
- **Tableau de bord** de la ferme : quatre indicateurs à emojis, performance par site (siège), cartes de lots, mortalité, alertes, finances.
- **Langues** : français, anglais, portugais, espagnol, arabe (droite à gauche) avec les dictionnaires du site (`assets/lang/{code}.json`, copiés de `efarm360/database/lang`) complétés par `assets/lang/mobile_{code}.json`. Choix sur l'écran de connexion et dans « Mon compte ». Un texte absent du dictionnaire reste en français.

## Ce qui est couvert

| Domaine | Contenu |
|---|---|
| **Ferme — saisie quotidienne** | rapport journalier (mortalité par cause, aliment, eau, températures, poids, œufs), alertes, stock avec entrées / sorties / seuils |
| **Ferme — lots** | liste, performance, création, modification, clôture, suppression, tableau de bande, prévisions d'aliment et de mortalité |
| **Ferme — commerce** | ventes (création, encaissement, annulation), clients, finance, dépenses, investissements, écritures comptables |
| **Ferme — gestion** | employés, paie (génération, ajustement, validation, paiement), fournisseurs |
| **Ferme — élevages** | bovins (troupeau, fiche, événements, sorties, traite, pesées, tableau de bord), embouche, couvoir et incubation, poules pondeuses, capteurs d'ambiance |
| **Ferme — communication** | messagerie d'équipe, aide et support (assistant + agent), formation (cours vidéo), parrainage, profil et mot de passe |
| **Ferme ↔ vétérinaire** | mes vétérinaires, documents reçus (ordonnances, rapports, instructions) à marquer appliqués, messagerie |
| **Vétérinaire — clinique (hors ligne)** | clients, patients, consultations, soins et vaccins avec rappels, rendez-vous, copie locale SQLite et file de saisies sans doublon |
| **Vétérinaire — cabinet (en ligne)** | devis, factures (création, émission, annulation, encaissement), ordonnances, vente au comptoir, catalogue, pharmacie (stock, lots, péremptions), fournisseurs, commandes avec réception, comptabilité, profil du cabinet |
| **Vétérinaire — fermes suivies** | invitations, synthèse sanitaire, dossier de lot, émission de documents à la ferme, actes sur les bovins, messagerie |

## Ce qui n'existe pas dans l'application

- **Partie administration**, volontairement exclue : portail d'administration, licences et paiements, utilisateurs / rôles / permissions, équipe du cabinet.
- **Fichiers** : imports et exports (Excel, CSV, PDF), envoi de photos et de vocaux dans les messages, guides PDF de formation (lecteur protégé du site).
- Création / modification des sites ; réglage des seuils d'alerte ; clés API et webhooks.
- Vétérinaire : documentation et formation du cabinet, parrainage, inventaire physique, étiquettes et scanner.
- Notifications push ; connexion Google ; builds Android / iOS (signature, icônes, `google-services`).
- Hors ligne : seulement la clinique du cabinet (le reste exige le réseau).

## Limites connues

- Le code côté serveur (`efarm360`, branche `claude/loving-faraday-c9jj8j`) n'a pas pu être exécuté contre une base MySQL pendant le développement : tester sur un serveur de recette avant publication.
- Pas de protection contre le double envoi d'une création (vente, document) si la réponse du serveur se perd.
- Les analyses et bilans sont affichés de façon générique (`DataTree`) : la mise en page évoluera avec les retours.

## Architecture

```
lib/
  core/        ApiClient (Dio, rafraîchissement unique des jetons), TokenStore, session (connexion, profil, offre)
  ui/          widgets communs (liste paginée, chargement / erreur)
  features/
    auth/      connexion
    farm/      accueil, rapports (+ formulaire), stock, alertes, sites
    commerce/  ventes, encaissements, clients, finance, dépenses, création de vente
    modules/   cadre générique : ModuleSpec (liste, détail, actions, formulaires typés, lignes, choix distants) + registres par domaine
    comm/      messagerie, support, formation, parrainage, profil
    vet/       VetRepo (copie locale + file + synchro), clinique, documents, ordonnances, cabinet, fermes suivies
    profile/   compte, appareils, déconnexion (efface la copie locale du cabinet)
test/          client HTTP, copie locale et file, droits, formulaires, modules, messagerie, cabinet
```

Ajouter un module : créer les routes `/api/mobile/v1/...` côté `efarm360` (contrôleur dérivé de `ApiMobileModuleController`, qui gère rôle, offre et droit),
puis décrire l'écran par un `ModuleSpec` dans `lib/features/modules/registry*.dart`.

## Build Android (release)

Créer `android/key.properties` (ignoré par git) :

```
storeFile=../upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

puis `flutter build apk --release` (ou `appbundle`). Sans ce fichier, le build est signé avec la clé de debug.
Le job CI `apk` publie aussi un APK en artefact.

## Windows et Web

Les plateformes `windows/` et `web/` sont générées. Lancer avec `flutter run -d windows` ou `flutter run -d chrome`.
- Windows : la base locale vétérinaire utilise `sqflite_common_ffi` (initialisé dans `main.dart`).
- Web : la base locale du cabinet vétérinaire est un SQLite dans le navigateur (WebAssembly, `web/sqlite3.wasm` et `web/sqflite_sw.js`, générés par `dart run sqflite_common_ffi_web:setup`). Le serveur doit autoriser le CORS pour l'origine de l'app.

## Modules masqués (serveur non implémenté)

`efarm360` (web) n'est pas modifié. L'application ne propose que ce que son `main` expose (`lib/core/server_support.dart`) :
connexion, appareils, résumé de ferme, sites, lots, rapports (lecture), stock (lecture), et côté vétérinaire tableau de bord,
clients, patients, rendez-vous, produits et synchronisation hors ligne.
Ventes, finances, bovins, embouche, couvoir, ponte, IoT, chat, support, formation, parrainage, cabinet vétérinaire, etc. restent
dans le code mais sont masqués. Pour réactiver un module, ajouter sa route dans `server_support.dart` (ou passer `hideUnsupported`
à `false` pour un serveur complet, avec l'API de la branche `claude/loving-faraday-c9jj8j` d'efarm360).

## Lecture hors ligne (ferme)

Chaque réponse GET réussie est conservée localement (`lib/core/response_cache.dart`, un fichier JSON par requête, effacé à la déconnexion).
Si le réseau est coupé, l'écran affiche la dernière copie et un bandeau « Hors ligne ». La saisie reste en ligne seulement ;
la clinique vétérinaire garde sa propre synchronisation complète (saisie hors ligne). Sur le web, la copie n'est conservée qu'en mémoire.

## Développer contre l'API complète

Par défaut, seuls les modules supportés par le `main` du serveur sont visibles. Pour voir toute l'application pendant le développement
(serveur de test qui expose l'API de la branche `claude/loving-faraday-c9jj8j` d'efarm360) :

```
flutter run -d windows --dart-define=FULL_API=true
```

## Détection automatique des fonctions du serveur

À la connexion, l'application lit le contrat public `/api/mobile/v1/openapi.json`. Un module n'est affiché que si le serveur déclare
sa route : dès que le site web est mis à jour avec l'API complète, les modules apparaissent sans nouvelle version de l'application.
Si le contrat est illisible (réseau coupé au tout premier démarrage), la liste statique de `lib/core/server_support.dart` est utilisée.
