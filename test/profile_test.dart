import 'package:efarm360/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rôles autorisés à saisir un rapport (comme sur le web)', () {
    for (final r in ['admin', 'responsable', 'employe']) {
      expect(Profile({'type': 'ferme', 'id': 1, 'role': r}).canReport, isTrue, reason: r);
    }
    expect(Profile({'type': 'ferme', 'id': 1, 'role': 'siege'}).canReport, isFalse);
  });

  test('droits du cabinet : le titulaire a tout, le collaborateur suit ses droits', () {
    final owner = Profile({'type': 'veterinaire', 'id': 1, 'titulaire': true, 'droits': {}});
    final member = Profile({'type': 'veterinaire', 'id': 1, 'titulaire': false, 'droits': {'clinique': true, 'stock': false}});
    expect(owner.can('compta'), isTrue);
    expect(member.can('clinique'), isTrue);
    expect(member.can('stock'), isFalse);
    expect(member.can('inconnu'), isFalse);
  });
}
