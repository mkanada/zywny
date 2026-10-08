package com.example.zywny

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    // B11: arquivos `.zywny` que o sistema entrega (clique no gerenciador de
    // arquivos, "Abrir com…"). O conteúdo é copiado para o cache e o Dart recebe
    // o caminho da cópia, que ele apaga depois de ler: o pacote dos hinos tem
    // MBs e não deve atravessar o canal em bytes.
    private var channel: MethodChannel? = null

    /** Entregas que chegaram antes de o Dart perguntar o que já havia. */
    private val waiting = mutableListOf<Map<String, Any?>>()
    private var dartListening = false

    /** Uma cópia por vez, fora da thread principal (a leitura pode demorar). */
    private val copier = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // cpal (AAudio) precisa da JavaVM + Context; ver ffi.rs.
        System.loadLibrary("zywny_audio")
        nativeInit(applicationContext)
        // Atividade recriada pelo sistema: o intent é o mesmo de antes e o
        // arquivo já foi tratado.
        if (savedInstanceState == null) takePackages(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    // O Dart se põe à escuta e pergunta o que chegou antes.
                    "initial" -> {
                        dartListening = true
                        result.success(ArrayList(waiting))
                        waiting.clear()
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takePackages(intent)
    }

    override fun onDestroy() {
        copier.shutdown()
        super.onDestroy()
    }

    private fun takePackages(intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return
        // Reaberto pelos recentes: o intent é o que abriu o app da primeira vez.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val uri = intent.data ?: return
        copier.execute {
            val delivery = copyToCache(uri)
            runOnUiThread { deliver(delivery) }
        }
    }

    private fun deliver(delivery: Map<String, Any?>) {
        if (dartListening) {
            channel?.invokeMethod("file", delivery)
        } else {
            waiting.add(delivery)
        }
    }

    private fun copyToCache(uri: Uri): Map<String, Any?> {
        val name = displayName(uri)
        var target: File? = null
        return try {
            val dir = File(cacheDir, "incoming").apply { mkdirs() }
            // Sobras de entregas que o Dart não chegou a ler (o app foi morto).
            val stale = System.currentTimeMillis() - 24 * 60 * 60 * 1000
            dir.listFiles()?.forEach { if (it.lastModified() < stale) it.delete() }
            val copy = File.createTempFile("pacote-", ".zywny", dir)
            target = copy
            val input = contentResolver.openInputStream(uri) ?: throw FileNotFoundException()
            input.use { source -> copy.outputStream().use { source.copyTo(it) } }
            mapOf("name" to name, "path" to copy.absolutePath, "temporary" to true)
        } catch (e: Exception) {
            target?.delete()
            mapOf("name" to name, "error" to explain(e))
        }
    }

    private fun explain(e: Exception): String {
        // Sem permissão, o Android às vezes lança FileNotFoundException com
        // "(Permission denied)" no texto, em vez de SecurityException.
        val denied = e is SecurityException ||
            (e is FileNotFoundException &&
                (e.message ?: "").let { it.contains("EACCES") || it.contains("Permission denied") })
        return when {
            denied ->
                "o Android não deixou o app ler o arquivo. Instale por dentro do app, em “Abrir arquivo…”"
            e is FileNotFoundException -> "o arquivo não está mais lá"
            else -> e.message ?: e.javaClass.simpleName
        }
    }

    private fun displayName(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val name = cursor.getString(0)
                        if (!name.isNullOrBlank()) return name
                    }
                }
        } catch (_: Exception) {
            // Sem nome do provedor: vale o fim do caminho.
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "arquivo"
    }

    private external fun nativeInit(context: Context)

    companion object {
        private const val CHANNEL = "zywny/incoming"
    }
}
