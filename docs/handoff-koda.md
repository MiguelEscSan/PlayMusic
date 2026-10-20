# Koda: contexto del proyecto para otro agente

Documento de traspaso de todo el proyecto `PlayMusic` (app **Koda**). Cubre qué hace la app, cómo está organizada, sus retos técnicos, lo que se trabajó en la última sesión y lo que queda pendiente. Lo marcado como **no verificado** necesita comprobación en un dispositivo.

## 1. Resumen

- **Qué es:** reproductor de audio híbrido para Android e iOS. Reproduce canciones por streaming desde YouTube o desde archivos descargados en el dispositivo.
- **Objetivo del proyecto:** demostrar arquitectura limpia, gestión de estado reactiva y audio en segundo plano en Flutter. Es un proyecto personal, no comercial. El README incluye un disclaimer legal sobre el uso de YouTube.
- **Repositorio:** `github.com/MiguelEscSan/PlayMusic`, rama `main`. El usuario pidió trabajar directamente en `main`.
- **Carpetas que no son nuestras:** `.atl/` y `scripts/` aparecen sin trackear. No tocar ni commitear.

## 2. Stack

| Área | Tecnología |
| --- | --- |
| Framework | Flutter (SDK `^3.13.5`), Dart |
| Estado | `flutter_riverpod` 3.4 |
| Audio | `just_audio` 0.10.6 + `audio_service` 0.18.19 |
| Streaming de YouTube | `youtube_explode_dart` 3.1.0 (y peticiones propias a InnerTube) |
| Red y descargas | `dio` 5.11.1, descargas por fragmentos |
| Base de datos | `sqflite` 2.4 (SQLite), esquema versión 2 |
| Otros | `cached_network_image`, `connectivity_plus`, `image_picker`, `uuid`, `path_provider`, `freezed`/`json_serializable` (modelos) |

Linter: `flutter_lints` 6. Tests con `flutter_test`, y `sqflite_common_ffi` para la BD en tests.

## 3. Funcionalidades

Cada funcionalidad es una carpeta en `lib/features/` con sus capas `domain`, `data` y `presentation`.

| Feature | Qué hace |
| --- | --- |
| `home` | Pantalla de inicio con secciones (top, recientes, playlists, favoritas). `home_shell.dart` tiene las 4 pestañas (Inicio, Buscar, Playlists, Descargas), el mini-reproductor y el layout responsive (barra inferior en móvil, rail lateral en pantallas anchas). |
| `search` | Búsqueda de canciones en YouTube, sugerencias mientras se escribe, historial de búsquedas y tarjetas de géneros. |
| `player` | Mini-reproductor, pantalla de reproducción completa, cola (`queue_sheet`), modos shuffle y repetir, y temporizador de apagado (`sleep_timer`). |
| `playback` | Reanudar la última reproducción al abrir la app (ver §5.4). |
| `playlists` | Crear, renombrar, borrar y ordenar playlists. Portada desde archivo. Importar playlists de YouTube y de Spotify a partir de un enlace. |
| `favorites` | "Me gusta" y la playlist automática "Me encanta" (`LikedPlaylist`). |
| `history` | Historial de reproducción: recientes y más escuchadas. Alimenta las secciones de inicio y la radio. |
| `radio` | Radio automática: cuando se acaba la cola, `RadioService` añade canciones parecidas, ordenadas por los gustos del usuario (`taste_ranker`). |
| `downloads` | Descargar canciones para escucharlas sin conexión, con progreso, cancelación y borrado. |
| `lyrics` | Letra sincronizada: parser de LRC y repositorio. |
| `export` | Exportar canciones a través de un canal nativo (`MethodChannel` `koda/export`). |
| `settings` | Radio on/off, descargar solo con Wi-Fi, uso de almacenamiento y borrar historial. |

## 4. Arquitectura

### 4.1 Organización

