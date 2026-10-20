# Koda: contexto para otro agente

Documento de traspaso. Resume el estado del proyecto `PlayMusic` (app Koda), los retos técnicos que aparecieron y qué quedó pendiente. Todo lo marcado como "no verificado" necesita comprobación en un dispositivo.

## 1. Proyecto

- **App:** Koda, reproductor de audio híbrido (streaming de YouTube + canciones descargadas).
- **Stack:** Flutter/Dart, Riverpod, SQLite (`sqflite`), `just_audio` 0.10.6, `audio_service` 0.18.19, `youtube_explode_dart` 3.1.0, `dio` 5.11.1.
- **Arquitectura:** Clean Architecture por funcionalidades (`lib/features/<feature>/{domain,data,presentation}`), con `lib/core` para lo compartido.
- **Plataformas:** Android e iOS. Sin Xcode disponible en la máquina de trabajo, así que lo de iOS solo se valida con pruebas del usuario en el dispositivo.
- **Repositorio:** `github.com/MiguelEscSan/PlayMusic`, rama `main` (se ha trabajado directo en `main` a petición del usuario).
- **Carpetas sin trackear que no son nuestras:** `.atl/` y `scripts/`. No tocar ni commitear.

## 2. Qué se hizo en esta sesión

| Commit | Qué hace |
| --- | --- |
| `d3c379a` | Reanudar la última reproducción: al cambiar de pista, pausar o cada 5 s mientras suena, se guarda cola, índice y posición en la tabla `settings`. Al abrir, la canción se carga en pausa en ese punto, omitiendo las que ya no existen. |
| `b6e446b` | Detector de fin de pista por posición (watchdog), como respaldo al evento `completed`. Luego se cambió (ver §3). |
| `6f7a32f`, `1e0e51e` | Readout temporal de diagnóstico (`ps`, `playing`, `pos`, `dur`, `stored`) en la pantalla de reproducción, y su retirada. |
| `f05f9ac` | Intento de usar la duración del reproductor y corregir la guardada. Se revirtió. |
| `dbb21da` | Usa la duración guardada (`stored`) para la barra de progreso y el fin de pista. Quitó el corrector de duración. |
| `a6ccdfd`, `f4a0882` | README: stack, retos, problemas conocidos. Se quitó la sección de compilación para iOS a petición del usuario. |
| `a1edc15`, `d206bac` | Demo: MP4 y GIF generados desde un test de widgets con datos ficticios (ver §5). |

## 3. Retos técnicos

### 3.1 Reproducción por streaming y resolución de URLs
- `PlaybackSourceResolver` decide por canción si reproducir desde archivo local (`LocalFileSource`) o desde una URL de streaming (`RemoteStreamSource`).
- Las URLs de googlevideo caducan. Se cachean en memoria en `playback_source_resolver_impl.dart` leyendo el parámetro `expire` (con margen).
- En Android, googlevideo responde 403 a las peticiones de ExoPlayer para URLs que sí acepta desde `dart:io`. Por eso existe `HttpRangeAudioSource` (`http_range_audio_source.dart`), que descarga los rangos con `HttpClient`.

### 3.2 Descargas
- `DownloadManager` (`features/downloads/data/download_manager.dart`) descarga por fragmentos con `dio`. Concurrencia máxima de 2.
- `_downloadWithRetry` reintenta una vez si la URL devuelve 403 o 410, refrescando la URL.
- **Pendiente:** no hay backoff ante 429. Una descarga masiva de una playlist resuelve canciones seguidas sin pausa, que es el patrón que activa la detección de bots de YouTube.

### 3.3 Riesgo de bloqueo por IP
- Escuchar normalmente genera poca carga (una resolución cada 3-4 minutos y caché de URLs). El riesgo real está en descargas masivas.
- Un bloqueo suele ser temporal (horas a días), y es más probable en IPs de datacenter.
- Descargar de YouTube va contra sus Términos de Servicio. El README tiene un disclaimer al respecto.

### 3.4 Reanudación de la última reproducción
- Entidad `LastPlayback` (`core/domain/entities/last_playback.dart`), clave `playback.last` en `settings` como JSON (`songIds`, `index`, `positionMs`). Solo se guardan ids, porque las URLs caducan.
- `LastPlaybackRecorder` (`features/playback/data/last_playback_recorder.dart`) guarda en cada cambio de estado y cada 5 s mientras suena.
- `restoreLastPlayback` lee la última reproducción al arrancar y llama a `KodaAudioHandler.restoreQueue`, que carga en pausa sin reproducir.
- **Ojo:** `restoreQueue` resuelve la URL de la canción al arrancar, aunque no vaya a sonar. Sin conexión, la carga falla y muestra error.

### 3.5 Fin de pista en iOS (el problema más largo)
Síntoma: al terminar una canción no pasaba a la siguiente. Pasó tanto en streaming como con canciones descargadas, y también en primer plano.

Lo que se verificó en el código:
- En `just_audio` 0.10.6 (`lib/just_audio.dart`), `player.position` no es un valor fijo: se extrapola con el reloj local cuando está sonando (`updatePosition + (now - updateTime) × speed`, línea ~673).
- `positionStream` es único y compartido. Usa `createPositionStream` con `steps: 800`, y el período queda entre 16 ms y 200 ms (en canciones largas, 200 ms). Solo emite mientras suena.
- En iOS (`darwin/just_audio/Sources/just_audio/AudioPlayer.m`, `onComplete`), `completed` solo se dispara cuando se acaba **toda la lista**. Con una fuente por pista, eso equivale al final de la pista.
- `getDuration` (`AudioPlayer.m:382`) usa `CMTimeGetSeconds` sobre la duración de la fuente. Con un `StreamAudioSource` sin longitud conocida, puede no ser válida.
- El issue #316 de just_audio trata de `ConcatenatingAudioSource`, no de una fuente por pista. No aplica directamente. Para una cola concatenada, `positionDiscontinuityStream` avisa del cambio de pista.

