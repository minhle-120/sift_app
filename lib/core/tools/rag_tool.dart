import '../models/ai_models.dart';
import '../storage/sift_database.dart';
import '../services/embedding_service.dart';
import '../services/rerank_service.dart';
import 'package:drift/drift.dart' hide Column;

class RAGTool {
  final AppDatabase database;
  final EmbeddingService embeddingService;
  final RerankService rerankService;
  final ChunkRegistry registry;

  RAGTool({
    required this.database,
    required this.embeddingService,
    required this.rerankService,
    required this.registry,
  });

  /// The tool name for OpenAI tool calling
  static const String name = 'query_knowledge_base';

  ToolDefinition get definition => ToolDefinition(
        function: FunctionDefinition(
          name: name,
          description: 'Search the local knowledge base for relevant information using keywords for retrieval and a query for reranking.',
          parameters: {
            'type': 'object',
            'properties': {
              'keywords': {
                'type': 'string',
                'description': 'Search keywords used for the initial vector retrieval stage.'
              },
              'query': {
                'type': 'string',
                'description': 'A more detailed question or context used to rerank the retrieved results for best relevance.'
              }
            },
            'required': ['keywords', 'query']
          },
        ),
      );

  Future<String> execute(int collectionId, Map<String, dynamic> args) async {
    final String keywords = args['keywords'] ?? '';
    final String query = args['query'] ?? '';

    if (keywords.isEmpty) return 'No keywords provided.';

    // 1. Vector Search (Top 10)
    final embeddings = await embeddingService.getEmbeddings([keywords]);
    final vectorResults = await database.vectorSearch(
      collectionId: collectionId,
      queryEmbedding: embeddings.first,
      limit: 10,
    );

    if (vectorResults.isEmpty) return 'No relevant information found in the library.';

    // 2. Rerank (Filter down to 5)
    final List<String> chunkTexts = vectorResults.map((r) {
      final chunk = r.readTable(database.documentChunks);
      return chunk.content;
    }).toList();

    final scores = await rerankService.getScores(query, chunkTexts);

    // Pair results with scores and sort
    final List<_ScoredResult> scored = [];
    for (int i = 0; i < vectorResults.length; i++) {
      scored.add(_ScoredResult(vectorResults[i], scores[i]));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    // 3. Take Top 5 and Format with Registry
    final top5 = scored.take(5);
    final List<RAGResult> results = [];

    for (var s in top5) {
      final chunk = s.result.readTable(database.documentChunks);
      final doc = s.result.readTable(database.documents);
      
      final index = registry.getIndex(chunk.content);
      results.add(RAGResult(
        content: chunk.content,
        index: index,
        sourceTitle: doc.title,
        score: s.score,
      ));
    }

    // Sort by index for consistent presentation to AI
    results.sort((a, b) => a.index.compareTo(b.index));

    return results.join('\n\n');
  }
}

class _ScoredResult {
  final TypedResult result;
  final double score;
  _ScoredResult(this.result, this.score);
}
