package com.sponify.sponify

import android.Manifest
import android.annotation.TargetApi
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

// audio_service necesita compartir el FlutterEngine con el servicio en
// segundo plano; por eso la actividad hereda de AudioServiceActivity.
class MainActivity : AudioServiceActivity() {
    // La copia de archivos va fuera del hilo principal; las respuestas al
    // canal, de vuelta en él.
    private val io: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXPORT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "exportAudio") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val displayName = call.argument<String>("displayName")
                val mimeType = call.argument<String>("mimeType") ?: "audio/*"
                if (path == null || displayName == null) {
                    result.error("bad_args", "Faltan path o displayName", null)
                    return@setMethodCallHandler
                }
                // Android 9 o anterior: hace falta WRITE_EXTERNAL_STORAGE. No
                // esperamos a la respuesta del diálogo: lo pedimos y devolvemos
                // error; si el usuario lo concede, el siguiente intento funciona.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && !hasLegacyWritePermission()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(
                            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            WRITE_PERMISSION_REQUEST,
                        )
                    }
                    result.error("permission_denied", "Sin permiso de almacenamiento", null)
                    return@setMethodCallHandler
                }
                io.execute {
                    try {
                        val location = exportAudio(File(path), displayName, mimeType)
                        mainHandler.post { result.success(location) }
                    } catch (e: FileNotFoundException) {
                        mainHandler.post { result.error("not_found", e.message, null) }
                    } catch (e: SecurityException) {
                        mainHandler.post { result.error("permission_denied", e.message, null) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("io_error", e.message, null) }
                    }
                }
            }
    }

    override fun onDestroy() {
        // Deja terminar la copia en curso, pero no acepta más.
        io.shutdown()
        super.onDestroy()
    }

    private fun hasLegacyWritePermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED

    /** Devuelve la ubicación legible para el usuario. */
    private fun exportAudio(source: File, displayName: String, mimeType: String): String {
        if (!source.isFile) throw FileNotFoundException(source.path)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            exportToMediaStore(source, displayName, mimeType)
        } else {
            exportToPublicDir(source, displayName)
        }
    }

    /**
     * Android 10+: MediaStore con almacenamiento acotado, sin permisos. Se
     * marca IS_PENDING mientras se copia para que otras apps no vean un
     * archivo a medias; si algo falla se borra la entrada.
     */
    @TargetApi(Build.VERSION_CODES.Q)
    private fun exportToMediaStore(source: File, displayName: String, mimeType: String): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_MUSIC}/$FOLDER")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("MediaStore no creó la entrada")
        try {
            val out = resolver.openOutputStream(uri)
                ?: throw IOException("No se pudo abrir el destino")
            out.use { output -> source.inputStream().use { input -> input.copyTo(output) } }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        // MediaStore puede renombrar si ya existe ("Nombre (1).m4a").
        return "Música/$FOLDER/$displayName"
    }

    /** Android 9 o anterior: copia directa a la carpeta pública de Música. */
    @Suppress("DEPRECATION")
    private fun exportToPublicDir(source: File, displayName: String): String {
        val musicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
        val dir = File(musicDir, FOLDER)
        if (!dir.isDirectory && !dir.mkdirs()) {
            throw IOException("No se pudo crear ${dir.path}")
        }
        val target = uniqueFile(dir, displayName)
        source.copyTo(target)
        // Para que aparezca en otros reproductores sin reiniciar.
        MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), null, null)
        return "Música/$FOLDER/${target.name}"
    }

    /** "Nombre.m4a", y si existe "Nombre (2).m4a", "Nombre (3).m4a"... */
    private fun uniqueFile(dir: File, name: String): File {
        var candidate = File(dir, name)
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var n = 2
        while (candidate.exists()) {
            candidate = File(dir, "$base ($n)$ext")
            n++
        }
        return candidate
    }

    private companion object {
        const val EXPORT_CHANNEL = "sponify/export"
        const val FOLDER = "Spoñify"
        const val WRITE_PERMISSION_REQUEST = 4201
    }
}
