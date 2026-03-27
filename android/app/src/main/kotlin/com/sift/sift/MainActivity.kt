package com.sift.sift

import java.io.File
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.app.Activity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.NonNull
import android.util.Log
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterFragmentActivity() {
    private val COMMAND_CHANNEL = "com.sift/command"
    private val RESPONSE_CHANNEL = "com.sift/response"
    private val PROGRESS_CHANNEL = "com.sift/progress"

    private lateinit var modelManager: ModelManager
    private lateinit var embeddingManager: EmbeddingManager
    private var responseSink: EventChannel.EventSink? = null
    private var progressSink: EventChannel.EventSink? = null

    private lateinit var filePickerLauncher: ActivityResultLauncher<Intent>
    private var pendingImportResult: MethodChannel.Result? = null

    override fun onCreate(saved: Bundle?) {
        super.onCreate(saved)
        modelManager = ModelManager(this)
        embeddingManager = EmbeddingManager(this)
        filePickerLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == Activity.RESULT_OK) {
                result.data?.data?.let { uri ->
                    importModelFromUri(uri)
                } ?: run {
                    pendingImportResult?.error("PICK_FAILED", "No URI returned", null)
                    pendingImportResult = null
                }
            } else {
                pendingImportResult?.error("PICK_CANCELLED", "User cancelled picking", null)
                pendingImportResult = null
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        modelManager.close()
        embeddingManager.close()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMMAND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickModel" -> {
                    pendingImportResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    filePickerLauncher.launch(intent)
                }
                "initialize" -> {
                    val path = call.argument<String>("path")
                    val useGpu = call.argument<Boolean>("useGpu") ?: false
                    if (path != null) {
                        lifecycleScope.launch {
                            try {
                                modelManager.initialize(path, useGpu)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("INIT_FAILED", e.message, null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is null", null)
                    }
                }
                "reset" -> {
                    modelManager.resetConversation()
                    result.success(null)
                }
                "cancel" -> {
                    modelManager.cancelGeneration()
                    result.success(null)
                }
                "generate" -> {
                    val prompt = call.argument<String>("prompt")
                    val requestId = call.argument<String>("requestId")
                    val systemInstruction = call.argument<String>("systemInstruction")
                    if (prompt != null) {
                        modelManager.generateResponse(prompt, responseSink, requestId, systemInstruction)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Prompt is null", null)
                    }
                }
                "initializeEmbedding" -> {
                    val path = call.argument<String>("path")
                    val tokenizerPath = call.argument<String>("tokenizerPath")
                    val useGpu = call.argument<Boolean>("useGpu") ?: false
                    if (path != null) {
                        lifecycleScope.launch {
                            try {
                                embeddingManager.initialize(path, tokenizerPath, useGpu)
                                result.success(true)
                            } catch (e: Exception) {
                                Log.e("MainActivity", "Embedding init failed: ${e.message}", e)
                                result.error("EMBED_INIT_FAILED", "${e.javaClass.simpleName}: ${e.message}", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is null", null)
                    }
                }
                "getEmbeddings" -> {
                    val input = call.argument<Any>("input")
                    lifecycleScope.launch(Dispatchers.Default) {
                        try {
                            when (input) {
                                is String -> {
                                    val embeddings = embeddingManager.getEmbeddings(input)
                                    withContext(Dispatchers.Main) {
                                        result.success(embeddings)
                                    }
                                }
                                is List<*> -> {
                                    val texts = input.filterIsInstance<String>()
                                    val embeddings = embeddingManager.getBatchEmbeddings(texts)
                                    withContext(Dispatchers.Main) {
                                        result.success(embeddings)
                                    }
                                }
                                else -> {
                                    withContext(Dispatchers.Main) {
                                        result.error("INVALID_ARGUMENT", "Input must be String or List<String>", null)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("EMBED_FAILED", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RESPONSE_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    responseSink = events
                }
                override fun onCancel(arguments: Any?) {
                    responseSink = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }
                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            }
        )
    }

    private fun importModelFromUri(uri: Uri) {
        val result = pendingImportResult
        pendingImportResult = null

        lifecycleScope.launch {
            try {
                val path = modelManager.importFromUri(uri, progressSink)
                result?.success(path)
            } catch (e: Exception) {
                result?.error("IMPORT_FAILED", e.message, null)
            }
        }
    }
}
