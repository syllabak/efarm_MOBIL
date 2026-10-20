# EFarm360 — application mobile (Flutter)

Application Android / iOS d'[EFarm360](https://github.com/syllabak/efarm360). Elle parle uniquement à l'**API mobile** du site web
(`/api/mobile/v1`, voir `docs/api/mobile-v1.md` et `openapi.json` dans le dépôt `efarm360`) : aucune base de données ni logique métier dupliquée,
les droits, la licence et les règles sont ceux du serveur.

Serveur par défaut : `https://efarm360.danov.sn` (modifiable dans « Options avancées » de l'écran de connexion).

## Lancer

```bash
flutter pub get
flutter run
flutter analyze && flutter test
```

## Ce qui est couvert

| Domaine | État |
|---|---|
| Connexion exploitation (e-mail ou téléphone + mot de passe, code société facultatif, choix de société si plusieurs) | ✅ |
| Connexion par code à usage unique (e-mail ou SMS) | ✅ |
| Double authentification (code ou code de récupération) | ✅ |
| Connexion vétérinaire (titulaire ou collaborateur) | ✅ |
| Jetons : stockage sécurisé, rafraîchissement automatique avec rotation (un seul à la fois), déconnexion cet appareil / tous | ✅ |
| Profil, licence, appareils connectés | ✅ |
| Ferme : tableau de bord, sites, lots (liste, détail), rapports, stock avec alertes de seuil | ✅ lecture |
| Ferme : **saisie du rapport journalier** (mortalité par cause, aliment, eau, températures, poids, œufs pour les pondeuses) | ✅ (nécessite `POST /farm/rapports`, ajouté au site web) |
| Cabinet vétérinaire : clients, patients, historique, consultations, soins/vaccins avec rappels, rendez-vous, pharmacie | ✅ |
| Cabinet vétérinaire **hors ligne** : copie locale (SQLite), file de saisies avec identifiant unique, envoi sans doublon, saisies refusées visibles et corrigeables | ✅ |

## Ce qui n'existe pas encore (et pourquoi)

Le site web compte plusieurs centaines de pages (ventes, finance, comptabilité, paie, bovins, embouche, couvoir, ponte détaillée, IoT, messagerie,
formation, support, administration, facturation et ordonnances vétérinaires…). **L'API mobile n'expose aujourd'hui que la ferme (lecture + rapport journalier) et la clinique vétérinaire.**
Une fonctionnalité du web apparaît dans l'application dès que son point d'accès `/api/mobile/v1/...` existe : l'application ne contourne jamais l'API.

Marche à suivre pour ajouter un module (ex. ventes) :
1. côté `efarm360` : contrôleur `ApiMobile…Controller` qui réutilise les services du module (droits, licence et isolation par société déjà gérés par `ApiMobileController`), route dans `index.php`, entrée dans `docs/api/*` ;
2. côté application : une page dans `lib/features/<module>/` qui appelle `ApiClient` ; les écritures hors ligne passent par une file avec `ref` unique, comme `lib/features/vet/vet_repo.dart`.

Limites connues :
- la saisie du rapport journalier exige le réseau (pas de file hors ligne côté ferme) ;
- notifications push et connexion Google ne sont pas branchées ;
- les builds Android/iOS (signature, icônes, `google-services`) ne sont pas configurés.

## Architecture

```
lib/
  core/        ApiClient (Dio, rafraîchissement des jetons), TokenStore (stockage sécurisé), session (connexion, profil)
  ui/          widgets communs (liste paginée, chargement/erreur)
  features/
    auth/      écran de connexion (mot de passe, code, 2FA, société)
    farm/      accueil, lots, rapports (+ formulaire), stock, sites
    vet/       VetRepo (copie locale + file + synchronisation), pages et formulaires
    profile/   compte, appareils, déconnexion (efface la copie locale du cabinet)
test/          client HTTP (rotation des jetons), copie locale et file hors ligne, droits, écran de connexion
```
