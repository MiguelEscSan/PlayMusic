# Plan de trabajo en paralelo con varios agentes

Objetivo: implementar las 9 mejoras propuestas con varios agentes trabajando a
la vez, sin pisarse. Cada agente trabaja en su propio `git worktree` y rama, y
un integrador fusiona en orden.

## Por qué no se pueden lanzar las 9 a la vez

Hay archivos que tocarían casi todas las funcionalidades. Si dos agentes los
editan en paralelo, las fusiones chocan.

| Archivo compartido | Lo tocarían |
|---|---|
| `lib/core/database/app_database.dart` (`_version` y migraciones) | Favoritos, Historial, Búsquedas, Ajustes |
| `lib/core/audio/koda_audio_handler.dart` | Historial, Temporizador, Radio, Plan B 403 |
| `lib/features/home/home_shell.dart` (pestañas) | Inicio (Favoritos + Historial), Ajustes |
| `lib/shared/widgets/song_tile.dart` | Favoritos |
| `lib/features/player/presentation/now_playing_screen.dart` | Favoritos, Temporizador |
| `lib/bootstrap.dart`, `lib/main.dart` | Todas (overrides de providers) |

Solución: una **oleada 0** secuencial prepara esos puntos de extensión una sola
vez. Después cada funcionalidad solo **añade** código en su propia carpeta y en
huecos ya preparados.

## Oleada 0: cimientos (1 agente, secuencial)

Requisito previo: commit de la línea base actual (lo que hay sin commitear:
quitar iOS, cliente visionOS, portadas, etc.). Sin ese commit no se pueden
crear worktrees limpios.

1. **Tests de la cola** (mejora 8): `playNext`, `addToQueue`, quitar, mover y
   aleatorio en `KodaAudioHandler`. Sirven de red de seguridad antes de que
   otros agentes toquen el reproductor.
2. **Esquema de BD v2** en una sola migración:
   - `songs.liked_at INTEGER NULL` (Favoritos)
   - tabla `play_history(song_id, played_at)` (Historial)
   - tabla `search_history(query PRIMARY KEY, searched_at)` (Búsquedas)
   - tabla `settings(key PRIMARY KEY, value)` (Ajustes)
   - Test de migración v1 → v2.
3. **Ganchos en el reproductor**, sin lógica de negocio:
   - `Stream<Song> songStarted`: emite cuando empieza a sonar una canción.
   - `Future<List<Song>> Function()? onQueueEnded`: si está definido, se llama
     al terminar la cola y las canciones devueltas se añaden y siguen sonando.
   - `stopAfterCurrent` (bool): para al terminar la canción actual.
4. **Pestaña Inicio vacía** en `home_shell.dart`, con una lista de secciones
   registrables (`homeSectionsProvider`), y una **pantalla de Ajustes vacía**
   accesible desde Inicio.
5. `flutter analyze` + `flutter test` en verde → commit → esta es la base de
   todas las ramas.

## Oleada 1: 4 agentes en paralelo

| Agente | Funcionalidad | Archivos propios | Toca de lo compartido |
|---|---|---|---|
| A | Favoritos (1) | `features/favorites/` | corazón en `song_tile.dart` y `now_playing_screen.dart`; registra sección en Inicio |
| B | Historial (2) | `features/history/` | escucha `songStarted`; registra sección "Recientes" en Inicio |
| C | Importar playlist de YouTube (3) | `features/playlists/data/playlist_importer.dart` | botón en `playlists_screen.dart` |
| D | Temporizador de apagado (4) | `features/player/sleep_timer/` | botón en `now_playing_screen.dart`; usa `stopAfterCurrent` |

Choques esperados: solo A y D en `now_playing_screen.dart`, en zonas
distintas (corazón junto al título, temporizador en la barra superior), más
líneas añadidas en `bootstrap.dart` y `main.dart`. Son triviales de fusionar.

## Oleada 2: 4 agentes en paralelo (cuando se fusione la 1)

| Agente | Funcionalidad | Archivos propios | Toca de lo compartido |
|---|---|---|---|
| E | Radio automática (5) | `features/radio/` | implementa `onQueueEnded` con vídeos relacionados |
| F | Historial de búsqueda y sugerencias (6) | `features/search/data/search_history_dao.dart` | `search_screen.dart` |
| G | Ajustes (7) | `features/settings/` | rellena la pantalla vacía; "solo wifi" en `download_manager.dart` |
| H | Plan B si YouTube da 403 (9) | `core/audio/stream_url_provider.dart` | aviso de error en el reproductor |

Van en la oleada 2 porque E necesita el gancho estable y probado, G toca las
descargas y H cambia el manejo de errores del reproductor que usan B y D.

## Reglas para cada agente

1. Trabaja en `git worktree add ../PlayMusic-<feature> -b feat/<feature>`
   desde el commit base de la oleada.
2. Solo edita sus archivos propios y los huecos compartidos de su fila. Si
   necesita otro archivo compartido, para y lo pide al integrador.
3. Test primero cuando haya lógica (DAO, temporizador, importador, radio).
4. Antes de entregar: `flutter analyze` sin issues y `flutter test` en verde
   en su worktree.
5. Entrega: un commit (Conventional Commits) por funcionalidad y un resumen de
   archivos tocados y tests.
6. No cambia `_version` de la BD ni añade migraciones: si le falta algo del
   esquema, lo pide.
7. No prueba en el emulador: solo hay uno y lo usa el integrador.

## Integración

- Un integrador (Claude en esta PC) fusiona las ramas de cada oleada **en
  orden fijo** (A, B, C, D / E, F, G, H). Después de cada fusión pasa
  `flutter analyze` + `flutter test`, y al final de la oleada hace una prueba
  manual en el emulador.
- Si una rama choca, el integrador resuelve solo los choques triviales
  (imports, overrides). Si no, se la devuelve a su agente para que haga rebase.
- El usuario prueba al final de cada oleada, no después de cada agente.

## Estimación

| Fase | Agentes | Duración aproximada |
|---|---|---|
| Oleada 0 | 1 | 1 sesión |
| Oleada 1 | 4 en paralelo | 1 sesión + integración |
| Oleada 2 | 4 en paralelo | 1 sesión + integración |
