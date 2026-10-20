import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/session.dart';
import 'core/theme.dart';
import 'features/auth/login_page.dart';
import 'features/home_shell.dart';
import 'ui/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bureau : sqflite passe par FFI. Web : pas de base locale (mode hors ligne vétérinaire indisponible).
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await initializeDateFormatting('fr_FR');
  runApp(const ProviderScope(child: EFarmApp()));
}

class EFarmApp extends StatelessWidget {
  const EFarmApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EFarm360',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: const _Root(),
      );
}

/// Choisit l'écran selon l'état de la session : la déconnexion (ou une session expirée) ramène à la connexion.
class _Root extends ConsumerWidget {
  const _Root();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(sessionProvider).when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: ErrorView(e, onRetry: () => ref.invalidate(sessionProvider))),
        data: (p) => p == null ? const LoginPage() : const HomeShell(),
      );
}
