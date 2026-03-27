package com.sift.sift

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.concurrent.CancellationException
import io.flutter.plugin.common.EventChannel

private const val TAG = "ModelManager"
private const val BUFFER_SIZE = 8192
private const val PROGRESS_REPORT_INTERVAL_MS = 100L

/**
 * Manages the lifecycle and operations of the LiteRT LM engine and conversation instances.
 * Handles model import from URIs and orchestrates inference requests.
 */
class ModelManager(private val context: Context) {
    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var currentSystemInstruction: String? = null

    /**
     * Imports a model file from a [Uri] to the internal "__imports" directory.
     * Reports progress back to the Flutter side via [progressSink].
     * 
     * @return The absolute path to the imported model file.
     */
    suspend fun importFromUri(uri: Uri, progressSink: EventChannel.EventSink?): String = withContext(Dispatchers.IO) {
        val contentResolver = context.contentResolver
        
        // Get filename and size
        var fileName = "imported_model.task"
        var fileSize = 0L
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex != -1) fileName = cursor.getString(nameIndex)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex != -1) fileSize = cursor.getLong(sizeIndex)
            }
        }

        // Create imports dir
        val importsDir = File(context.getExternalFilesDir(null), "__imports")
        if (!importsDir.exists()) importsDir.mkdirs()
        
        val outputFile = File(importsDir, fileName)
        val outputStream = FileOutputStream(outputFile)
        val inputStream: InputStream? = contentResolver.openInputStream(uri)

        if (inputStream == null) {
            throw Exception("Could not open input stream")
        }

        val buffer = ByteArray(BUFFER_SIZE)
        var bytesRead: Int
        var totalBytesRead = 0L
        var lastProgressReport = 0L

        inputStream.use { input ->
            outputStream.use { output ->
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    totalBytesRead += bytesRead
                    
                    val now = System.currentTimeMillis()
                    if (now - lastProgressReport > PROGRESS_REPORT_INTERVAL_MS) {
                        lastProgressReport = now
                        val progress = if (fileSize > 0) totalBytesRead.toDouble() / fileSize else 0.0
                        withContext(Dispatchers.Main) {
                            progressSink?.success(progress)
                        }
                    }
                }
            }
        }

        withContext(Dispatchers.Main) {
            progressSink?.success(1.0)
        }
        outputFile.absolutePath
    }

    /**
     * Initializes the LiteRT LM engine with the model at the specified [path].
     * Closes any existing engine or conversation sessions before re-initializing.
     * 
     * @param path Absolute path to the .task model file.
     * @param useGpu Whether to use GPU acceleration.
     * @throws Exception If model file is missing or initialization fails.
     */
    suspend fun initialize(path: String, useGpu: Boolean = false) = withContext(Dispatchers.IO) {
        Log.i(TAG, "Initializing engine (GPU: $useGpu) with model at: $path")
        
        // Cleanup existing
        try {
            conversation?.close()
            engine?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup: ${e.message}")
        } finally {
            conversation = null
            engine = null
        }
        
        currentSystemInstruction = null

        val modelFile = File(path)
        if (!modelFile.exists()) {
            throw Exception("Model file does not exist at path: $path")
        }

        try {
            val config = EngineConfig(
                modelPath = path,
                backend = if (useGpu) Backend.GPU else Backend.CPU,
                visionBackend = null,
                audioBackend = null,
                maxNumTokens = 4096,
                cacheDir = null
            )
            val newEngine = Engine(config)
            newEngine.initialize()
            
            val systemContents: Contents? = currentSystemInstruction?.let { 
                Contents.of(listOf(Content.Text(it))) 
            }
            
            val newConversation = newEngine.createConversation(
                ConversationConfig(
                    systemInstruction = systemContents,
                    samplerConfig = SamplerConfig(
                        topK = 64,
                        topP = 0.95,
                        temperature = 1.0
                    )
                )
            )
            
            engine = newEngine
            conversation = newConversation
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize engine: ${e.message}", e)
            throw e
        }
    }

    fun resetConversation() {
        val currentEngine = engine ?: return
        
        conversation?.close()
        
        val systemContents: Contents? = currentSystemInstruction?.let { 
            Contents.of(listOf(Content.Text(it))) 
        }
        
    conversation = currentEngine.createConversation(
            ConversationConfig(
                systemInstruction = systemContents,
                samplerConfig = SamplerConfig(
                    topK = 64,
                    topP = 0.95,
                    temperature = 1.0
                )
            )
        )
    }

    /**
     * Cancels any in-progress generation by resetting the conversation.
     * This interrupts the native inference and silently discards any pending tokens.
     */
    fun cancelGeneration() {
        Log.d(TAG, "Cancelling active generation via cancelProcess()")
        conversation?.cancelProcess()
    }

    private fun updateSystemInstruction(newInstruction: String?) {
        if (newInstruction == currentSystemInstruction) return
        
        currentSystemInstruction = newInstruction
        resetConversation()
    }

    /**
     * Generates a response for the given [prompt].
     * Can optionally update the [systemInstruction] before sending the message.
     * 
     * @param sink The sink to send streamed responses back to Flutter.
     * @param requestId Optional ID to track which client is requesting the response.
     */
    fun generateResponse(prompt: String, sink: EventChannel.EventSink?, requestId: String? = null, systemInstruction: String? = null) {
        Log.d(TAG, "Generating response for requestId: $requestId")
        updateSystemInstruction(systemInstruction)
        
        val conv = conversation
        if (conv == null) {
            sink?.error("NOT_INITIALIZED", "Model not initialized", null)
            return
        }

        val contents = Contents.of(listOf(Content.Text(prompt)))
        
        conv.sendMessageAsync(contents, object : MessageCallback {
            private val handler = Handler(Looper.getMainLooper())

            override fun onMessage(message: Message) {
                handler.post {
                    val data = mapOf(
                        "type" to "partial",
                        "text" to message.toString(),
                        "done" to false,
                        "requestId" to requestId
                    )
                    sink?.success(data)
                }
            }

            override fun onDone() {
                handler.post {
                    val data = mapOf(
                        "type" to "done",
                        "text" to "",
                        "done" to true,
                        "requestId" to requestId
                    )
                    sink?.success(data)
                }
            }

            override fun onError(throwable: Throwable) {
                handler.post {
                    if (throwable is CancellationException) {
                        Log.i(TAG, "Native inference was cancelled.")
                        val data = mapOf(
                            "type" to "done",
                            "text" to "",
                            "done" to true,
                            "requestId" to requestId
                        )
                        sink?.success(data)
                    } else {
                        Log.e(TAG, "Inference error", throwable)
                        val data = mapOf(
                            "type" to "error",
                            "error" to (throwable.message ?: "Unknown native error"),
                            "requestId" to requestId
                        )
                        sink?.success(data)
                    }
                }
            }
        })
    }

    /**
     * Closes and releases all native resources (engine and conversation).
     */
    fun close() {
        Log.i(TAG, "Closing ModelManager and releasing resources")
        try {
            conversation?.close()
            engine?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error during close: ${e.message}")
        } finally {
            conversation = null
            engine = null
        }
    }
}
