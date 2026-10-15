# Fase 0 — Cimientos para el trabajo en paralelo

Locator: `odd/tasks/fase-0-cimientos.md` · Plan general: `docs/plan-agentes.md`

## Objetivo

Preparar una sola vez los puntos compartidos (BD, reproductor, Inicio,
Ajustes) para que las oleadas 1 y 2 solo añadan código en sus carpetas.

## Alcance autorizado

Rama `main`, un commit por tarea (el usuario pidió trabajar en main). Sin push
hasta terminar la fase y confirmarlo con el usuario.

## Tareas

- [ ] T1 Tests de la cola de `SponifyAudioHandler` (playQueue, playNext,
      addToQueue, removeFromQueue, moveInQueue, aleatorio). Ruta: inline.
      Son tests de caracterización: el comportamiento ya existe, así que
      pasan desde el principio (sin RED).
- [ ] T2 Ganchos del reproductor: `songStarted`, `onQueueEnded`,
      `stopAfterCurrent`. Test primero.
- [ ] T3 Esquema de BD v2: `songs.liked_at`, `play_history`,
      `search_history`, `settings`, con test de migración v1→v2. Test primero.
- [ ] T4 Pestaña Inicio con `homeSectionsProvider` (secciones registrables)
      y pantalla de Ajustes vacía. Widget test.

## Criterios de aceptación

- `flutter analyze lib test` sin issues y `flutter test` en verde tras cada
  tarea.
- Las oleadas 1 y 2 pueden implementarse sin tocar `_version` ni la lógica
  interna del handler.

## Progreso y evidencias

(se rellena tarea a tarea)
