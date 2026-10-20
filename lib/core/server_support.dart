/// Routes de l'API mobile réellement déployées sur le serveur (`main` d'efarm360).
///
/// Tout ce qui n'y figure pas est masqué dans l'application jusqu'à ce que le serveur l'implémente :
/// il suffit alors d'ajouter la route ici pour que le module réapparaisse.
/// `flutter run --dart-define=FULL_API=true` affiche tous les modules (serveur de développement avec l'API complète).
bool hideUnsupported = !const bool.fromEnvironment('FULL_API');

const _get = <String>{
  '/me', '/devices', '/status',
  '/farm/resume', '/farm/sites', '/farm/lots', '/farm/lots/{id}', '/farm/rapports', '/farm/stock',
  '/vet/dashboard', '/vet/clients', '/vet/patients', '/vet/patients/{id}', '/vet/produits', '/vet/rendez-vous',
  '/vet/sync/snapshot',
};

const _write = <String>{
  'POST /auth/logout', 'POST /auth/logout-all', 'POST /vet/sync/push',
};

String _norm(String path) => path.split('?').first.replaceAllMapped(RegExp(r'/(\d+|\{[A-Za-z_]+\}|\$\w+|\$\{[^}]*\})(?=/|$)'), (_) => '/{id}');

Set<String>? _live;

/// Contrat réellement publié par le serveur (`/openapi.json`) : remplace la liste ci-dessus.
/// Ainsi, dès que le serveur est mis à jour, les modules réapparaissent sans nouvelle version de l'application.
void useContract(Map<String, dynamic>? openapi) {
  final paths = openapi?['paths'];
  if (paths is! Map || paths.isEmpty) return;
  _live = {
    for (final e in paths.entries)
      if (e.value is Map)
        for (final m in (e.value as Map).keys)
          if (const {'get', 'post', 'put', 'patch', 'delete'}.contains('$m'.toLowerCase())) '${'$m'.toUpperCase()} ${_norm('${e.key}')}',
  };
}

/// Le serveur sait-il répondre à ce chemin ? (`method` : GET, POST, PUT, DELETE…)
bool serverCan(String method, String path) {
  if (!hideUnsupported) return true;
  final key = '${method.toUpperCase()} ${_norm(path)}';
  final live = _live;
  if (live != null) return live.contains(key);
  return method.toUpperCase() == 'GET' ? _get.contains(_norm(path)) : _write.contains(key);
}

bool serverGets(String path) => serverCan('GET', path);

/// Pour les tests : retour à la liste statique.
void resetContract() => _live = null;
