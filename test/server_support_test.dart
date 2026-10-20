import 'package:efarm360/core/server_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => hideUnsupported = true);
  tearDown(() {
    hideUnsupported = false;
    resetContract();
  });

  test('routes déployées reconnues, identifiants normalisés', () {
    expect(serverGets('/farm/lots'), isTrue);
    expect(serverGets('/farm/lots/12'), isTrue);
    expect(serverGets('/vet/patients/\${p.id}'), isTrue);
    expect(serverCan('POST', '/vet/sync/push'), isTrue);
  });

  test('routes absentes du serveur masquées', () {
    expect(serverGets('/sales'), isFalse);
    expect(serverGets('/cattle'), isFalse);
    expect(serverCan('POST', '/farm/rapports'), isFalse);
    expect(serverCan('POST', '/vet/documents'), isFalse);
  });

  test('masquage désactivable', () {
    hideUnsupported = false;
    expect(serverGets('/sales'), isTrue);
  });

  test('contrat publié par le serveur : remplace la liste statique', () {
    useContract({
      'paths': {
        '/sales': {'get': {}, 'post': {}},
        '/sales/{id}/payments': {'post': {}},
        '/vet/farms/{societeId}/documents': {'post': {}},
      }
    });
    expect(serverGets('/sales'), isTrue);
    expect(serverCan('POST', '/sales'), isTrue);
    expect(serverCan('POST', '/sales/42/payments'), isTrue);
    expect(serverCan('POST', '/vet/farms/3/documents'), isTrue);
    expect(serverGets('/cattle'), isFalse);
    expect(serverGets('/farm/lots'), isFalse); // absent du contrat : masqué
  });

  test('contrat vide ou invalide : on garde la liste statique', () {
    useContract({'paths': {}});
    useContract(null);
    expect(serverGets('/farm/lots'), isTrue);
    expect(serverGets('/sales'), isFalse);
  });
}
