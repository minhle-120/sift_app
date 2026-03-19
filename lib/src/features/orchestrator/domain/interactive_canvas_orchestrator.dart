import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../services/ai/i_ai_service.dart';
import '../../../../core/services/openai_service.dart';

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

    contentBuffer.writeln('### EVIDENCE CHUNKS');
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
    return '''You are a UI/UX Designer and SVG Expert. Your task is to transform research evidence into a beautiful, structured, and interactive component using HTML, CSS, and SVG.

### DESIGN PRINCIPLES:
1. **Premium Aesthetic**: Use subtle gradients, rounded corners, and clean typography.
2. **Thematic Consistency**: You MUST use the following colors for all styling to match the app theme:
   - Base Background (page): #131314
   - Card/Surface Background: #1E1E20
   - Primary/Accent Color: #D0BCFF
   - Primary Text: #FFFFFF
   - Outline/Borders: #444746
3. **Interactive Visuals**: When creating diagrams (e.g., flowcharts, maps, anatomy), use SVG. Combine them with HTML for structural layouts.
4. **Readability**: Ensure high contrast and clear hierarchy.

### CRITICAL TECHNICAL CONSTRAINTS (FLUTTER LIMITATIONS):
- **No JavaScript**: Do not use `<script>` tags. The environment is static HTML/CSS.
- **SVG Sizing (CRITICAL)**: You MUST set explicit, absolute integer `width` and `height` attributes on EVERY `<svg>` tag (e.g. `<svg width="800" height="400" viewBox="0 0 800 400">`). Do NOT use percentages like `width="100%"`. Without explicit integer dimensions, the SVG will disappear or crash the renderer.
- **SVG Filters BANNED**: `flutter_svg` does NOT support `<filter>`, `<feGaussianBlur>`, or dropshadows. Do NOT use them.
- **SVG Styling Isolation**: SVG elements CANNOT inherit CSS classes or variables from the HTML `<style>` block. You MUST use inline presentation attributes (e.g., `fill="#D0BCFF"`, `stroke="#FFFFFF"`) directly on SVG tags.
- **No CSS Variables**: Do NOT use CSS variables (like `var(--sift-primary)`) inside SVGs or complex HTML styles. Use the exact hex colors provided above.
- **Layout Limitations**: The HTML renderer does NOT support complex Flexbox (`display: flex`, `align-items`) or absolute positioning (`position: absolute`, `bottom: 0`). Do NOT try to build bar charts or complex visual structures natively using HTML `<div>` blocks! You MUST build ALL charts, graphs, and complex visual diagrams entirely out of SVG. Rely on standard HTML block elements only for structural layout, text paragraphs, headings, and `<a>` links.
- **Link Placement**: Do NOT place `<a>` tags inside `<svg>` tags. They will not be clickable. All interactive `<a>` elements MUST be placed in the HTML structure OUTSIDE the `<svg>` tag.
- **Structure**: Wrap your overall content in a `div` with class "canvas-container".

### INTERACTIVITY HOOKS:
To make elements interactive, use standard `<a>` tags in your HTML. 
- You can use "logical links" that describe an action, e.g., `<a href="research:quantum_physics">Explore Quantum Physics</a>`.
- The parent application will capture these taps.

### EXAMPLES OF VALID CANVAS GENERATION

**Example 1: A Simple Infographic Card**
```html
<style>
  .canvas-container { color: #FFFFFF; font-family: sans-serif; background: #131314; padding: 20px; }
  .card { background: #1E1E20; border: 1px solid #444746; border-radius: 12px; padding: 16px; margin-bottom: 20px; text-align: center; }
  .accent { color: #D0BCFF; font-weight: bold; }
  .link-button { display: inline-block; padding: 8px 16px; background: #D0BCFF; color: #131314; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 10px; }
</style>
<div class="canvas-container">
  <div class="card">
    <h3><span class="accent">Quantum Computing</span> Overview</h3>
    <p>A brief introduction to qubits and superposition.</p>
    
    <!-- SVG MUST have explicit integer width and height -->
    <svg width="120" height="120" viewBox="0 0 120 120">
      <!-- SVG paths MUST use exact HEX colors inline -->
      <circle cx="60" cy="60" r="50" stroke="#D0BCFF" stroke-width="4" fill="#1E1E20" />
      <circle cx="60" cy="20" r="10" fill="#FFFFFF" />
      <circle cx="60" cy="100" r="10" fill="#444746" />
      <path d="M60 30 L60 90" stroke="#444746" stroke-width="2" stroke-dasharray="4" />
    </svg>
    <br>
    
    <!-- Interactive links MUST be outside the SVG -->
    <a href="research:quantum_superposition" class="link-button">Learn About Superposition</a>
  </div>
</div>
```

**Example 2: A Flowchart with HTML Interactivity**
```html
<style>
  .canvas-container { background: #131314; color: #FFFFFF; font-family: sans-serif; padding: 20px; }
  .flow-row { margin: 20px 0; text-align: center; }
  .node { display: inline-block; background: #1E1E20; border: 2px solid #D0BCFF; padding: 15px 25px; border-radius: 8px; font-weight: bold; color: #D0BCFF; text-decoration: none; }
  .arrow-container { text-align: center; margin: 10px 0; }
</style>
<div class="canvas-container">
  <h2>Machine Learning Pipeline</h2>
  
  <div class="flow-row">
    <!-- Clickable HTML block instead of SVG shapes for interactive nodes -->
    <a href="research:data_collection" class="node">1. Data Collection</a>
  </div>
  
  <div class="arrow-container">
    <svg width="40" height="40" viewBox="0 0 40 40">
      <path d="M20 0 L20 30 M10 20 L20 35 L30 20" stroke="#444746" stroke-width="3" fill="none" />
    </svg>
  </div>
  
  <div class="flow-row">
    <a href="research:model_training" class="node">2. Model Training</a>
  </div>
</div>
```

**Example 3: A Data Chart built entirely in SVG**
```html
<style>
  .canvas-container { background: #131314; color: #FFFFFF; font-family: sans-serif; padding: 20px; }
  .card { background: #1E1E20; border: 1px solid #444746; border-radius: 12px; padding: 20px; text-align: center; }
  .link-button { display: inline-block; padding: 10px 20px; background: #D0BCFF; color: #131314; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 15px; }
</style>
<div class="canvas-container">
  <div class="card">
    <h3>Memory Consumption Trends</h3>
    <p>Comparing baseline vs optimized model runs.</p>
    
    <!-- All chart elements (bars, grid lines, labels) are SVG! -->
    <svg width="400" height="200" viewBox="0 0 400 200">
      <!-- Grid Lines -->
      <line x1="50" y1="150" x2="350" y2="150" stroke="#444746" stroke-width="2" />
      <line x1="50" y1="100" x2="350" y2="100" stroke="#444746" stroke-width="1" stroke-dasharray="4" />
      <line x1="50" y1="50" x2="350" y2="50" stroke="#444746" stroke-width="1" stroke-dasharray="4" />
      
      <!-- Baseline Bar -->
      <rect x="100" y="50" width="60" height="100" fill="#444746" />
      <text x="130" y="40" text-anchor="middle" fill="#FFFFFF" font-size="14">8GB</text>
      <text x="130" y="170" text-anchor="middle" fill="#A0A0A0" font-size="12">Baseline</text>

      <!-- Optimized Bar -->
      <rect x="240" y="110" width="60" height="40" fill="#D0BCFF" />
      <text x="270" y="100" text-anchor="middle" fill="#FFFFFF" font-size="14">2GB</text>
      <text x="270" y="170" text-anchor="middle" fill="#A0A0A0" font-size="12">Optimized</text>
    </svg>
    <br>
    
    <!-- Interactive link placed OUTSIDE the SVG -->
    <a href="research:optimization_techniques" class="link-button">Read Optimization Techniques</a>
  </div>
</div>
```
''';
  }
}
