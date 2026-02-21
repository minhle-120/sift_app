import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

final modelPlatformServiceProvider = Provider((ref) => ModelPlatformService());

/// A service that communicates with the native Android layer via [MethodChannel]
/// and [EventChannel] to manage the LiteRT LM model.
class ModelPlatformService {
  static const _commandChannel = MethodChannel('com.sift/command');
  static const _responseChannel = EventChannel('com.sift/response');
  static const _progressChannel = EventChannel('com.sift/progress');

  Stream<double>? _progressStream;
  Stream<Map<dynamic, dynamic>>? _responseStream;

  /// A stream of model import progress (0.0 to 1.0).
  Stream<double> get progressStream {
    _progressStream ??= _progressChannel
        .receiveBroadcastStream()
        .map((event) => (event as num).toDouble());
    return _progressStream!;
  }

  /// A stream of model responses and status events from the native layer.
  Stream<Map<dynamic, dynamic>> get responseStream {
    _responseStream ??= _responseChannel
        .receiveBroadcastStream()
        .map((event) => event as Map<dynamic, dynamic>);
    return _responseStream!;
  }

  /// Opens the native file picker to select a model file.
  /// Returns the absolute path of the selected model or null if cancelled.
  Future<String?> pickModel() async {
    try {
      final String? path = await _commandChannel.invokeMethod('pickModel');
      return path;
    } on PlatformException catch (e) {
      debugPrint("[Native Error] Failed to pick model: '${e.message}'.");
      return null;
    }
  }

  /// Initializes the LiteRT engine with the model at the given [path].
  /// [useGpu] specifies whether to enable GPU acceleration.
  /// Returns true if initialization was successful.
  Future<bool> initializeModel(String path, {bool useGpu = false}) async {
    try {
      final bool result = await _commandChannel.invokeMethod('initialize', {
        'path': path,
        'useGpu': useGpu,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("[Native Error] Failed to initialize model: '${e.message}'.");
      return false;
    }
  }

  /// Resets the current conversation state in the native engine.
  Future<void> resetConversation() async {
    try {
      await _commandChannel.invokeMethod('reset');
    } on PlatformException catch (e) {
      debugPrint("[Native Error] Failed to reset conversation: '${e.message}'.");
    }
  }

  /// Sends a [prompt] to the native engine to generate a response.
  /// 
  /// [requestId] helps route the response back to the correct caller (UI or API).
  /// [systemInstruction] can be used to set a persona for the model.
  Future<void> generateResponse(String prompt, {String? requestId, String? systemInstruction}) async {
    try {
      await _commandChannel.invokeMethod('generate', {
        'prompt': prompt,
        'requestId': requestId,
        'systemInstruction': systemInstruction,
      });
    } on PlatformException catch (e) {
      debugPrint("[Native Error] Failed to generate response: '${e.message}'.");
    }
  }
}