```
lib/
├── main.dart, app.dart, bootstrap.dart   # arranque: BD, resolver, audio, descargas, radio
├── core/                                  # compartido por varias features
│   ├── audio/        AudioPlayerService (interfaz), KodaAudioHandler,
│   │                 PlaybackSourceResolver, HttpRangeAudioSource
│   ├── database/     AppDatabase (esquema y migraciones), DAOs
│   ├── domain/       entidades (Song, Playlist, LastPlayback...), repositorios
│   │                 (interfaces), sources (puertos de fuentes de música)
│   ├── data/         implementaciones de repositorios y modelos
│   ├── settings/     SettingsDao y claves
│   ├── storage/      FilePaths (carpeta de música en el dispositivo)
│   └── error/        Result (Ok/Err) y Failure tipados
├── features/         una carpeta por funcionalidad (ver §3)
├── sources/youtube/  adaptador de YouTube (ver §6)
├── shared/           widgets reutilizables (song_tile, download_button, artwork_image...)
└── di/               providers de Riverpod: servicios, casos de uso, overrides
```

- **Regla de dependencias:** la UI nunca importa `just_audio`; usa `AudioPlayerService`, lo que permite testear con un fake.
- **Casos de uso:** cada operación tiene una clase en `domain/usecases` y un provider en `di/use_case_providers.dart`.
- **Errores:** los repositorios devuelven `Result<T>` (`Ok` o `Err` con un `Failure`), nunca lanzan.

### 4.2 Documentación existente (no duplicar, consultar)

- `ARCHITECTURE.md`: decisiones de la etapa inicial ("Paso 1"). Algunas partes están desactualizadas, por ejemplo el esquema y la lista de dependencias.
- `docs/music-source-ports.md`: puertos y adaptadores de fuentes de música (`SourceAdapter`, `SourceRegistry`, `IStreamResolver`, `ITrackSearch`, `IRadioSource`, `IRemotePlaylistSource`).
- `docs/release.md`: cómo publicar un APK de Android con un tag `v*`.
- `docs/plan-agentes.md`: plan para trabajar en paralelo con varios agentes en worktrees separados.
- `odd/tasks/`: documentos de tareas de funcionalidades grandes: `clean-architecture-refactor.md`, `fase-0-cimientos.md`, `music-source-ports.md`, `spotify-import.md`.
- `docs/handoff-koda.md`: este documento.

## 5. Datos y audio

### 5.1 Base de datos (SQLite, versión 2)

Migraciones en `core/database/app_database.dart`: cada cambio de esquema sube `_version` y añade un `case` en `_onUpgrade`.

| Tabla | Contenido |
| --- | --- |
| `songs` | Canciones. `source` + `source_id` son únicos. `local_path` nulo = no descargada. `stream_url` es solo caché. `liked_at`, `downloaded_at` e índices asociados. |
| `playlists` | Playlists con nombre, descripción, portada y fechas. |
| `playlist_songs` | Relación playlist↔canción con `position`. Clave primaria `(playlist_id, position)`. |
| `play_history` | Cada reproducción registrada, con su fecha (índice por fecha). |
| `search_history` | Búsquedas recientes. |
| `settings` | Pares clave-valor en texto. |

Claves de `settings` (en `core/settings/settings_dao.dart`): `radio.enabled`, `downloads.only_wifi`, `favorites.playlist_id`, `playback.last`.

### 5.2 Reproducción

- `AudioPlayerService` (`core/audio/audio_player_service.dart`) es la fachada única: cola, transporte, modos y ganchos (`songStarted`, `onQueueEnded`).
- `KodaAudioHandler` (`core/audio/koda_audio_handler.dart`) implementa esa interfaz sobre `just_audio` y `audio_service`. Carga una pista a la vez con `setAudioSource` y precarga la siguiente.
- `PlaybackSourceResolver` decide por canción: archivo local (`LocalFileSource`) si está descargada, o URL de streaming (`RemoteStreamSource`) si no.
- En Android, googlevideo responde 403 a las peticiones de ExoPlayer para URLs que sí acepta desde `dart:io`. Por eso `HttpRangeAudioSource` (`core/audio/http_range_audio_source.dart`) descarga los rangos con `HttpClient` y se los pasa a just_audio por su proxy local.
- Las URLs de googlevideo caducan. Se cachean en memoria en `playback_source_resolver_impl.dart` leyendo el parámetro `expire`, con un margen.

