import 'dart:async';

import 'package:efarm360/core/server_support.dart';

/// Les tests exercent tous les modules : on désactive le masquage des routes non déployées.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  hideUnsupported = false;
  await testMain();
}
