# Spoñify — Arquitectura (Paso 1)

## Decisiones

| Tema | Elección | Por qué |
|---|---|---|
| Organización | **Feature-first** con capas internas (data / domain / presentation) | Cada pantalla crece sin tocar las demás; lo compartido vive en `core/`. |
| Estado | **Riverpod** (`flutter_riverpod`) | Inyección de dependencias + streams del reproductor sin `BuildContext`. Cambiable si prefieres Bloc. |
| Base de datos | **sqflite** | Relaciones playlist↔canción con orden (`position`) son naturales en SQL. Isar está prácticamente sin mantenimiento. |
| Audio | `just_audio` + `audio_service` detrás de `AudioPlayerService` | La UI nunca importa just_audio; se puede testear con un fake. |
| Fuente de música | `youtube_explode_dart` (primaria), Jamendo (opcional) | `SongSource` + `sourceId` permiten mezclar orígenes. |

## Estructura de carpetas

```
lib/
├── main.dart                         # ProviderScope + overrides
├── bootstrap.dart                    # crea BD, resolver, audio, descargas, playlists
├── app.dart                          # MaterialApp + tema
│
├── core/                             # lo que usan varias features
│   ├── models/          song.dart · playlist.dart
│   ├── audio/           audio_player_service.dart (interfaz)
│   │                    sponify_audio_handler.dart (just_audio + audio_service)
│   │                    playback_source*.dart (local vs streaming)
│   │                    stream_url_provider.dart (URLs frescas de YouTube)
│   │                    audio_bootstrap.dart · audio_providers.dart
│   ├── database/        app_database.dart (esquema + migraciones) · song_dao.dart
│   ├── storage/         file_paths.dart (<appDocs>/music/<id>.m4a)
│   └── utils/           formatters.dart (duración, MB, "N canciones")
│
├── features/
│   ├── home/            home_shell.dart (pestañas + mini-reproductor, responsive)
│   ├── search/
│   │   ├── data/        search_source.dart · youtube_search_source.dart
│   │   └── presentation/ search_controller.dart · search_screen.dart
│   ├── player/
│   │   └── presentation/ mini_player.dart · now_playing_screen.dart · queue_sheet.dart
│   ├── playlists/
│   │   ├── data/        playlist_dao.dart
│   │   └── presentation/ playlists_screen.dart · playlist_detail_screen.dart
│   │                    playlists_providers.dart · widgets/add_to_playlist_sheet.dart
│   └── downloads/
│       ├── data/        download_manager.dart (dio por trozos + progreso)
│       ├── domain/      download_task.dart
│       └── presentation/ downloads_screen.dart · downloads_providers.dart
│
└── shared/
    ├── song_actions.dart             # reproducir / cola / descargar desde cualquier pantalla
    └── widgets/         song_tile.dart · download_button.dart · artwork_image.dart
                         dialogs.dart · empty_state.dart
```

## Esquema SQLite

```sql
CREATE TABLE songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT,
  duration_ms INTEGER NOT NULL,
  artwork_url TEXT,
  source TEXT NOT NULL,          -- youtube | jamendo | local
  source_id TEXT NOT NULL,
  stream_url TEXT,               -- caché, puede caducar
  local_path TEXT,               -- NULL = no descargada
  file_size_bytes INTEGER,
  downloaded_at INTEGER,
  UNIQUE (source, source_id)
);

CREATE TABLE playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  cover_url TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE playlist_songs (
  playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  song_id     TEXT NOT NULL REFERENCES songs(id)     ON DELETE CASCADE,
  position    INTEGER NOT NULL,
  PRIMARY KEY (playlist_id, position)
);
```

## Cambios respecto al modelo sugerido

- **`isDownloaded` es un getter** (`localPath != null`), no un campo: así nunca puede quedar desincronizado con la ruta.
- **`downloadProgress` no se persiste.** Está en el modelo para pintar la UI, pero la fuente de verdad es el stream del gestor de descargas (Paso 3).
- **Se añaden `source` y `sourceId`.** Las URLs de streaming de YouTube caducan a las pocas horas, así que `streamUrl` es solo caché y el resolver pide una nueva cuando hace falta.
- **`durationMs`** en vez de `duration` para que la unidad sea explícita; hay un getter `duration` que devuelve `Duration`.
- **Igualdad por origen** (`source` + `sourceId`), para no duplicar la misma canción al guardarla dos veces.

## Dependencias previstas (`pubspec.yaml`, se añadirán al crear el proyecto)

```yaml
dependencies:
  flutter_riverpod:
  just_audio:
  audio_service:
  just_audio_background:   # opcional, si no usamos audio_service a mano
  dio:
  path_provider:
  sqflite:
  path:
  uuid:
  youtube_explode_dart:
  cached_network_image:
  connectivity_plus:
```

## Cómo encaja el reproductor híbrido

```
UI ──playSong(song)──▶ AudioPlayerService
                           │
                           ▼
                 PlaybackSourceResolver.resolve(song)
                    │                       │
        archivo existe               no hay archivo
                    ▼                       ▼
           LocalFileSource        RemoteStreamSource (URL fresca si caducó)
                    │                       │
                    └──────▶ just_audio ◀───┘
                    AudioSource.file / AudioSource.uri
```