### 5.3 Fin de pista

El avance a la siguiente pista tiene dos caminos:

1. El evento `completed` del reproductor (`processingState`).
2. Un watchdog por posición: cuando la posición llega a 500 ms del final de la duración **guardada** (`stored`), se llama a `_endTrack`. Tiene una guarda (`_trackEndHandled`) para no saltar dos veces.

El watchdog se añadió porque en iOS `completed` no siempre llegaba (ver §7.1).

### 5.4 Reanudar la última reproducción

- Entidad `LastPlayback` (`core/domain/entities/last_playback.dart`): ids de la cola, índice y posición. Se guarda como JSON en `settings` con la clave `playback.last`. Solo se guardan ids, porque las URLs caducan.
- `LastPlaybackRecorder` (`features/playback/data/last_playback_recorder.dart`) guarda en cada cambio de estado y cada 5 s mientras suena.
- `restoreLastPlayback` lee el estado al arrancar. `KodaAudioHandler.restoreQueue` carga la cola en pausa, en la posición guardada, y omite canciones borradas.
- **Ojo:** la restauración resuelve la URL al arrancar aunque la canción no vaya a sonar. Sin conexión, la carga falla y muestra error.

## 6. Fuentes de música

- **YouTube (adaptador principal):** `lib/sources/youtube/`.
  - `youtube_innertube.dart`: cliente InnerTube compartido y helpers de JSON.
  - `youtube_stream_resolver.dart`: URL de audio fresca. Usa `youtube_explode_dart` y clientes de visionOS con `visitorData`.
  - `youtube_track_search.dart`, `youtube_track_matcher.dart`, `youtube_playlist_source.dart`, `youtube_radio_source.dart`, `youtube_suggestion_source.dart`.
- **Spotify:** solo para importar playlists desde un enlace. `spotify_playlist_importer.dart` y `track_match_scoring.dart` buscan cada tema en YouTube y puntúan la mejor coincidencia.
- **Jamendo:** aparece en el enum `SongSource` y en los puertos, pero **no encontré un adaptador implementado** (no verificado al 100%).
- **Puertos y registro:** `core/domain/sources/` (`SourceRegistry` elige el adaptador según `Song.source`).

## 7. Retos técnicos

### 7.1 Fin de pista en iOS (el problema más largo)

Síntoma: al terminar una canción no pasaba a la siguiente, tanto en streaming como con descargadas, y también en primer plano.

Lo verificado en el código de `just_audio` 0.10.6:
- `player.position` se extrapola con el reloj local mientras suena (`updatePosition + (now - updateTime) × speed`, `lib/just_audio.dart` ~línea 673). Chequearlo con un timer da precisión fina sin depender del stream.
- `positionStream` es compartido y usa `createPositionStream` con `steps: 800`. El período queda entre 16 ms y 200 ms, y en canciones largas es de 200 ms. Solo emite mientras suena.
- En iOS (`darwin/just_audio/Sources/just_audio/AudioPlayer.m`, `onComplete`), `completed` solo se dispara cuando se acaba **toda la lista**. Con una fuente por pista, eso equivale al final de la pista.
- `getDuration` (`AudioPlayer.m:382`) usa `CMTimeGetSeconds` sobre la duración de la fuente. Con un `StreamAudioSource` sin longitud conocida, puede no ser válida.
- El issue #316 de just_audio trata de `ConcatenatingAudioSource`, no de una fuente por pista. Para colas concatenadas, `positionDiscontinuityStream` avisa del cambio de pista.

