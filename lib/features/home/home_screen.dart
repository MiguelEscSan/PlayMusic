import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/empty_state.dart';
import '../settings/presentation/settings_screen.dart';
import 'home_sections.dart';

/// Pestaña Inicio: las secciones registradas en [homeSectionsProvider], en
/// orden, y acceso a Ajustes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = [
      for (final section in ref.watch(homeSectionsProvider))
        if (section.hasContent == null || ref.watch(section.hasContent!))
          section,
    ]..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: sections.isEmpty
          ? const EmptyState(
              icon: Icons.home_outlined,
              title: 'Aquí aparecerá tu música',
              message: 'Tus favoritas y lo último que escuchaste.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final section in sections)
                  KeyedSubtree(
                    key: ValueKey(section.id),
                    child: section.builder(context),
                  ),
              ],
            ),
    );
  }
}
