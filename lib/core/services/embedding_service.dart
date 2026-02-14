import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/features/chat/presentation/controllers/settings_controller.dart';

final embeddingServiceProvider = Provider((ref) => EmbeddingService(ref));

class EmbeddingService {
  final Ref _ref;
  final Dio _dio = Dio();

  EmbeddingService(this._ref);

  Future<List<List<double>>> getEmbeddings(List<String> texts) async {
    final settings = _ref.read(settingsProvider);
    final baseUrl = settings.llamaServerUrl;
    final model = settings.embeddingModel;

    if (baseUrl.isEmpty) {
      throw Exception('Llama Server URL is not configured');
    }

    if (model.isEmpty) {
       // Optional: fetch models or throw? 
       // For now throw to urge user to select model
       throw Exception('No embedding model selected');
    }

    try {
      // Prepare request for OpenAI compatible endpoint
      // Note: Some local servers might expect 'input' as string or list
      // We'll send list for batching if possible, but standard is handling list.
      
      final response = await _dio.post(
        '$baseUrl/v1/embeddings',
        data: {
          'model': model,
          'input': texts,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            // Add auth header if needed, for now assume local open
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('data')) {
          final List<dynamic> dataList = data['data'];
          // Ensure sorted by index to match input order (openai guarantees this but good to be safe if index provided)
          // Actually standard is just list in order.
          
          final List<List<double>> embeddings = [];
          for (var item in dataList) {
            if (item is Map && item.containsKey('embedding')) {
               final List<dynamic> vec = item['embedding'];
               embeddings.add(vec.map((e) => (e as num).toDouble()).toList());
            }
          }
          
          if (embeddings.length != texts.length) {
             throw Exception('Mismatch in embedding count: sent ${texts.length}, got ${embeddings.length}');
          }
          
          return embeddings;
        }
      }
      
      throw Exception('Failed to get embeddings: ${response.statusCode} ${response.statusMessage}');
      
    } catch (e) {
      throw Exception('Embedding service error: $e');
    }
  }
}
