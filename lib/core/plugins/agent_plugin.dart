import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_models.dart';
import '../../src/features/chat/domain/entities/message.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';

class PluginResult {
  final Map<String, dynamic> metadataToPersist;
  final dynamic resultData;
  final bool successful;

  PluginResult({
    required this.metadataToPersist,
    this.resultData,
    this.successful = true,
  });
}

abstract class AgentPlugin {
  String get name;
  String get toolName;
  ToolDefinition get toolDefinition;
  
  String get mandate;
  
  String getStatusMessage(Map<String, dynamic> toolArgs);
  
  bool isEnabled(SettingsState settings);

  Future<PluginResult> execute({
    required Map<String, dynamic> toolArgs,
    required String userQuery,
    required String fullContext,
    required ChunkRegistry registry,
    Map<String, dynamic>? currentTabMetadata,
  });

  String getSynthesisInjection(PluginResult result);

  void onResult(PluginResult result, String messageId, Ref ref);

  Widget? buildMessageActionTrigger(BuildContext context, WidgetRef ref, Message message);
}
