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

String _norm(String path) => path.split('?').first.replaceAllMapped(RegExp(r'/(\d+|\{[a-z_]+\}|\$\w+|\$\{[^}]*\})(?=/|$)'), (_) => '/{id}');

/// Le serveur sait-il répondre à ce chemin ? (`method` : GET, POST, PUT, DELETE…)
bool serverCan(String method, String path) {
  if (!hideUnsupported) return true;
  final p = _norm(path);
  return method.toUpperCase() == 'GET' ? _get.contains(p) : _write.contains('${method.toUpperCase()} $p');
}

bool serverGets(String path) => serverCan('GET', path);
