import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/audio/audio_providers.dart';
import 'features/downloads/presentation/downloads_providers.dart';
import 'features/playlists/presentation/playlists_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = await bootstrap();
  runApp(
    ProviderScope(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(deps.audio),
        songDaoProvider.overrideWithValue(deps.songDao),
        playlistDaoProvider.overrideWithValue(deps.playlistDao),
        downloadManagerProvider.overrideWithValue(deps.downloads),
      ],
      child: const SponifyApp(),
    ),
  );
}
