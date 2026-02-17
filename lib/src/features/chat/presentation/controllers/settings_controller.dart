import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/models/ai_models.dart';
import '../../../../../core/services/backend_downloader.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

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
  final String enginesPath;
  final double downloadProgress;
  final bool isDownloading;
  final String downloadStatus;
  final bool isFetchingEngines;
  final List<GitHubAsset> availableEngines;
  final String? selectedEngine;
  final List<DeviceInfo> availableDevices;
  final String? selectedDeviceId;
  final List<String> serverLogs;
  // Engine verification (filesystem-checked)
  final String? installedEngineName;
  final bool isEngineVerified;
  // Model bundle
  final bool isDownloadingBundle;
  final double bundleProgress;
  final String bundleStatus;
  final bool isInstructInstalled;
  final bool isEmbeddingInstalled;
  final bool isRerankerInstalled;
  // Server lifecycle
  final bool isServerRunning;
  final bool isConfigReady;
  final String configPath;
  // First-time setup
  final bool isSetupComplete;
  final bool isSettingsLoaded;

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
    this.gpuDeviceIndex = 0,
    this.modelsPath = '',
    this.enginesPath = '',
    this.downloadProgress = 0.0,
    this.isDownloading = false,
    this.downloadStatus = '',
    this.isFetchingEngines = false,
    this.availableEngines = const [],
    this.selectedEngine,
    this.availableDevices = const [],
    this.selectedDeviceId,
    this.serverLogs = const [],
    this.installedEngineName,
    this.isEngineVerified = false,
    this.isDownloadingBundle = false,
    this.bundleProgress = 0,
    this.bundleStatus = '',
    this.isInstructInstalled = false,
    this.isEmbeddingInstalled = false,
    this.isRerankerInstalled = false,
    this.isServerRunning = false,
    this.isConfigReady = false,
    this.configPath = '',
    this.isSetupComplete = false,
    this.isSettingsLoaded = false,
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
    String? enginesPath,
    double? downloadProgress,
    bool? isDownloading,
    String? downloadStatus,
    bool? isFetchingEngines,
    List<GitHubAsset>? availableEngines,
    String? selectedEngine,
    List<DeviceInfo>? availableDevices,
    String? selectedDeviceId,
    List<String>? serverLogs,
    String? installedEngineName,
    bool? isEngineVerified,
    bool? isDownloadingBundle,
    double? bundleProgress,
    String? bundleStatus,
    bool? isInstructInstalled,
    bool? isEmbeddingInstalled,
    bool? isRerankerInstalled,
    bool? isServerRunning,
    bool? isConfigReady,
    String? configPath,
    bool? isSetupComplete,
    bool? isSettingsLoaded,
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
      error: error ?? this.error,
      backendType: backendType ?? this.backendType,
      gpuDeviceIndex: gpuDeviceIndex ?? this.gpuDeviceIndex,
      modelsPath: modelsPath ?? this.modelsPath,
      enginesPath: enginesPath ?? this.enginesPath,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      isFetchingEngines: isFetchingEngines ?? this.isFetchingEngines,
      availableEngines: availableEngines ?? this.availableEngines,
      selectedEngine: selectedEngine ?? this.selectedEngine,
      availableDevices: availableDevices ?? this.availableDevices,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      serverLogs: serverLogs ?? this.serverLogs,
      installedEngineName: installedEngineName ?? this.installedEngineName,
      isEngineVerified: isEngineVerified ?? this.isEngineVerified,
      isDownloadingBundle: isDownloadingBundle ?? this.isDownloadingBundle,
      bundleProgress: bundleProgress ?? this.bundleProgress,
      bundleStatus: bundleStatus ?? this.bundleStatus,
      isInstructInstalled: isInstructInstalled ?? this.isInstructInstalled,
      isEmbeddingInstalled: isEmbeddingInstalled ?? this.isEmbeddingInstalled,
      isRerankerInstalled: isRerankerInstalled ?? this.isRerankerInstalled,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      isConfigReady: isConfigReady ?? this.isConfigReady,
      configPath: configPath ?? this.configPath,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      isSettingsLoaded: isSettingsLoaded ?? this.isSettingsLoaded,
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
      modelsPath: prefs.getString('modelsPath') ?? await _downloader.getModelsDirectory(),
      enginesPath: await _downloader.getEngineDirectory(),
      selectedEngine: prefs.getString('selectedEngine'),
      selectedDeviceId: prefs.getString('selectedDeviceId') ?? 'cpu',
      configPath: await _downloader.getConfigPath(),
      isSetupComplete: prefs.getBool('isSetupComplete') ?? false,
      isSettingsLoaded: true,
    );
    
    fetchModels();
    fetchEngines();

    // Verify engine + config integrity on disk
    await verifyEngineIntegrity();
    await verifyConfig();

    if (state.selectedEngine != null && state.isEngineVerified) {
      fetchDevices();
    }
  }

  // ─── Filesystem Verification ───────────────────────────────────

  Future<void> verifyEngineIntegrity() async {
    final installed = await _downloader.getInstalledEngineNames();
    
    if (installed.isEmpty) {
      state = state.copyWith(
        installedEngineName: null,
        isEngineVerified: false,
      );
      return;
    }

    final engineName = installed.first;
    state = state.copyWith(
      installedEngineName: engineName,
      isEngineVerified: true,
    );

    // Verify model files on disk
    final modelsDir = await _downloader.getModelsDirectory();
    state = state.copyWith(
      isInstructInstalled: await File(p.join(modelsDir, 'Qwen3-4B-Instruct-2507-UD-Q4_K_XL.gguf')).exists(),
      isEmbeddingInstalled: await File(p.join(modelsDir, 'Qwen3-Embedding-0.6B-Q8_0.gguf')).exists(),
      isRerankerInstalled: await File(p.join(modelsDir, 'qwen3-reranker-0.6b-q8_0.gguf')).exists(),
    );
  }

  Future<void> verifyConfig() async {
    final exists = await _downloader.configExists();
    state = state.copyWith(isConfigReady: exists);
  }

  // ─── Server Lifecycle ──────────────────────────────────────────

  Future<void> startServer() async {
    if (state.selectedEngine == null || !state.isEngineVerified) {
      appendLog('Cannot start: No verified engine found.');
      return;
    }

    if (!state.isInstructInstalled || !state.isEmbeddingInstalled || !state.isRerankerInstalled) {
      appendLog('Cannot start: One or more models are missing. Please download the Qwen3 bundle.');
      return;
    }

    // Auto-generate config if missing
    if (!state.isConfigReady) {
      appendLog('Config not found. Generating default config...');
      await _downloader.generateDefaultConfig();
      await verifyConfig();
    }

    try {
      appendLog('Starting server...');
      state = state.copyWith(isServerRunning: true);

      final process = await _downloader.startServer(
        engineName: state.selectedEngine!,
        deviceId: state.selectedDeviceId ?? 'cpu',
        onLog: (line) => appendLog(line),
      );

      // Monitor process exit
      process.exitCode.then((code) {
        appendLog('--- Server exited with code $code ---');
        state = state.copyWith(isServerRunning: false);
      });

      // Give the server a moment to bind to the port, then fetch models
      Future.delayed(const Duration(seconds: 2), () {
        if (state.isServerRunning) {
          fetchModels();
        }
      });
    } catch (e) {
      appendLog('Failed to start server: $e');
      state = state.copyWith(isServerRunning: false);
    }
  }

  Future<void> stopServer() async {
    appendLog('Stopping server...');
    await _downloader.stopServer();
    state = state.copyWith(isServerRunning: false);
    appendLog('Server stopped.');
  }

  // ─── Config Management ─────────────────────────────────────────

  Future<void> openConfig() async {
    await _downloader.openConfigFile();
  }

  Future<void> resetConfig() async {
    await _downloader.resetConfig();
    await verifyConfig();
    appendLog('Config reset to default.');
  }

  // ─── Device & Folder Management ────────────────────────────────

  Future<void> fetchDevices() async {
    if (state.selectedEngine == null) return;
    
    if (!state.isEngineVerified) {
      await verifyEngineIntegrity();
      if (!state.isEngineVerified) return;
    }

    final result = await _downloader.listAvailableDevices(state.selectedEngine!);
    
    appendLog('--- Hardware Device Audit ---');
    appendLog(result.rawOutput);
    state = state.copyWith(availableDevices: result.devices);

    final deviceExists = state.availableDevices.any((d) => d.id == state.selectedDeviceId);
    if (!deviceExists) {
      setSelectedDevice('cpu');
    }
  }

  Future<void> setSelectedDevice(String devId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedDeviceId', devId);
    state = state.copyWith(selectedDeviceId: devId);
  }

  Future<void> openEngineFolder() async {
    await _downloader.openEngineFolder();
  }

  Future<void> openModelsFolder() async {
    await _downloader.openModelsFolder();
  }

  void appendLog(String log) {
    final newLogs = List<String>.from(state.serverLogs);
    newLogs.add(log);
    if (newLogs.length > 1000) {
      newLogs.removeAt(0);
    }
    state = state.copyWith(serverLogs: newLogs);
  }

  void clearLogs() {
    state = state.copyWith(serverLogs: const []);
  }

  // ─── Engine Download ───────────────────────────────────────────

  Future<void> fetchEngines() async {
    state = state.copyWith(isFetchingEngines: true);
    final engines = await _downloader.fetchAvailableEngines();
    await verifyEngineIntegrity();
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

      await _downloader.cleanupLegacyEngines(p.basenameWithoutExtension(asset.name));

      await verifyEngineIntegrity();
      fetchDevices();
    } catch (e) {
      state = state.copyWith(isDownloading: false, downloadStatus: 'Error: $e');
    }
  }

  // ─── Model Bundle Download ─────────────────────────────────────

  Future<void> downloadModelBundle() async {
    state = state.copyWith(
      isDownloadingBundle: true, 
      bundleProgress: 0, 
      bundleStatus: 'Starting bundle download...'
    );

    try {
      await _downloader.downloadModelBundle(
        onProgress: (p) => state = state.copyWith(bundleProgress: p),
        onStatus: (s) => state = state.copyWith(bundleStatus: s),
      );

      final modelsDir = await _downloader.getModelsDirectory();
      
      await updateChatModel(p.join(modelsDir, 'Qwen3-4B-Instruct-2507-UD-Q4_K_XL.gguf'));
      await updateEmbeddingModel(p.join(modelsDir, 'Qwen3-Embedding-0.6B-Q8_0.gguf'));
      await updateRerankModel(p.join(modelsDir, 'qwen3-reranker-0.6b-q8_0.gguf'));

      // Auto-generate config after bundle download
      appendLog('Generating default config (sift_config.ini)...');
      await _downloader.generateDefaultConfig();
      await verifyConfig();
      appendLog('Config ready!');
      
      state = state.copyWith(
        isDownloadingBundle: false, 
        bundleStatus: 'Bundle ready!',
        isInstructInstalled: true,
        isEmbeddingInstalled: true,
        isRerankerInstalled: true,
      );
    } catch (e) {
      state = state.copyWith(
        isDownloadingBundle: false, 
        bundleStatus: 'Error: $e'
      );
    }
  }

  // ─── External Server Connection ────────────────────────────────

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

  // ─── Settings Updates ──────────────────────────────────────────

  Future<void> updateLlamaServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llamaServerUrl', url);
    state = state.copyWith(llamaServerUrl: url);
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
    
    // If switching to internal, default the URL and refresh
    if (type == BackendType.internal) {
      await updateLlamaServerUrl('http://localhost:8080');
    }
    
    state = state.copyWith(backendType: type);
  }

  Future<void> updateGpuDeviceIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gpuDeviceIndex', index);
    state = state.copyWith(gpuDeviceIndex: index);
  }

  Future<void> completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSetupComplete', true);
    state = state.copyWith(isSetupComplete: true);
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
