# Tester l'API EFarm360 avec Postman

1. Postman → **Import** → choisissez `EFarm360-mobile.postman_collection.json` (198 requêtes, regroupées par thème).
   Autre possibilité : importer directement `https://efarm360.danov.sn/api/mobile/v1/openapi.json`.
   Attention : le contrat en ligne ne liste que les routes **déjà déployées** sur le serveur.
2. Ouvrez la collection → onglet **Variables** → renseignez **email** et **password** (votre compte, jamais partagé) ; `base_url` est déjà
   `https://efarm360.danov.sn/api/mobile/v1`.
3. Dossier « Auth » → **POST /auth/login** → *Send*. Le jeton d'accès est enregistré automatiquement (`access_token`, `refresh_token`).
   - Réponse `two_factor_required` : envoyez **POST /auth/2fa** avec `{ "token": "…", "code": "123456" }`.
   - Compte vétérinaire : changez `"type": "ferme"` en `"type": "veterinaire"` dans le corps.
4. Les autres requêtes utilisent automatiquement `Authorization: Bearer {{access_token}}` (valable 1 h ; **POST /auth/refresh** le renouvelle).
5. Première vérification sans compte : **GET /status** doit répondre `{"success":true,"data":{"service":"EFarm360",…}}`.

Codes d'erreur utiles : `401 non_authentifie` (en-tête Authorization perdu par l'hébergement), `401 jeton_invalide` (jeton expiré),
`404` (route non déployée), `500` (erreur du serveur : voir `storage/logs/php_errors.log`).