Lo que se hizo: el watchdog de §5.3 (commit `b6e446b`), y el uso de la duración guardada (`dbb21da`). **Estado:** el usuario reportó que el auto-avance quedó arreglado. Confirmado en la conversación, sin prueba automatizada.

### 7.2 Duración del stream distinta a la guardada

- Caso concreto: el video `yYVCf-y2YmE` ("Playa Del Inglés - Quevedo, Myke Towers"). Según su página pública dura 255-256 s. La BD guarda `stored=256000`, correcto.
- El reproductor reportó `dur=510419` (8:30), casi el doble. La canción seguía sonando después de los 4:16.
- Hipótesis **no verificada**: la longitud o el `Content-Range` que se le pasa al proxy en `HttpRangeAudioSource.request` (líneas ~49-55) hacen que AVPlayer calcule mal la duración (factor ~2).
- Decisión tomada: `stored` es la referencia para la barra de progreso y el fin de pista. Se quitó el corrector que sobrescribía la BD con la duración del reproductor.

### 7.3 Descargas y límites de YouTube

- `DownloadManager` (`features/downloads/data/download_manager.dart`) descarga por fragmentos con `dio`. Concurrencia máxima de 2.
- `_downloadWithRetry` reintenta una vez si la URL devuelve 403 o 410, refrescando la URL.
- **Pendiente:** no hay backoff ante 429. Una descarga masiva resuelve canciones seguidas sin pausa, el patrón que activa la detección de bots de YouTube.
- **Riesgo de bloqueo por IP:** escuchar normalmente genera poca carga. El riesgo real está en descargas masivas. Un bloqueo suele durar horas o días, y es más probable en IPs de datacenter.

### 7.4 Rendimiento y batería

- Un timer de una sola vez por pista, más chequeos de posición en la última ventana, cuesta casi nada y no genera tráfico nativo.
- Un stream de posición de 50 ms aumentaría los eventos de la capa nativa, así que no se recomendó.
- Android: no requiere cambios para esto. Con el servicio de primer plano de audio activo, Doze debería respetar la reproducción. **Pendiente de probar** con la pantalla apagada.

## 8. Plataformas y CI

- **Android:** `.github/workflows/release.yml` analiza, testea y compila el APK al empujar un tag `v*`, y crea la GitHub Release con el APK adjunto. Ver `docs/release.md`.
- **iOS:** `.github/workflows/build-ipa.yml` es un workflow manual que genera un IPA sin firmar. **El usuario no quiere publicar instrucciones de compilación para iOS** (motivos legales), así que no van al README.
- **Sin Xcode** en la máquina de trabajo. Lo de iOS solo se valida con pruebas del usuario en su dispositivo.
- `server/` contiene un entorno de Python (`.venv`) para herramientas de yt-dlp. No es código de la app (no revisado en detalle).
- `tool/` contiene scripts de prueba de los clientes de YouTube (`yt_*.dart`). Hay avisos de lint en esos archivos; no afectan a la app.

## 9. Tests

- Unos 50 archivos en `test/`, organizados por feature. Ejemplos: `audio_queue_test.dart` (cola y avance por posición), `last_playback_test.dart` (reanudación), `download_manager_test.dart`, `playback_source_resolver_test.dart`, `radio_service_test.dart`, `lyrics_repository_test.dart`, `app_database_test.dart`, `settings_screen_test.dart`.
- `test/demo/demo_screenshots_test.dart`: genera los frames del recorrido de la demo (ver §10).
- Los fakes compartidos están en `test/domain/fakes/` y `test/helpers/`.

## 10. Demo y README

### 10.1 README

- Secciones: descripción, stack, arquitectura, retos resueltos, problemas conocidos, demo, cómo ejecutar.
- Se quitó la sección de compilación para iOS (ver §8).
- El disclaimer legal se mantiene.

### 10.2 Demo en video

