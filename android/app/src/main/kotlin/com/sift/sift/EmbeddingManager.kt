package com.sift.sift

import android.content.Context
import android.util.Log

import com.google.ai.edge.localagents.rag.models.EmbedData
import com.google.ai.edge.localagents.rag.models.EmbeddingRequest
import com.google.ai.edge.localagents.rag.models.GemmaEmbeddingModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.withContext
import java.io.File

private const val TAG = "EmbeddingManager"

/**
 * Manages the lifecycle and operations of the MediaPipe TextEmbedder.
 * Handles text embedding generation for single and batch inputs.
 */
class EmbeddingManager(private val context: Context) {
    private var gemmaEmbedder: GemmaEmbeddingModel? = null

    /**
     * Initializes the GemmaEmbeddingModel with the model and tokenizer at the specified paths.
     * 
     * @param modelPath Absolute path to the .tflite embedding model file.
     * @param tokenizerPath Optional path to the tokenizer. If null, tries to find sentencepiece.model next to the model.
     * @param useGpu Whether to use GPU acceleration.
     * @throws Exception If initialization fails or files are missing.
     */
    suspend fun initialize(modelPath: String, tokenizerPath: String? = null, useGpu: Boolean = false) = withContext(Dispatchers.IO) {
        Log.i(TAG, "Initializing GemmaEmbeddingModel (GPU: $useGpu)")
        
        close() // Ensure any existing embedder is closed

        val modelFile = File(modelPath)
        if (!modelFile.exists()) throw Exception("Model file missing: $modelPath")

        // Auto-detect tokenizer if not provided
        val finalTokenizerPath = tokenizerPath ?: modelFile.parent?.let { parent ->
            File(parent, "sentencepiece.model").let { if (it.exists()) it.absolutePath else null }
        } ?: modelFile.parent?.let { parent ->
            File(parent, "tokenizer.model").let { if (it.exists()) it.absolutePath else null }
        }

        if (finalTokenizerPath == null || !File(finalTokenizerPath).exists()) {
            throw Exception("Tokenizer file missing. Please provide it explicitly or place sentencepiece.model next to the model.")
        }

        Log.i(TAG, "Model: $modelPath")
        Log.i(TAG, "Tokenizer: $finalTokenizerPath")

        try {
            gemmaEmbedder = GemmaEmbeddingModel(modelPath, finalTokenizerPath, useGpu)
            Log.i(TAG, "GemmaEmbeddingModel initialized successfully")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize GemmaEmbeddingModel: ${e.message}", e)
            throw Exception("Gemma Error: ${e.message}")
        }
    }

    /**
     * Generates an embedding vector for the given [text].
     */
    suspend fun getEmbeddings(text: String): List<Float> {
        val embedder = gemmaEmbedder ?: throw Exception("GemmaEmbedder not initialized")
        
        return try {
            val embedData = EmbedData.create(text, EmbedData.TaskType.RETRIEVAL_QUERY)
            val request = EmbeddingRequest.create(listOf(embedData))
            val result = embedder.getEmbeddings(request).await()
            result.toList()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate embeddings: ${e.message}", e)
            throw e
        }
    }

    /**
     * Generates embedding vectors for a batch of [texts].
     */
    suspend fun getBatchEmbeddings(texts: List<String>): List<List<Float>> {
        val embedder = gemmaEmbedder ?: throw Exception("GemmaEmbedder not initialized")
        
        return try {
            val embedDataList = texts.map { EmbedData.create(it, EmbedData.TaskType.RETRIEVAL_QUERY) }
            val request = EmbeddingRequest.create(embedDataList)
            val result = embedder.getBatchEmbeddings(request).await()
            result.map { it.toList() }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate batch embeddings: ${e.message}", e)
            throw e
        }
    }

    /**
     * Closes and releases the MediaPipe TextEmbedder resources.
     */
    fun close() {
        Log.i(TAG, "Closing EmbeddingManager")
        // GemmaEmbeddingModel doesn't have an explicit close in the preview SDK usually, 
        // but we'll null it out. If it implements AutoCloseable, we'll try to close it.
        try {
            (gemmaEmbedder as? AutoCloseable)?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error during close: ${e.message}")
        } finally {
            gemmaEmbedder = null
        }
    }
}
