# Koda

Reproductor de música para Android, híbrido: escucha en streaming desde YouTube y descarga
las canciones para oírlas sin conexión. Hecho con Flutter (antes se llamaba Spoñify).

## Funciones

- **Buscar** canciones en YouTube, con sugerencias mientras escribes e historial de búsquedas.
  La búsqueda se lanza al pulsar Enter.
- **Reproductor** con mini-reproductor, pantalla completa, cola editable y controles en la
  notificación y la pantalla de bloqueo. Desliza a izquierda o derecha sobre la carátula
  (o el mini-reproductor) para cambiar de canción.
- **Descargas** para escuchar offline. Opción de descargar solo con wifi y de ver o borrar el
  espacio ocupado.
- **Playlists** propias, con portada elegida desde la galería, e **importación de playlists de
  YouTube**.
- **Me encanta**: las canciones con like se guardan también en una playlist "Me encanta".
- **Inicio** con lo escuchado recientemente, lo más escuchado, favoritos y playlists.
- **Radio automática**: al acabar la cola sigue con canciones parecidas.
- **Temporizador de apagado**.
- **Letras** sincronizadas (desde [LRCLIB](https://lrclib.net)).
- **Exportar** una canción descargada a la carpeta `Música/Koda` del móvil.
- **Ajustes**: radio automática, descargas solo con wifi, espacio ocupado, borrar descargas y
  borrar historial.

## Requisitos

- Windows con [Flutter](https://docs.flutter.dev/get-started/install/windows) 3.47.7
  (la misma versión que usa el workflow de release).
- Android Studio con el SDK de Android y un emulador (o un móvil Android con depuración USB).
- Java 17 (viene con Android Studio).

En este PC Flutter está en `C:\dev\flutter` y no está en el `PATH`. Puedes añadirlo para la
sesión de PowerShell actual:

```powershell
$env:Path = "C:\dev\flutter\bin;$env:Path"
flutter --version
```

O llamarlo con la ruta completa: `C:\dev\flutter\bin\flutter.bat`.

## Compilar y ejecutar en local

Desde la carpeta del proyecto (`C:\Projects\PlayMusic`):

```powershell
flutter pub get          # instala dependencias
flutter devices          # comprueba que el emulador o el móvil aparece
flutter run              # compila e instala la app en modo debug
```

Con el emulador de Android Studio abierto, `flutter run` lo usa directamente. Si hay varios
dispositivos, elige uno con `flutter run -d <id>`.

Análisis y tests:

```powershell
flutter analyze lib test
flutter test
```

## Generar la APK de release

```powershell
flutter build apk --release
```

La APK queda en `build\app\outputs\flutter-apk\app-release.apk`. Para instalarla en el
emulador o en un móvil conectado:

```powershell
flutter install --release
```

Sin `android\key.properties` la APK se firma con la clave debug: sirve para instalarla a mano,
pero no para Play Store. Para firmar con un keystore real, copia
`android\key.properties.example` a `android\key.properties` y rellénalo (nunca subas ese
archivo ni el `.jks`).

### APK desde GitHub

El workflow `.github/workflows/release.yml` compila la APK en GitHub Actions al subir un tag
`v*` (por ejemplo `v1.0.1`) y la publica en
[Releases](https://github.com/MiguelEscSan/PlayMusic/releases) como `koda-1.0.1.apk`. También
se puede lanzar a mano desde la pestaña Actions. Todos los detalles, incluidos los secretos de
firma, están en [docs/release.md](docs/release.md).

## Estructura del proyecto

```
lib/
├── main.dart · app.dart · bootstrap.dart
├── core/        audio, base de datos (sqflite), modelos, ajustes, rutas y utilidades
├── features/    una carpeta por función: home, search, player, playlists, downloads,
│                favorites, history, lyrics, radio, settings
└── shared/      acciones y widgets comunes, exportación de canciones
test/            tests de DAOs, servicios y pantallas
```

Stack: Riverpod, sqflite, just_audio + audio_service, dio y youtube_explode_dart. Las
decisiones de diseño, el esquema de la base de datos y cómo funciona el reproductor híbrido
están en [ARCHITECTURE.md](ARCHITECTURE.md).

## Nota sobre el nombre

La app se muestra como **Koda**, pero el `applicationId` (`com.sponify.sponify`), el paquete
Dart (`sponify`) y el nombre de la base de datos siguen siendo los de Spoñify, para que las
instalaciones existentes se actualicen sin perder datos.
