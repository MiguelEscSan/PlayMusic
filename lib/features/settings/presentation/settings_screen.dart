import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_dao.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../downloads/presentation/downloads_providers.dart';
import '../../history/presentation/history_providers.dart';
import 'settings_providers.dart';

/// Ajustes de la app: radio automática, descargas (solo wifi, espacio
/// ocupado, borrar todo), historial y acerca de.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const appName = 'Spoñify';
  static const appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mientras carga se muestran los valores por defecto.
    final radio = ref.watch(radioEnabledProvider).value ?? true;
    final onlyWifi = ref.watch(downloadOnlyWifiProvider).value ?? false;
    final usage = ref.watch(storageUsageProvider);

    Future<void> setBool(String key, bool value) =>
        ref.read(settingsDaoProvider).setBool(key, value);

    Future<void> deleteDownloads() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Borrar todas las descargas',
        message:
            'Se liberarán ${formatBytes(usage?.bytes ?? 0)}. Las canciones '
            'seguirán en tus playlists para escucharlas en streaming.',
        confirmLabel: 'Borrar todo',
      );
      if (ok) await ref.read(downloadManagerProvider).deleteAll();
    }

    Future<void> clearHistory() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Borrar historial de escucha',
        message: 'Se borrará lo escuchado recientemente. No se puede deshacer.',
      );
      if (!ok) return;
      await ref.read(historyDaoProvider).clear();
      if (context.mounted) showSnack(context, 'Historial borrado');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _SectionTitle('Reproducción'),
          SwitchListTile(
            secondary: const Icon(Icons.radio_rounded),
            title: const Text('Radio automática'),
            subtitle: const Text(
              'Al acabar la cola, sigue con canciones parecidas',
            ),
            value: radio,
            onChanged: (v) => setBool(SettingsKeys.radioEnabled, v),
          ),
          const _SectionTitle('Descargas'),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_rounded),
            title: const Text('Descargar solo con wifi'),
            subtitle: const Text('No usa datos móviles para descargar'),
            value: onlyWifi,
            onChanged: (v) => setBool(SettingsKeys.downloadOnlyWifi, v),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_rounded),
            title: const Text('Espacio ocupado'),
            subtitle: Text(
              usage == null
                  ? 'Calculando…'
                  : '${formatBytes(usage.bytes)} · ${songCount(usage.songs)}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Borrar todas las descargas'),
            subtitle: const Text('Las canciones seguirán en streaming'),
            enabled: usage == null || usage.songs > 0,
            onTap: deleteDownloads,
          ),
          const _SectionTitle('Historial'),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Borrar historial de escucha'),
            onTap: clearHistory,
          ),
          const _SectionTitle('Acerca de'),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text(appName),
            subtitle: Text('Versión $appVersion'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
