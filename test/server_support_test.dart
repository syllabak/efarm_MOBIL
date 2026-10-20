import 'package:efarm360/core/server_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => hideUnsupported = true);
  tearDown(() => hideUnsupported = false);

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
}
