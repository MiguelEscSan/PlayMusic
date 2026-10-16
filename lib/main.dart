import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'di/app_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = await bootstrap();
  runApp(
    ProviderScope(overrides: appOverrides(deps), child: const SponifyApp()),
  );
}