Lo que se hizo:
- `b6e446b`: watchdog por posición que llama a `_endTrack` cuando la posición llega a 500 ms del final, con una guarda para no saltar dos veces.
- Se encontró que la duración guardada en la BD no siempre coincide con el audio real (ver §3.6). Se cambió el watchdog para usar la duración guardada (`dbb21da`).

**Estado al cierre:** el usuario reportó que el auto-avance quedó arreglado tras estos cambios. Confirmado en la conversación, sin prueba automatizada.

### 3.6 Duración del stream distinta a la guardada
- Caso concreto: el video `yYVCf-y2YmE` ("Playa Del Inglés - Quevedo, Myke Towers"). Según su página pública, dura 255-256 s (4:15-4:16). La BD guarda `stored=256000`, correcto.
- El reproductor reportó `dur=510419` (8:30), casi el doble. En la app, la canción seguía sonando después de los 4:16.
- Hipótesis no verificada: la longitud o el `Content-Range` que se le pasa al proxy de `just_audio` en `HttpRangeAudioSource` hacen que AVPlayer calcule mal la duración (factor ~2).
- Decisión tomada: `stored` es la referencia para la barra y el fin de pista. Se quitó el corrector que sobrescribía la BD con la duración del reproductor.
- **Pendiente:** investigar por qué el stream reporta el doble. Revisar cómo se calcula `sourceLength` y `contentLength` en `HttpRangeAudioSource.request` (líneas ~49-55).

### 3.7 Batería y rendimiento
- Un timer de una sola vez por pista más chequeos de posición en la última ventana cuesta casi nada, y no genera tráfico nativo.
- Un stream de posición de 50 ms sí aumentaría los eventos por la capa nativa, así que no se recomendó.
- Android: no requiere cambios para esto. Con el servicio de primer plano de audio activo, Doze debería respetar la reproducción. Pendiente de probar con la pantalla apagada.

## 4. README

- Secciones actuales: descripción, stack, arquitectura, retos resueltos, problemas conocidos, demo, cómo ejecutar.
- Se quitó la sección de compilación de iOS. El usuario no quiere publicar instrucciones de compilación por motivos legales.
- El disclaimer legal se mantiene.
- Pendiente: decidir si el README menciona el recorrido completo o solo el reproductor (ver §5).

## 5. Demo (recorrido en video)

- **Test:** `test/demo/demo_screenshots_test.dart`. Renderiza `HomeShell` con datos ficticios (canciones inventadas, playlists inventadas, búsquedas de prueba) y captura 60 frames en `build/demo_frames/` (sin versionar).
- **Pantallas incluidas:** Inicio, Buscar, Playlists, Descargas y el reproductor (abierto desde el mini-player).
- **No incluidas:** Ajustes (se abre desde el icono de engranaje de Inicio) y el detalle de playlist. Si el objetivo es "toda la app", faltan.
- **Codificación:** ffmpeg de `imageio-ffmpeg` (Python 3.10, instalado con pip). MP4 con libx264 a 10 fps, y GIF generado a partir del MP4.
- **Archivos:** `docs/demo/demo.mp4` (~150 KB) y `docs/demo/demo.gif` (~350 KB). El GIF pesa más que el MP4 con el mismo contenido.
- **Dependencias del entorno:** rutas fijas de Windows para las fuentes (`C:\Windows\Fonts\segoeui.ttf` y la fuente de iconos del SDK de Flutter). Si no existen, el test se salta.
- **Detalle visual:** en el frame de Playlists, el botón "Nueva" tiene un borde negro de foco. Es menor, pero conviene revisarlo.
- **Regla del usuario:** la demo debe usar solo material original (títulos inventados, carátulas generadas por la app). No usar carátulas ni nombres de artistas reales.

## 6. Portfolio

El usuario va a cargar Koda en su portfolio (formulario "Nuevo proyecto", bilingüe). Contenido acordado:

- **Slug:** `koda`
- **Categoría:** Producto
- **Año:** 2026. **Estado:** Publicado
- **Tags:** Flutter, Dart, Riverpod, Clean Architecture, just_audio, SQLite
- **URL código:** `https://github.com/MiguelEscSan/PlayMusic`
- **URL live:** vacía (no hay versión publicada)
- **Cliente:** Proyecto personal
- **Rol:** Mobile Developer (EN) / Desarrollador móvil (ES)
- **Título:** Koda

Descripciones (ES y EN) redactadas. Ver el historial de la conversación si hace falta el texto completo. Pendiente: decidir si el relleno se hace en el navegador o lo copia el usuario.

## 7. Pendientes

1. Confirmar en dispositivo el auto-avance y la barra de progreso con `stored` (usuario).
2. Investigar por qué el stream de algunos videos reporta el doble de duración (§3.6).
3. Agregar backoff ante 429 en `DownloadManager` (§3.2).
4. Incluir Ajustes y el detalle de playlist en el recorrido de la demo, si se quiere cubrir toda la app (§5).
5. Revisar el borde de foco del botón "Nueva" en la captura de Playlists (§5).
6. Decidir el relleno del portfolio: navegador o copia manual (§6).
7. Probar la reproducción con la pantalla apagada en Android, para validar Doze (§3.7).

## 8. Cómo verificar

```bash
flutter analyze
flutter test test/audio_queue_test.dart test/last_playback_test.dart test/di test/domain
flutter test test/demo/demo_screenshots_test.dart
```

El tercer comando regenera los frames de `build/demo_frames/`. Después, ffmpeg los codifica a `docs/demo/demo.mp4`.
