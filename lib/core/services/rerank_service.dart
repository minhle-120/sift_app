import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';

class RerankService {
  final Dio _dio = Dio();
  final String serverUrl;
  final String model;

  RerankService({required this.serverUrl, required this.model});

  /// Returns a list of scores for the provided documents relative to the query.
  /// Higher is better.
  Future<List<double>> getScores(String query, List<String> documents) async {
    if (documents.isEmpty) return [];
    if (model.isEmpty) {
      // Return neutral scores if no model is configured
      return List.filled(documents.length, 1.0);
    }

    try {
      final response = await _dio.post(
        '$serverUrl/v1/rerank',
        data: {
          'model': model,
          'query': query,
          'documents': documents,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = response.data['results'];
        // Sort back to match input order using 'index' field usually provided by rerankers
        // or just extract scores directly if the API returns them ordered.
        // Assuming standard /v1/rerank response format.
        final List<double> scores = List.filled(documents.length, 0.0);
        for (var result in results) {
          int idx = result['index'];
          double score = result['relevance_score'].toDouble();
          scores[idx] = score;
        }
        return scores;
      }
    } catch (e) {
      // Log error appropriately if a logger is available
    }

    // Default to neutral scores on failure
    return List.filled(documents.length, 0.0);
  }
}

final rerankServiceProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return RerankService(
    serverUrl: settings.llamaServerUrl,
    model: settings.rerankModel,
  );
});
