# Diagnostic d'une erreur 500 de l'API mobile

Quand le serveur répond « Erreur interne — Réessayez. » (HTTP 500), le site cache volontairement la cause en production.
`diag_api_login.php` rejoue la requête de l'application avec l'affichage détaillé des erreurs, **sans modifier le code du site**.

1. Copiez `diag_api_login.php` à la racine du site (à côté de `index.php`) et remplacez `CHANGEZ-MOI` par un secret long (lettres et chiffres).
2. Dans l'application : Options avancées → Adresse du serveur = `https://VOTRE-DOMAINE/diag_api_login.php/VOTRE-SECRET`, puis se connecter.
3. Le message d'erreur (fichier, ligne, cause) s'affiche. En navigateur : onglet Network → requête `login` → Response.
4. **Supprimez `diag_api_login.php` du serveur dès le test terminé** : il révèle des chemins et des détails internes.

Sans le bon secret dans l'adresse, le fichier répond 404 et ne fait rien.
