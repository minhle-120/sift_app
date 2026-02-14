import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';

class SettingsState {
  final String llamaServerUrl;
  final String chatModel;
  final String embeddingModel;
  final String rerankModel;
  final int embeddingDimensions;
  final int chunkSize;
  final int chunkOverlap;
  final bool isSyncEnabled;
  final List<String> availableModels;
  final bool isLoadingModels;
  final String? error;

  const SettingsState({
    this.llamaServerUrl = 'http://localhost:8080',
    this.chatModel = '',
    this.embeddingModel = '',
    this.rerankModel = '',
    this.embeddingDimensions = 1024,
    this.chunkSize = 100,
    this.chunkOverlap = 50,
    this.isSyncEnabled = true,
    this.availableModels = const [],
    this.isLoadingModels = false,
    this.error,
  });

  SettingsState copyWith({
    String? llamaServerUrl,
    String? chatModel,
    String? embeddingModel,
    String? rerankModel,
    int? embeddingDimensions,
    int? chunkSize,
    int? chunkOverlap,
    bool? isSyncEnabled,
    List<String>? availableModels,
    bool? isLoadingModels,
    String? error,
  }) {
    return SettingsState(
      llamaServerUrl: llamaServerUrl ?? this.llamaServerUrl,
      chatModel: chatModel ?? this.chatModel,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      rerankModel: rerankModel ?? this.rerankModel,
      embeddingDimensions: embeddingDimensions ?? this.embeddingDimensions,
      chunkSize: chunkSize ?? this.chunkSize,
      chunkOverlap: chunkOverlap ?? this.chunkOverlap,
      isSyncEnabled: isSyncEnabled ?? this.isSyncEnabled,
      availableModels: availableModels ?? this.availableModels,
      isLoadingModels: isLoadingModels ?? this.isLoadingModels,
      error: error,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  final Dio _dio = Dio();

  SettingsController() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('llamaServerUrl') ?? 'http://localhost:8080';
    
    state = state.copyWith(
      llamaServerUrl: url,
      chatModel: prefs.getString('chatModel') ?? '',
      embeddingModel: prefs.getString('embeddingModel') ?? '',
      rerankModel: prefs.getString('rerankModel') ?? '',
      embeddingDimensions: prefs.getInt('embeddingDimensions') ?? 1024,
      chunkSize: prefs.getInt('chunkSize') ?? 100,
      chunkOverlap: prefs.getInt('chunkOverlap') ?? 50,
      isSyncEnabled: prefs.getBool('isSyncEnabled') ?? true,
    );
    
    // Fetch models after loading URL
    fetchModels();
  }

  Future<void> fetchModels() async {
    if (state.llamaServerUrl.isEmpty) return;
    
    state = state.copyWith(isLoadingModels: true, error: null);
    
    try {
      final response = await _dio.get('${state.llamaServerUrl}/v1/models');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('data')) {
          final List<dynamic> modelsList = data['data'];
          final List<String> models = modelsList
              .map((m) => m['id'].toString())
              .toList();
          
          state = state.copyWith(
            availableModels: models,
            isLoadingModels: false,
          );
        }
      } else {
         state = state.copyWith(
            isLoadingModels: false, 
            error: 'Failed to fetch models: ${response.statusCode}'
         );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingModels: false,
        error: 'Connection error: $e',
      );
    }
  }

  Future<void> updateLlamaServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llamaServerUrl', url);
    state = state.copyWith(llamaServerUrl: url);
    
    // Debounce fetching models or just let user trigger it manually? 
    // For now, let's trigger it if URL looks valid-ish length
    if (url.length > 10) {
      fetchModels();
    }
  }

  Future<void> updateChatModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chatModel', model);
    state = state.copyWith(chatModel: model);
  }

  Future<void> updateEmbeddingModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('embeddingModel', model);
    state = state.copyWith(embeddingModel: model);
  }

  Future<void> updateRerankModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rerankModel', model);
    state = state.copyWith(rerankModel: model);
  }

  Future<void> updateEmbeddingDimensions(int dim) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('embeddingDimensions', dim);
    state = state.copyWith(embeddingDimensions: dim);
  }

  Future<void> updateChunkSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chunkSize', size);
    state = state.copyWith(chunkSize: size);
  }

  Future<void> updateChunkOverlap(int overlap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chunkOverlap', overlap);
    state = state.copyWith(chunkOverlap: overlap);
  }

  Future<void> toggleSync(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSyncEnabled', enabled);
    state = state.copyWith(isSyncEnabled: enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController();
});
