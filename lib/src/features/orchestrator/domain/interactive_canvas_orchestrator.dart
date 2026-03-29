import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/services/openai_service.dart';
class InteractiveCanvasPackage {
  final List<int> indices;
  final String canvasGoal;

  InteractiveCanvasPackage({required this.indices, required this.canvasGoal});

  @override
  String toString() => 'InteractiveCanvasPackage(indices: $indices, goal: $canvasGoal)';
}

class InteractiveCanvasResult {
  final InteractiveCanvasPackage package;
  final String htmlContent;
  final List<ChatMessage> steps;

  InteractiveCanvasResult({
    required this.package,
    required this.htmlContent,
    required this.steps,
  });
}

final interactiveCanvasOrchestratorProvider = Provider((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return InteractiveCanvasOrchestrator(aiService: aiService);
});

class InteractiveCanvasOrchestrator {
  final IAiService aiService;

  InteractiveCanvasOrchestrator({required this.aiService});

  Future<InteractiveCanvasResult> generateCanvas({
    required InteractiveCanvasPackage package,
    required ChunkRegistry registry,
    String? fullContext,
  }) async {
    // 1. Resolve Chunks
    final List<String> resolvedChunks = [];
    for (final index in package.indices) {
      final res = registry.getResult(index);
      if (res != null) {
        resolvedChunks.add('[[Chunk $index]]\n${res.content}');
      }
    }

    // 2. Build Bundled Message
    final StringBuffer contentBuffer = StringBuffer();

    if (fullContext != null) {
      contentBuffer.writeln('### CONVERSATION HISTORY');
      contentBuffer.writeln(fullContext);
      contentBuffer.writeln();
    }

    contentBuffer.writeln('### TARGET CANVAS GOAL');
    contentBuffer.writeln(package.canvasGoal);
    contentBuffer.writeln();

    contentBuffer.writeln('### INFORMATION CHUNKS');
    contentBuffer.writeln(resolvedChunks.join('\n\n'));

    final messages = [
      ChatMessage(role: ChatRole.system, content: _buildSystemPrompt()),
      ChatMessage(
        role: ChatRole.user,
        content: contentBuffer.toString().trim(),
      ),
    ];

    // 3. Generate Content
    final response = await aiService.chat(messages);
    final cleanHtml = _extractHtml(response.content);

    // 4. Return result
    return InteractiveCanvasResult(
      package: package,
      htmlContent: cleanHtml,
      steps: [
        ChatMessage(
          role: response.role,
          content: response.content,
          toolCalls: response.toolCalls,
        )
      ],
    );
  }

