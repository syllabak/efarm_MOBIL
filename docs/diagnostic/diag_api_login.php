<?php
// Diagnostic TEMPORAIRE de l'API mobile : affiche l'erreur PHP exacte au lieu de « Erreur interne ».
// À déposer à la racine du site (à côté de index.php), à utiliser le temps d'un test, puis À SUPPRIMER.
// Remplacez CHANGEZ-MOI par un secret d'au moins 12 lettres/chiffres (une seule modification, à la ligne ci-dessous).
const CLE_DIAG = 'CHANGEZ-MOI';

// Adresse à saisir dans l'application : https://VOTRE-DOMAINE/diag_api_login.php?k=VOTRE-SECRET&r=
// (l'application y ajoute /api/mobile/v1/… : aucun chemin supplémentaire n'est nécessaire côté Apache)
$k = (string)($_GET['k'] ?? '');
$r = (string)($_GET['r'] ?? '');
if (strlen(CLE_DIAG) < 12 || !hash_equals(CLE_DIAG, $k) || !str_starts_with($r, '/api/mobile/')) { http_response_code(404); exit; }

// Navigateur (Chrome) : autorise l'application locale à appeler ce fichier de test (CORS), uniquement pour ce diagnostic.
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') { http_response_code(204); exit; }

// On rejoue la requête (même route, mêmes données) avec l'affichage détaillé des erreurs.
unset($_GET['k'], $_GET['r']);
$requete = http_build_query($_GET);
$_SERVER['REQUEST_URI'] = $r . ($requete !== '' ? '?' . $requete : '');
$_SERVER['QUERY_STRING'] = $requete;
$_SERVER['SCRIPT_NAME'] = '/index.php';
define('APP_DEBUG', true);
header('X-Diagnostic: efarm360');
require __DIR__ . '/index.php';