- **Test:** `test/demo/demo_screenshots_test.dart`. Renderiza `HomeShell` con datos ficticios (canciones, playlists y búsquedas inventadas, carátulas generadas por la app) y captura 60 frames en `build/demo_frames/`, sin versionar.
- **Pantallas incluidas:** Inicio, Buscar, Playlists, Descargas y el reproductor (abierto desde el mini-reproductor).
- **No incluidas:** Ajustes (se abre desde el engranaje de Inicio) y el detalle de playlist. Si la demo debe cubrir toda la app, faltan.
- **Archivos:** `docs/demo/demo.mp4` (~150 KB, 10 fps, libx264) y `docs/demo/demo.gif` (~350 KB). El GIF pesa más que el MP4.
- **Codificación:** ffmpeg de `imageio-ffmpeg` (Python 3.10, instalado con pip).
- **Dependencias del entorno:** rutas fijas de Windows para las fuentes (`C:\Windows\Fonts\segoeui.ttf` y la fuente de iconos del SDK de Flutter). Si no existen, el test se salta.
- **Regla del usuario:** solo material original. Nada de carátulas ni nombres de artistas reales.
- **Detalle visual:** en el frame de Playlists, el botón "Nueva" tiene un borde negro de foco.

### 10.3 Portafolio

El usuario va a cargar Koda en su portafolio (formulario bilingüe "Nuevo proyecto"). Contenido acordado:

- **Slug:** `koda`. **Categoría:** Producto. **Año:** 2026. **Estado:** Publicado
- **Tags:** Flutter, Dart, Riverpod, Clean Architecture, just_audio, SQLite
- **URL código:** `https://github.com/MiguelEscSan/PlayMusic`. **URL live:** vacía (no hay versión publicada)
- **Cliente:** Proyecto personal
- **Rol:** Mobile Developer (EN) / Desarrollador móvil (ES)
- **Título:** Koda
- Descripciones y retos redactados en ES y EN en la conversación. **Pendiente:** decidir si el relleno se hace en el navegador o lo copia el usuario.

## 11. Historial de esta sesión

| Commit | Qué hace |
| --- | --- |
| `d3c379a` | Reanudar la última reproducción (§5.4). |
| `b6e446b` | Watchdog de fin de pista por posición (§5.3). |
| `6f7a32f`, `1e0e51e` | Readout temporal de diagnóstico y su retirada. |
| `f05f9ac` | Intento de corregir la duración guardada. Se revirtió. |
| `dbb21da` | Usa la duración guardada para la barra y el fin de pista (§7.2). |
| `a6ccdfd`, `f4a0882` | README: stack, retos y problemas conocidos. Se quitó la sección iOS. |
| `a1edc15`, `d206bac` | Demo: MP4 y GIF desde el test de widgets. |
| `4c1c5f3` | Este documento (versión inicial de la sesión). |

Nota: el commit remoto `4c06047` borró `docs/demo/demo.mp4`. El video sigue en el historial (`d206bac`).

## 12. Pendientes

1. Confirmar en dispositivo el auto-avance y la barra de progreso con la duración guardada (usuario).
2. Investigar por qué algunos streams reportan el doble de duración (§7.2).
3. Agregar backoff ante 429 en `DownloadManager` (§7.3).
4. Probar la reproducción con la pantalla apagada en Android, para validar Doze (§7.4).
5. Incluir Ajustes y el detalle de playlist en el recorrido de la demo, si la demo debe cubrir toda la app (§10.2).
6. Revisar el borde de foco del botón "Nueva" en la captura de Playlists (§10.2).
7. Decidir el relleno del portafolio: navegador o copia manual (§10.3).
8. Revisar si `ARCHITECTURE.md` debe actualizarse con el estado actual (esquema, dependencias, Jamendo).

## 13. Cómo verificar

```bash
flutter analyze
flutter test test/audio_queue_test.dart test/last_playback_test.dart test/di test/domain
flutter test
flutter test test/demo/demo_screenshots_test.dart
```

El último comando regenera los frames de `build/demo_frames/`. Después, ffmpeg los codifica a `docs/demo/demo.mp4` y a `docs/demo/demo.gif`.
