package com.example.app_casamento

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CANAL_ARQUIVOS = "br.com.appcasamento/arquivos"
        private const val CODIGO_PERMISSAO_DOWNLOADS = 4101
    }

    private data class SolicitaçãoDownload(
        val nomeArquivo: String,
        val mimeType: String,
        val bytes: ByteArray
    )

    private var downloadPendente: SolicitaçãoDownload? = null
    private var resultadoDownloadPendente: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CANAL_ARQUIVOS
        ).setMethodCallHandler { chamada, resultado ->
            if (chamada.method != "salvarEmDownloads") {
                resultado.notImplemented()
                return@setMethodCallHandler
            }

            val nomeArquivo = chamada.argument<String>("nomeArquivo")
            val mimeType = chamada.argument<String>("mimeType")
            val bytes = chamada.argument<ByteArray>("bytes")

            if (nomeArquivo.isNullOrBlank() || mimeType.isNullOrBlank() || bytes == null) {
                resultado.error(
                    "ARGUMENTOS_INVALIDOS",
                    "Nome, tipo e conteúdo do arquivo são obrigatórios.",
                    null
                )
                return@setMethodCallHandler
            }

            val solicitacao = SolicitaçãoDownload(nomeArquivo, mimeType, bytes)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                    PackageManager.PERMISSION_GRANTED
            ) {
                if (resultadoDownloadPendente != null) {
                    resultado.error(
                        "DOWNLOAD_EM_ANDAMENTO",
                        "Já existe um pedido de permissão para salvar um arquivo.",
                        null
                    )
                    return@setMethodCallHandler
                }

                downloadPendente = solicitacao
                resultadoDownloadPendente = resultado
                requestPermissions(
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    CODIGO_PERMISSAO_DOWNLOADS
                )
                return@setMethodCallHandler
            }

            executarSalvamento(solicitacao, resultado)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CODIGO_PERMISSAO_DOWNLOADS) return

        val solicitacao = downloadPendente
        val resultado = resultadoDownloadPendente
        downloadPendente = null
        resultadoDownloadPendente = null

        if (solicitacao == null || resultado == null) return

        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            executarSalvamento(solicitacao, resultado)
        } else {
            resultado.error(
                "PERMISSAO_DOWNLOADS_NEGADA",
                "Permita o acesso à pasta Downloads para salvar o relatório.",
                null
            )
        }
    }

    private fun executarSalvamento(
        solicitacao: SolicitaçãoDownload,
        resultado: MethodChannel.Result
    ) {
        Thread {
            try {
                val localSalvo = salvarEmDownloads(
                    nomeArquivo = solicitacao.nomeArquivo,
                    mimeType = solicitacao.mimeType,
                    bytes = solicitacao.bytes
                )

                runOnUiThread {
                    resultado.success(
                        mapOf(
                            "nomeArquivo" to solicitacao.nomeArquivo,
                            "local" to localSalvo
                        )
                    )
                }
            } catch (erro: Exception) {
                runOnUiThread {
                    resultado.error(
                        "ERRO_AO_SALVAR_DOWNLOADS",
                        erro.message ?: "Não foi possível salvar o arquivo em Downloads.",
                        null
                    )
                }
            }
        }.start()
    }

    private fun salvarEmDownloads(
        nomeArquivo: String,
        mimeType: String,
        bytes: ByteArray
    ): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            salvarComMediaStore(nomeArquivo, mimeType, bytes)
        } else {
            salvarEmAndroidAntigo(nomeArquivo, bytes)
        }
    }

    private fun salvarComMediaStore(
        nomeArquivo: String,
        mimeType: String,
        bytes: ByteArray
    ): String {
        val valores = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, nomeArquivo)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val colecao = MediaStore.Downloads.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY
        )

        val uri = contentResolver.insert(colecao, valores)
            ?: throw IllegalStateException(
                "O Android não permitiu criar o arquivo na pasta Downloads."
            )

        try {
            contentResolver.openOutputStream(uri, "w")?.use { saida ->
                saida.write(bytes)
                saida.flush()
            } ?: throw IllegalStateException(
                "Não foi possível abrir o arquivo para gravação."
            )

            valores.clear()
            valores.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, valores, null, null)

            return "${Environment.DIRECTORY_DOWNLOADS}/$nomeArquivo"
        } catch (erro: Exception) {
            contentResolver.delete(uri, null, null)
            throw erro
        }
    }

    @Suppress("DEPRECATION")
    private fun salvarEmAndroidAntigo(
        nomeArquivo: String,
        bytes: ByteArray
    ): String {
        val pastaDownloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )

        if (!pastaDownloads.exists() && !pastaDownloads.mkdirs()) {
            throw IllegalStateException(
                "Não foi possível acessar a pasta Downloads."
            )
        }

        val arquivo = File(pastaDownloads, nomeArquivo)

        FileOutputStream(arquivo).use { saida ->
            saida.write(bytes)
            saida.flush()
        }

        return arquivo.absolutePath
    }
}
