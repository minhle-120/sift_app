import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service that handles communication with the native Android embedding layer.
/// Uses MediaPipe TextEmbedder via MethodChannel.
class EmbeddingPlatformService {
  final MethodChannel _channel = const MethodChannel('com.sift/command');

  /// Initializes the embedding model at the given [path].
  /// 
  /// @param path Absolute path to the .tflite embedding model.
  /// @param useGpu Whether to use GPU acceleration.
  /// @returns true if initialization was successful.
  Future<bool> initializeEmbeddingModel(String path, {String? tokenizerPath, bool useGpu = false}) async {
    try {
      final bool result = await _channel.invokeMethod('initializeEmbedding', {
        'path': path,
        'tokenizerPath': tokenizerPath,
        'useGpu': useGpu,
      });
      debugPrint("[Native] Embedding model initialized from $path (GPU: $useGpu)");
      return result;
    } on PlatformException catch (e) {
      debugPrint("[Native Error] Failed to initialize embedding model: '${e.message}'.");
      return false;
    }
  }

  /// Generates embeddings for the given [input].
  /// 
  /// @param input Can be a single String or a List of Strings.
  /// @returns List of double if input is a String, or List of List of double if input is List of Strings.
  Future<dynamic> getEmbeddings(dynamic input) async {
    try {
      final dynamic result = await _channel.invokeMethod('getEmbeddings', {'input': input});
      return result;
    } on PlatformException catch (e) {
      debugPrint("[Native Error] Failed to generate embeddings: '${e.message}'.");
      rethrow;
    }
  }
}
