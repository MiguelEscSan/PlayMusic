import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_dao.dart';

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => throw UnimplementedError('settingsDaoProvider se define en main()'),
);
