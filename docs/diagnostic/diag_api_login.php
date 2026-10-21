<?php
// Diagnostic TEMPORAIRE de l'API mobile : affiche l'erreur PHP exacte au lieu de « Erreur interne ».
// À déposer à la racine du site (à côté de index.php), à utiliser le temps d'un test, puis À SUPPRIMER.
// Remplacez CHANGEZ-MOI par une longue valeur secrète (lettres et chiffres, sans « / »).
const CLE_DIAG = 'CHANGEZ-MOI';

$chemin = (string)parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH);
$prefixe = '/' . basename(__FILE__) . '/' . CLE_DIAG;
if (CLE_DIAG === 'CHANGEZ-MOI' || !str_starts_with($chemin, $prefixe . '/')) { http_response_code(404); exit; }

// On rejoue la requête telle quelle (mêmes données, même route), mais avec l'affichage détaillé des erreurs.
$_SERVER['REQUEST_URI'] = substr($chemin, strlen($prefixe)) . (isset($_SERVER['QUERY_STRING']) && $_SERVER['QUERY_STRING'] !== '' ? '?' . $_SERVER['QUERY_STRING'] : '');
$_SERVER['SCRIPT_NAME'] = '/index.php';
define('APP_DEBUG', true);
header('X-Diagnostic: efarm360');
require __DIR__ . '/index.php';
