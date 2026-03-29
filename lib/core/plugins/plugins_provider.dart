import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_plugin.dart';
import 'graph_plugin.dart';
import 'code_plugin.dart';
import 'flashcard_plugin.dart';
import 'canvas_plugin.dart';
import '../../src/features/orchestrator/domain/graph_generator_orchestrator.dart';
import '../../src/features/orchestrator/domain/code_orchestrator.dart';
import '../../src/features/orchestrator/domain/flashcard_orchestrator.dart';
import '../../src/features/orchestrator/domain/interactive_canvas_orchestrator.dart';

final pluginsProvider = Provider<List<AgentPlugin>>((ref) {
  return [
    GraphPlugin(ref.watch(graphGeneratorOrchestratorProvider)),
    CodePlugin(ref.watch(codeOrchestratorProvider)),
    FlashcardPlugin(ref.watch(flashcardOrchestratorProvider)),
    CanvasPlugin(ref.watch(interactiveCanvasOrchestratorProvider)),
  ];
});
