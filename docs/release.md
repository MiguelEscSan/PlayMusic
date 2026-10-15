# Publicar una versión (APK Android)

El workflow `.github/workflows/release.yml` analiza, testea y compila el APK de Spoñify.

## Publicar una versión

```bash
git tag v1.0.1
git push origin v1.0.1
```

Un tag `v*` lanza el workflow: `flutter analyze`, `flutter test`, `flutter build apk --release`
con `--build-name` igual al tag sin la `v` (`1.0.1`) y `--build-number` igual al número de ejecución.
Al terminar crea (o actualiza) la GitHub Release del tag con `sponify-1.0.1.apk` adjunto.

## Ejecución manual

GitHub → **Actions** → **Release APK** → **Run workflow**. No crea Release: el APK queda como
artefacto de la ejecución, con nombre `sponify-<versión de pubspec>-dev.<sha>.apk`.

## Dónde descargar el APK

- Versiones con tag: **Releases** del repositorio (`github.com/MiguelEscSan/PlayMusic/releases`).
- Cualquier ejecución: pestaña **Actions** → la ejecución → sección **Artifacts** (caducan a los 90 días).

## Firma

Sin secretos configurados, el APK se firma con la **clave debug** (aviso en el log). Sirve para
instalar a mano, pero no para Play Store, y no se puede actualizar sobre un APK firmado con otra clave.

Para firmar con un keystore real, añade en **Settings → Secrets and variables → Actions**:

| Secreto | Valor |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | El `.jks` en base64 (`base64 -w0 upload-keystore.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña del keystore |
| `ANDROID_KEY_ALIAS` | Alias de la clave |
| `ANDROID_KEY_PASSWORD` | Contraseña de la clave |

El workflow genera `android/key.properties` y `build.gradle.kts` lo usa si existe. En local puedes
hacer lo mismo copiando `android/key.properties.example` (nunca subas `key.properties` ni el `.jks`).
