# Fase 0 — Cimientos para el trabajo en paralelo

Locator: `odd/tasks/fase-0-cimientos.md` · Plan general: `docs/plan-agentes.md`

## Objetivo

Preparar una sola vez los puntos compartidos (BD, reproductor, Inicio,
Ajustes) para que las oleadas 1 y 2 solo añadan código en sus carpetas.

## Alcance autorizado

Rama `main`, un commit por tarea (el usuario pidió trabajar en main). Sin push
hasta terminar la fase y confirmarlo con el usuario.

## Tareas

- [x] T1 Tests de la cola de `KodaAudioHandler` (playQueue, playNext,
      addToQueue, removeFromQueue, moveInQueue, aleatorio). Ruta: inline.
      Se pensaron como tests de caracterización, pero 2 fallaron y
      destaparon un bug: `playNext`/`addToQueue` no refrescaban el
      `PlayerSnapshot`, así que la hoja de cola no mostraba la canción
      añadida. Arreglado. Commit `ed0594b`.
- [x] T2 Ganchos del reproductor: `songStarted`, `onQueueEnded`,
      `stopAfterCurrent` (+ `PlayerSnapshot.stopAfterCurrent`). RED → GREEN.
      Commit `620be0d`. De paso se arregló un test de descargas inestable en
      Windows (`997ae82`).
- [x] T3 Esquema de BD v2: `songs.liked_at`, `play_history`,
      `search_history`, `settings`, con test de migración v1→v2. RED → GREEN.
      Commit `5a7141a`.
- [x] T4 Pestaña Inicio (primera pestaña) con `homeSectionsProvider` y
      pantalla de Ajustes vacía. RED → GREEN. Commit: ver abajo.

## Criterios de aceptación

- `flutter analyze lib test` sin issues y `flutter test` en verde tras cada
  tarea.
- Las oleadas 1 y 2 pueden implementarse sin tocar `_version` ni la lógica
  interna del handler.

## Progreso y evidencias

- Tras cada tarea: `flutter analyze lib test` → No issues found.
- Final: `flutter test` → 58/58 en verde, dos corridas seguidas (antes 6
  corridas seguidas tras el arreglo del test inestable).

## Notas para las oleadas 1 y 2

- Inicio: cada funcionalidad expone su `HomeSection` y suma una línea a la
  lista de `homeSectionsProvider` (`lib/features/home/home_sections.dart`).
- `SongDao.upsert` actualiza con `Song.toMap()`, que no incluye `liked_at`:
  no borra el "me gusta". Favoritos debe leer `liked_at` en `Song.fromMap`
  sin añadirlo a `toMap` (o hacerlo con cuidado).
- Ganchos: Historial escucha `songStarted`; Radio asigna `onQueueEnded`;
  Temporizador usa `setStopAfterCurrent` y `pause()`.

## Siguiente paso

Oleada 1 (A Favoritos, B Historial, C Importar playlist, D Temporizador).
