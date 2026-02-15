import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/models/ai_models.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';
import '../../services/ai/i_ai_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OpenAiService implements IAiService {
  final Dio _dio = Dio();
  final Ref _ref;

  OpenAiService(this._ref);

  @override
  Future<ChatMessage> chat(List<ChatMessage> messages, {List<ToolDefinition>? tools, String? toolChoice}) async {
    final settings = _ref.read(settingsProvider);
    final baseUrl = settings.llamaServerUrl;
    final model = settings.chatModel;

    final response = await _dio.post(
      '$baseUrl/v1/chat/completions',
      data: {
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        if (tools != null && tools.isNotEmpty) 'tools': tools.map((t) => t.toJson()).toList(),
        if (tools != null && tools.isNotEmpty) 'tool_choice': toolChoice ?? 'auto',
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200) {
      final choice = response.data['choices'][0]['message'];
      final roleStr = choice['role'];
      final content = choice['content'] ?? '';
      
      ChatRole role;
      switch (roleStr) {
        case 'assistant':
          role = ChatRole.assistant;
          break;
        case 'user':
          role = ChatRole.user;
          break;
        case 'system':
          role = ChatRole.system;
          break;
        case 'tool':
          role = ChatRole.tool;
          break;
        default:
          role = ChatRole.assistant;
      }

      List<ToolCall>? toolCalls;
      if (choice.containsKey('tool_calls') && choice['tool_calls'] != null) {
        toolCalls = (choice['tool_calls'] as List)
            .map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
            .toList();
      }

      return ChatMessage(
        role: role,
        content: content,
        toolCalls: toolCalls,
      );
    } else {
      throw Exception('OpenAI Service Error: ${response.statusCode} - ${response.data}');
    }
  }

  @override
  Stream<String> streamChat(List<ChatMessage> messages) async* {
    final settings = _ref.read(settingsProvider);
    final baseUrl = settings.llamaServerUrl;
    final model = settings.chatModel;

    final response = await _dio.post(
      '$baseUrl/v1/chat/completions',
      data: {
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': true,
      },
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200) {
      final Stream<List<int>> stream = response.data.stream;
      String buffer = '';

      // Use bind and cast to avoid Uint8List vs List<int> type conflicts in transform()
      final decodedStream = utf8.decoder.bind(stream.cast<List<int>>());

      await for (final text in decodedStream) {
        buffer += text;

        while (buffer.contains('\n')) {
          final index = buffer.indexOf('\n');
          final line = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 1);

          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') break;

            try {
              final json = jsonDecode(data);
              final content = json['choices'][0]['delta']['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            } catch (e) {
              // Ignore invalid JSON chunks (often headers or partial chunks)
            }
          }
        }
      }
    } else {
      throw Exception('OpenAI Streaming Service Error: ${response.statusCode}');
    }
  }

  @override
  Stream<String> streamResponse(String message) {
    // Basic streaming implementation placeholder
    return Stream.value("Streaming not fully implemented in this minimalist path yet.");
  }

  @override
  Future<bool> checkConnection() async {
    final settings = _ref.read(settingsProvider);
    final baseUrl = settings.llamaServerUrl;

    try {
      final response = await _dio.get(
        '$baseUrl/v1/models',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

final aiServiceProvider = Provider<IAiService>((ref) => OpenAiService(ref));
