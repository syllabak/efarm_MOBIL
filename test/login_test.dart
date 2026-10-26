import 'package:flutter/material.dart';
import 'package:efarm360/core/session.dart';
import 'package:efarm360/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('sans jeton : écran de connexion, bascule exploitation / vétérinaire / code', (t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    await t.pumpWidget(const ProviderScope(child: EFarmApp()));
    await t.pumpAndSettle();
    expect(find.text('EFarm360'), findsOneWidget);
    expect(find.text('E-mail ou téléphone'), findsOneWidget);
    expect(find.text('Connexion par code (e-mail ou SMS)'), findsOneWidget);

    await t.tap(find.text('Connexion par code (e-mail ou SMS)'));
    await t.pump();
    expect(find.text('Mot de passe'), findsNothing);
    expect(find.text('Recevoir un code'), findsOneWidget);

    await t.tap(find.text('Vétérinaire'));
    await t.pump();
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Connexion par code (e-mail ou SMS)'), findsNothing);

    await t.tap(find.text('Se connecter'));
    await t.pump();
    expect(find.text('Requis'), findsNWidgets(2));
  });

  testWidgets('test du serveur : succès affiché à l\'utilisateur', (t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (api, _, _) = await makeClient({'GET /status': (_) => ok({'service': 'EFarm360', 'version': '1.0'})}, access: null, refresh: null);
    await t.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api)], child: const EFarmApp()));
    await t.pumpAndSettle();
    await t.tap(find.text('Options avancées'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Tester la connexion au serveur'));
    await t.tap(find.text('Tester la connexion au serveur'));
    await t.pumpAndSettle();
    expect(find.text('Serveur joignable : EFarm360, API mobile v1.0.'), findsOneWidget);
  });
}
