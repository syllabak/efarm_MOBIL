import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/comm/account_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _Admin extends SessionNotifier {
  @override
  Future<Profile?> build() async => Profile({'type': 'ferme', 'id': 1, 'role': 'admin', 'tous_les_sites': true});
}

void main() {
  testWidgets('double authentification : configuration, confirmation par code, codes de récupération', (t) async {
    var actif = false;
    Map<String, dynamic>? enable;
    final (api, _, _) = await makeClient({
      'GET /profile/2fa': (_) => ok({'actif': actif}),
      'POST /profile/2fa/setup': (_) => ok({'secret': 'JBSWY3DPEHPK3PXP', 'otpauth_url': 'otpauth://totp/EFarm360:a%40b.sn?secret=JBSWY3DPEHPK3PXP&issuer=EFarm360'}),
      'POST /profile/2fa/enable': (o) {
        enable = Map<String, dynamic>.from(o.data as Map);
        actif = true;
        return ok({'codes_recuperation': ['AAAA1111', 'BBBB2222']});
      },
      'GET /me': (_) => ok({'type': 'ferme', 'id': 1, 'role': 'admin', 'tous_les_sites': true, 'deux_facteurs': true}),
    });
    await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api), sessionProvider.overrideWith(_Admin.new)], child: const MaterialApp(home: TwoFactorPage())));
    await t.pumpAndSettle();
    expect(find.text('Désactivée'), findsOneWidget);
    await t.tap(find.text('Commencer'));
    await t.pumpAndSettle();
    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    await t.enterText(find.byType(TextField), '123456');
    await t.ensureVisible(find.text('Activer'));
    await t.tap(find.text('Activer'));
    await t.pumpAndSettle();
    expect(enable, {'secret': 'JBSWY3DPEHPK3PXP', 'code': '123456'});
    expect(find.textContaining('AAAA1111'), findsOneWidget);
    await t.tap(find.text('J\'ai noté mes codes'));
    await t.pumpAndSettle();
    expect(find.text('Activée'), findsOneWidget);
  });
}
