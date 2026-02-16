import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../core/services/openai_service.dart';
import '../../../../services/ai/i_ai_service.dart';

final visualOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return VisualOrchestrator(aiService: aiService);
});

class VisualOrchestrator {
  final IAiService aiService;

  VisualOrchestrator({required this.aiService});

  Future<VisualResult> visualize({
    required VisualPackage package,
    required ChunkRegistry registry,
  }) async {
    // 1. Resolve Chunks
    final List<String> resolvedChunks = [];
    for (final index in package.indices) {
      final res = registry.getResult(index);
      if (res != null) {
        resolvedChunks.add('[[Chunk $index]]\n${res.content}');
      }
    }

    // 2. Build Messages
    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildSystemPrompt()),
      ChatMessage(
        role: ChatRole.user,
        content: '''Target Visualization: ${package.visualizationGoal}

Evidence Chunks:
${resolvedChunks.join('\n\n')}''',
      ),
    ];

    // 3. Generate Schema
    final response = await aiService.chat(messages);
    final cleanContent = _extractJson(response.content);

    // 4. Return result with clean content
    return VisualResult(
      package: package,
      schema: cleanContent,
      steps: [
        ChatMessage(
          role: response.role,
          content: cleanContent,
          toolCalls: response.toolCalls,
        )
      ],
    );
  }

  String _extractJson(String text) {
    if (text.contains('```json')) {
      final startIndex = text.indexOf('```json') + '```json'.length;
      final endIndex = text.lastIndexOf('```');
      if (endIndex > startIndex) {
        return text.substring(startIndex, endIndex).trim();
      }
    } else if (text.contains('```')) {
      final startIndex = text.indexOf('```') + '```'.length;
      final endIndex = text.lastIndexOf('```');
      if (endIndex > startIndex) {
        return text.substring(startIndex, endIndex).trim();
      }
    }
    return text.trim();
  }

  String _buildSystemPrompt() {
    return '''You are an Information Architect and Data Visualization Expert. Your task is to transform research evidence into a highly logical, structured JSON schema for GraphView visualization.

### GOAL:
Create graphs that reveal the **structure** and **relationships** in the data. 
Avoid "star" or "hub-and-spoke" diagrams where everything connects to one central node unless that is strictly the logical relationship (e.g., a simple list). Instead, look for:
- **Causality**: A implies B implies C.
- **Hierarchy**: A is a parent of B and C.
- **Comparison**: A and B are both types of C.
- **Process**: Step A -> Step B -> Step C.

### OUTPUT FORMAT:
Output a valid JSON block with the following structure:
JSON Structure:
```json
{
  "title": "Concise Chart Title",
  "layoutType": "tree" | "directed" | "circular" | "balloon" | "radial" | "mindmap",
  "nodes": [
    {"id": "unique_id", "label": "Short Display Name", "type": "important" | "normal"}
  ],
  "edges": [
    {"from": "id1", "to": "id2", "label": "Relationship name"}
  ]
}
```

### EXAMPLES BY LAYOUT TYPE:

**1. Tree (Strict Hierarchy)**
Input: "Describe the layers of Classification X."
Output JSON:
```json
{
  "title": "Classification Hierarchy",
  "layoutType": "tree",
  "nodes": [
    {"id": "root", "label": "Top Category", "type": "important"},
    {"id": "sub1", "label": "Sub-concept A", "type": "normal"},
    {"id": "sub2", "label": "Sub-concept B", "type": "normal"}
  ],
  "edges": [
    {"from": "root", "to": "sub1", "label": "Classifies"},
    {"from": "root", "to": "sub2", "label": "Classifies"}
  ]
}
```

**2. Directed (Linear Flow)**
Input: "Sequence from Event A to Outcome C."
Output JSON:
```json
{
  "title": "Process Flow",
  "layoutType": "directed",
  "nodes": [
    {"id": "a", "label": "Initial Stage A", "type": "normal"},
    {"id": "b", "label": "Transition B", "type": "normal"},
    {"id": "c", "label": "Final Result C", "type": "important"}
  ],
  "edges": [
    {"from": "a", "to": "b", "label": "Triggers"},
    {"from": "b", "to": "c", "label": "Leads to"}
  ]
}
```

**3. Circular (Feedback Loop)**
Input: "Describe the lifecycle of System Y."
Output JSON:
```json
{
  "layoutType": "circular",
  "nodes": [
    {"id": "s1", "label": "Input Phase", "type": "normal"},
    {"id": "s2", "label": "Execution", "type": "normal"},
    {"id": "s3", "label": "Feedback", "type": "normal"}
  ],
  "edges": [
    {"from": "s1", "to": "s2", "label": "Starts"},
    {"from": "s2", "to": "s3", "label": "Reports"},
    {"from": "s3", "to": "s1", "label": "Refines"}
  ]
}
```

**4. Balloon (Clustering around Hub)**
Input: "Show variables influencing Factor Z."
Output JSON:
```json
{
  "layoutType": "balloon",
  "nodes": [
    {"id": "core", "label": "Central Factor Z", "type": "important"},
    {"id": "v1", "label": "Variable 1", "type": "normal"},
    {"id": "v2", "label": "Variable 2", "type": "normal"}
  ],
  "edges": [
    {"from": "core", "to": "v1", "label": "Influences"},
    {"from": "core", "to": "v2", "label": "Influences"}
  ]
}
```

**5. Radial (Concentric Layers)**
Input: "Map the layers of Influence W."
Output JSON:
```json
{
  "layoutType": "radial",
  "nodes": [
    {"id": "inner", "label": "Core Essence", "type": "important"},
    {"id": "mid", "label": "Primary Layer", "type": "normal"},
    {"id": "outer", "label": "Extended Scope", "type": "normal"}
  ],
  "edges": [
    {"from": "inner", "to": "mid", "label": "Foundation of"},
    {"from": "mid", "to": "outer", "label": "Projects to"}
  ]
}
```

**6. Mindmap (Exploration)**
Input: "Map the brainstormed ideas for Topic Q."
Output JSON:
```json
{
  "layoutType": "mindmap",
  "nodes": [
    {"id": "main", "label": "Central Theme Q", "type": "important"},
    {"id": "idea1", "label": "Idea Alpha", "type": "normal"},
    {"id": "idea2", "label": "Idea Beta", "type": "normal"}
  ],
  "edges": [
    {"from": "main", "to": "idea1", "label": "Sparks"},
    {"from": "main", "to": "idea2", "label": "Sparks"}
  ]
}
```

### INSTRUCTIONS:
1. **Title**: Always include a concise, descriptive "title" (2-4 words) for the visualization.
2. **Labels**: Keep labels very concise (2-4 words).
3. **Node Types**: Use "important" for primary actors/results and "normal" for supporting data.
4. **Edges**: Always provide a descriptive label for edges to explain the connection.
5. **Resilience**: Ensure all `id`s used in `edges` exist in the `nodes` list.
''';
  }
}
