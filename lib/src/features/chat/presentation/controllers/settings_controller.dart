import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/models/ai_models.dart';
import '../../../../../core/services/backend_downloader.dart';
import 'package:dio/dio.dart';

enum BackendType { external, internal }

class SettingsState {
  final String llamaServerUrl;
  final String chatModel;
  final String embeddingModel;
  final String rerankModel;
  final int embeddingDimensions;
  final int chunkSize;
  final int chunkOverlap;
  final bool isSyncEnabled;
  final VisualizerMode visualizerMode;
  final List<String> availableModels;
  final bool isLoadingModels;
  final String? error;
  final BackendType backendType;
  final int gpuDeviceIndex;
  final String modelsPath;
  final double downloadProgress;
  final bool isDownloading;
  final String downloadStatus;
  final bool isFetchingEngines;
  final List<GitHubAsset> availableEngines;
  final String? selectedEngine;

  const SettingsState({
    this.llamaServerUrl = 'http://localhost:8080',
    this.chatModel = '',
    this.embeddingModel = '',
    this.rerankModel = '',
    this.embeddingDimensions = 1024,
    this.chunkSize = 100,
    this.chunkOverlap = 50,
    this.isSyncEnabled = true,
    this.visualizerMode = VisualizerMode.auto,
    this.availableModels = const [],
    this.isLoadingModels = false,
    this.error,
    this.backendType = BackendType.external,
    this.gpuDeviceIndex = 0, // 0 = Auto/CPU, 1 = GPU 0, 2 = GPU 1 etc.
    this.modelsPath = '',
    this.downloadProgress = 0.0,
    this.isDownloading = false,
    this.downloadStatus = '',
    this.isFetchingEngines = false,
    this.availableEngines = const [],
    this.selectedEngine,
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
    VisualizerMode? visualizerMode,
    List<String>? availableModels,
    bool? isLoadingModels,
    String? error,
    BackendType? backendType,
    int? gpuDeviceIndex,
    String? modelsPath,
    double? downloadProgress,
    bool? isDownloading,
    String? downloadStatus,
    bool? isFetchingEngines,
    List<GitHubAsset>? availableEngines,
    String? selectedEngine,
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
      visualizerMode: visualizerMode ?? this.visualizerMode,
      availableModels: availableModels ?? this.availableModels,
      isLoadingModels: isLoadingModels ?? this.isLoadingModels,
      error: error,
      backendType: backendType ?? this.backendType,
      gpuDeviceIndex: gpuDeviceIndex ?? this.gpuDeviceIndex,
      modelsPath: modelsPath ?? this.modelsPath,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      isFetchingEngines: isFetchingEngines ?? this.isFetchingEngines,
      availableEngines: availableEngines ?? this.availableEngines,
      selectedEngine: selectedEngine ?? this.selectedEngine,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  final Dio _dio = Dio();
  final BackendDownloader _downloader = BackendDownloader();

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
      visualizerMode: VisualizerMode.values[prefs.getInt('visualizerMode') ?? 0],
      backendType: BackendType.values[prefs.getInt('backendType') ?? 0],
      gpuDeviceIndex: prefs.getInt('gpuDeviceIndex') ?? 0,
      modelsPath: prefs.getString('modelsPath') ?? '',
      selectedEngine: prefs.getString('selectedEngine'),
    );
    
    // Fetch models and engines
    fetchModels();
    fetchEngines();
  }

  Future<void> fetchEngines() async {
    state = state.copyWith(isFetchingEngines: true);
    final engines = await _downloader.fetchAvailableEngines();
    state = state.copyWith(availableEngines: engines, isFetchingEngines: false);
  }

  Future<void> downloadEngine(GitHubAsset asset) async {
    state = state.copyWith(isDownloading: true, downloadProgress: 0, downloadStatus: 'Preparing...');
    try {
      await _downloader.downloadAndExtract(
        asset,
        onProgress: (p) => state = state.copyWith(downloadProgress: p),
        onStatus: (s) => state = state.copyWith(downloadStatus: s),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedEngine', asset.name);
      state = state.copyWith(isDownloading: false, selectedEngine: asset.name);
    } catch (e) {
      state = state.copyWith(isDownloading: false, downloadStatus: 'Error: $e');
    }
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

  Future<void> updateVisualizerMode(VisualizerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('visualizerMode', mode.index);
    state = state.copyWith(visualizerMode: mode);
  }

  Future<void> updateBackendType(BackendType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('backendType', type.index);
    state = state.copyWith(backendType: type);
  }

  Future<void> updateGpuDeviceIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gpuDeviceIndex', index);
    state = state.copyWith(gpuDeviceIndex: index);
  }

  Future<void> updateModelsPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('modelsPath', path);
    state = state.copyWith(modelsPath: path);
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController();
});
