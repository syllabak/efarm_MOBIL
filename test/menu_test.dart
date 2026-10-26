import 'package:efarm360/core/server_support.dart';
import 'package:efarm360/core/session.dart';
import 'package:efarm360/features/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _Admin extends SessionNotifier {
  @override
  Future<Profile?> build() async => Profile({'type': 'ferme', 'id': 1, 'role': 'admin', 'tous_les_sites': true});
}

void main() {
  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (api, _, _) = await makeClient({});
    await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api), sessionProvider.overrideWith(_Admin.new)], child: const MaterialApp(home: Scaffold(body: FarmMore()))));
    await t.pumpAndSettle();
  }

  testWidgets('serveur actuel : seuls les modules disponibles sont proposés', (t) async {
    hideUnsupported = true;
    addTearDown(() => hideUnsupported = false);
    await pump(t);
    expect(find.text('Sites & Fermes'), findsOneWidget);
    expect(find.text('Mon compte'), findsOneWidget);
    for (final m in ['Ventes commerciales', 'Clients', 'Finance & ROI', 'Alertes', 'Bovins', 'Messagerie']) {
      expect(find.text(m), findsNothing, reason: m);
    }
  });

  testWidgets('serveur complet : les modules reviennent', (t) async {
    hideUnsupported = false;
    await pump(t);
    expect(find.text('Ventes commerciales', skipOffstage: false), findsOneWidget);
    expect(find.text('Finance & ROI', skipOffstage: false), findsOneWidget);
    expect(find.text('Alertes', skipOffstage: false), findsOneWidget);
  });
}
