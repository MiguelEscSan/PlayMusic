import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

/// Ajustes de la app. Por ahora vacía: la rellena la funcionalidad de
/// Ajustes (calidad de descarga, espacio ocupado, solo wifi...).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajustes')),
    body: const EmptyState(
      icon: Icons.settings_outlined,
      title: 'Todavía no hay ajustes',
    ),
  );
}