  String _extractHtml(String text) {
    if (text.contains('```html')) {
      final startIndex = text.indexOf('```html') + '```html'.length;
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
    return '''### ROLE
Senior UI Designer. Your task is to generate premium, STATIC data components (Canvases) using the restricted SIFT standard.

### CORE MANDATES (STRICT COMPLIANCE REQUIRED)
1. **STATIC OUTPUT ONLY**: Strictly exclude `<a>`, `<button>`, and any interactive tags.
2. **ZERO-FLEX TOLERANCE**: **NEVER** use `display: flex`, `display: grid`, `float`, or `position`. These will CRASH the renderer or cause layout failure.
3. **TABLE-BASED ALIGNMENT**: Use `<table>` for ALL side-by-side content (e.g., labels vs. values, multi-column stats).
4. **WIDTH COMPLIANCE**: Assign `width="100%"` to every `<table>` tag.
5. **CELL PROPORTIONS**: Assign explicit percentage widths to `<td>` and `<th>` elements (e.g., `<td width="60%">`) to ensure consistent alignment.
6. **SVG INLINE STYLING**: Assign all styles as inline attributes (e.g., `<text fill="#FFFFFF">`). `<style>` blocks or classes are NOT permitted inside `<svg>`.
7. **TAG HIERARCHY**: `<tr>`, `<td>`, `<th>` must be nested inside `<table>`. No loose table tags.
8. **SVG MULTI-LINE TEXT**: SVG `<text>` elements DO NOT support `<br/>`. Use separate `<text>` elements with unique `y` positions for multiple lines.
9. **SVG CENTERING**: Use `text-align: center` on a parent `<div>` to center SVG content.
10. **SVG BOUNDS**: Always ensure content (x, y, width, height) stay WITHIN the defined `width` and `viewBox`. Elements outside the `viewBox` will be CLIPPED.
11. **NO OUTER BORDERS**: Do NOT add a border to the `.canvas-container`. This creates a double-box effect. Only the `.card` should have a border IF absolutely necessary, but prefer a borderless, shadow-based look.
12. **PREMIUM ROUNDING**: Use `border-radius: 24px` for all cards and sections.
13. **TEXT CONTRAST**: All text MUST be `#FFFFFF` (Solid) or `#938F99` (Muted). NEVER use black or dark text as the background is `#0E0E0E` or `#171719`.

### SIFT DESIGN SYSTEM (THE WHITELIST)
- **Approved Tags**: `<div>`, `<span>`, `<table>`, `<tr>`, `th`, `<td>`, `<h3>`, `<h4>`, `<p>`, `<ul>`, `ol`, `li`, `<br>`, `<svg>`, `<path>`, `<rect>`, `<circle>`, `<line>`, `<g>`, `<text>`.
- **Approved CSS**: `color`, `background-color`, `padding`, `margin`, `font-size`, `font-weight`, `text-align`, `line-height`, `letter-spacing`, `border`, `border-radius`.
- **SIFT Palette**: #0E0E0E (Scaffold), #171719 (Card), #D0BCFF (Primary), #CCC2DC (Success), #EFB8C8 (Detail), #FFFFFF (Text), #938F99 (Muted), #252525 (Border).

### GOLDEN EXAMPLES (FEW-SHOT)

#### EXAMPLE 1: METRIC ROW (Side-by-Side Label & Value)
```html
<style>
  .canvas-container { padding: 24px; background: #0E0E0E; font-family: sans-serif; text-align: center; color: #FFFFFF; }
  .card { background: #171719; border-radius: 24px; padding: 24px; text-align: left; color: #FFFFFF; }
  .table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
  .label-cell { border-left: 4px solid #D0BCFF; padding: 12px; color: #938F99; font-size: 14px; text-align: left; }
  .value-cell { padding: 12px; color: #FFFFFF; font-size: 24px; font-weight: bold; text-align: right; }
</style>
<div class="canvas-container">
  <div class="card">
    <table class="table">
      <tr>
        <td class="label-cell">[METRIC_LABEL]</td>
        <td class="value-cell">[METRIC_VALUE]</td>
      </tr>
    </table>
    <table class="table">
      <tr>
        <td class="label-cell" style="border-left-color: #EFB8C8;">[METRIC_LABEL_SECONDARY]</td>
        <td class="value-cell">[METRIC_VALUE_SECONDARY]</td>
      </tr>
    </table>
  </div>
</div>
```

#### EXAMPLE 2: DATA TABLE (Standard Usage)
```html
<div class="canvas-container" style="color: #FFFFFF; text-align: center;">
  <div class="card" style="border-radius: 24px; background: #171719; padding: 32px; color: #FFFFFF; text-align: left;">
    <table style="border-collapse: collapse; width: 100%;">
      <tr>
        <th style="color: #938F99; text-align: left; padding: 8px; font-size: 12px; border-bottom: 1px solid #252525;">[COL_HEADER_1]</th>
        <th style="color: #938F99; text-align: right; padding: 8px; font-size: 12px; border-bottom: 1px solid #252525;">[COL_HEADER_2]</th>
      </tr>
      <tr>
        <td style="padding: 12px 8px; border-bottom: 1px solid #252525; color: #FFFFFF;">[ROW_DATA_1]</td>
        <td style="padding: 12px 8px; border-bottom: 1px solid #252525; text-align: right; color: #D0BCFF; font-weight: bold;">[ROW_DATA_2]</td>
      </tr>
    </table>
  </div>
</div>
```

#### EXAMPLE 3: PROGRESS BAR (Inline SVG Bar)
```html
<div class="canvas-container" style="text-align: center; color: #FFFFFF;">
  <div class="card" style="border-radius: 24px; background: #171719; padding: 32px; color: #FFFFFF;">
    <p style="color: #FFFFFF; font-size: 14px; margin-bottom: 8px;">[TITLE_TEXT]</p>
    <svg width="400" height="20" viewBox="0 0 400 20">
      <rect x="0" y="0" width="400" height="20" rx="10" fill="#252525" />
      <rect x="0" y="0" width="280" height="20" rx="10" fill="#D0BCFF" />
    </svg>
    <p style="color: #938F99; font-size: 12px; margin-top: 8px;">[SUBTEXT_OR_PERCENTAGE]</p>
  </div>
</div>
```

#### EXAMPLE 4: SIDE-BY-SIDE CONTENT (2-Column Layout via Table)
```html
<div class="canvas-container" style="color: #FFFFFF; text-align: center;">
  <div class="card" style="border-radius: 24px; background: #171719; padding: 32px; color: #FFFFFF; text-align: left;">
    <table style="width: 100%; border-collapse: collapse;">
      <tr>
        <td style="padding: 20px; vertical-align: top; border-right: 1px solid #252525;">
          <h4 style="color: #D0BCFF; margin-top: 0;">[COLUMN_1_TITLE]</h4>
          <p style="color: #938F99;">[COLUMN_1_TEXT_DESCRIPTION]</p>
        </td>
        <td style="padding: 20px; vertical-align: top; text-align: center;">
          <h4 style="color: #EFB8C8; margin-top: 0;">[COLUMN_2_TITLE]</h4>
          <p style="color: #FFFFFF; font-size: 24px; font-weight: bold;">[COLUMN_2_DATA]</p>
        </td>
      </tr>
    </table>
  </div>
</div>
```

#### EXAMPLE 5: MULTI-SEGMENT DONUT GRAPH (Inline SVG)
```html
<div class="canvas-container" style="text-align: center; color: #FFFFFF;">
  <div class="card" style="border-radius: 24px; background: #171719; padding: 40px; color: #FFFFFF;">
    <h3 style="color: #D0BCFF; margin-bottom: 24px;">[GRAPH_TITLE]</h3>
    <svg width="240" height="240" viewBox="0 0 240 240">
      <!-- Background Circle -->
      <circle cx="120" cy="120" r="100" fill="none" stroke="#252525" stroke-width="20" />
      
      <!-- Segment 1 (e.g. 40% of 628 circumference) -->
      <circle cx="120" cy="120" r="100" fill="none" stroke="#D0BCFF" stroke-width="20" 
              stroke-dasharray="251 628" stroke-dashoffset="0" transform="rotate(-90 120 120)" />
      
      <!-- Segment 2 (e.g. 20%, offset by Segment 1) -->
      <circle cx="120" cy="120" r="100" fill="none" stroke="#EFB8C8" stroke-width="20" 
              stroke-dasharray="125 628" stroke-dashoffset="-251" transform="rotate(-90 120 120)" />
              
      <!-- Center Text Lines (Separated) -->
      <text x="120" y="115" text-anchor="middle" font-size="28" fill="#FFFFFF" font-weight="bold">[METRIC]</text>
      <text x="120" y="145" text-anchor="middle" font-size="12" fill="#938F99">[UNIT_OR_LABEL]</text>
    </svg>
  </div>
</div>
```
''';
  }
}
