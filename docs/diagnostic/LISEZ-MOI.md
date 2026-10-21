# Diagnostic d'une erreur 500 de l'API mobile

Quand le serveur répond « Erreur interne — Réessayez. » (HTTP 500), le site cache volontairement la cause en production.
`diag_api_login.php` rejoue la requête de l'application avec l'affichage détaillé des erreurs, **sans modifier le code du site**.

1. Dans `diag_api_login.php`, remplacez `CHANGEZ-MOI` (une seule fois, ligne `const CLE_DIAG`) par un secret d'au moins 12 lettres/chiffres.
2. Copiez le fichier à la racine du site (à côté de `index.php`).
3. Test dans le navigateur : `https://VOTRE-DOMAINE/diag_api_login.php?k=VOTRE-SECRET&r=/api/mobile/v1/status` doit afficher le JSON du service.
4. Dans l'application : Options avancées → Adresse du serveur = `https://VOTRE-DOMAINE/diag_api_login.php?k=VOTRE-SECRET&r=`, puis se connecter.
5. Le message d'erreur (fichier, ligne, cause) s'affiche. En navigateur : onglet Network → requête `login` → Response.
6. **Supprimez `diag_api_login.php` du serveur dès le test terminé** et remettez l'adresse normale dans l'application.

Sans le bon secret, le fichier répond 404 et ne fait rien. L'adresse passe par des paramètres (`?k=…&r=…`) et non par un chemin,
car certains hébergements mutualisés refusent les URL de la forme `fichier.php/chemin`.
