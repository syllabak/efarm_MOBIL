import 'package:efarm360/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sans jeton : écran de connexion, bascule exploitation / vétérinaire / code', (t) async {
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
}
