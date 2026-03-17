import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import '../../../../../core/services/embedding_service.dart';
import '../../../../../core/services/portable_settings.dart';
import '../../../../../core/models/ai_models.dart';
import '../../../../../core/services/backend_downloader.dart';
import '../../../../../core/services/model_platform_service.dart';
import '../../../../../core/services/embedding_platform_service.dart';

enum BackendType { external, internal }
enum ModelBundleSize { standard4B, fast2B }

class SettingsState {
  final String llamaServerUrl;
  final String externalLlamaServerUrl;
  final String chatModel;
  final String embeddingModel;
  final String rerankModel;

  // Auto-detected embedding dimension
  final int? detectedEmbeddingDimension;
  final int chunkSize;
  final int chunkOverlap;
  final bool isSyncEnabled;
  final VisualizerMode visualizerMode;
  final CoderMode coderMode;
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
  // Preferences
  final bool autoStartServer;
  final String? engineFetchError;
  // Mobile AI Engine
  final String mobileGenModelPath;
  final String mobileEmbedModelPath;
  final String mobileTokenizerPath;
  final bool mobileUseGpu;
  final bool isMobileEngineInitialized;
  final bool isMobileEmbedderInitialized;
  final double mobileImportProgress;
  final bool isInitializingMobileEngine;
  final String? mobileEngineError;
  final bool autoInitMobileEngine;
  final bool isDownloadingMobileBundle;
  final double mobileBundleProgress;
  final String mobileBundleStatus;
  final bool isMobileBundleInstalled;
  final bool isBrainstormMode;
  final ModelBundleSize selectedBundleSize;

  const SettingsState({
    this.llamaServerUrl = 'http://localhost:8080',
    this.externalLlamaServerUrl = 'http://localhost:8080',
    this.chatModel = '',
    this.embeddingModel = '',
    this.rerankModel = '',
    this.detectedEmbeddingDimension,
    this.chunkSize = 100,
    this.chunkOverlap = 50,
    this.isSyncEnabled = true,
    this.visualizerMode = VisualizerMode.auto,
    this.coderMode = CoderMode.auto,
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
    this.autoStartServer = true,
    this.engineFetchError,
    this.mobileGenModelPath = '',
    this.mobileEmbedModelPath = '',
    this.mobileTokenizerPath = '',
    this.mobileUseGpu = false,
    this.isMobileEngineInitialized = false,
    this.isMobileEmbedderInitialized = false,
    this.mobileImportProgress = 0.0,
    this.isInitializingMobileEngine = false,
    this.mobileEngineError,
    this.autoInitMobileEngine = true,
    this.isDownloadingMobileBundle = false,
    this.mobileBundleProgress = 0.0,
    this.mobileBundleStatus = '',
    this.isMobileBundleInstalled = false,
    this.isBrainstormMode = false,
    this.selectedBundleSize = ModelBundleSize.standard4B,
  });

  bool get isMobileInternal => (Platform.isAndroid || Platform.isIOS) && backendType == BackendType.internal;

  String get chatModelDisplay {
    if (isMobileInternal) {
      if (mobileGenModelPath.isEmpty) return 'No Model Selected';
      final fileName = p.basename(mobileGenModelPath);
      return fileName.replaceAll('.task', '').replaceAll('.litertlm', '');
    }
    return chatModel.isEmpty ? 'Select Model' : chatModel;
  }

  SettingsState copyWith({
    String? llamaServerUrl,
    String? externalLlamaServerUrl,
    String? chatModel,
    String? embeddingModel,
    String? rerankModel,
    int? detectedEmbeddingDimension,
    int? chunkSize,
    int? chunkOverlap,
    bool? isSyncEnabled,
    VisualizerMode? visualizerMode,
    CoderMode? coderMode,
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
    bool? autoStartServer,
    String? engineFetchError,
    String? mobileGenModelPath,
    String? mobileEmbedModelPath,
    String? mobileTokenizerPath,
    bool? mobileUseGpu,
    bool? isMobileEngineInitialized,
    bool? isMobileEmbedderInitialized,
    double? mobileImportProgress,
    bool? isInitializingMobileEngine,
    String? mobileEngineError,
    bool? autoInitMobileEngine,
    bool? isDownloadingMobileBundle,
    double? mobileBundleProgress,
    String? mobileBundleStatus,
    bool? isMobileBundleInstalled,
    bool? isBrainstormMode,
    ModelBundleSize? selectedBundleSize,
  }) {
    return SettingsState(
      llamaServerUrl: llamaServerUrl ?? this.llamaServerUrl,
      externalLlamaServerUrl: externalLlamaServerUrl ?? this.externalLlamaServerUrl,
      chatModel: chatModel ?? this.chatModel,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      rerankModel: rerankModel ?? this.rerankModel,
      detectedEmbeddingDimension: detectedEmbeddingDimension ?? this.detectedEmbeddingDimension,
      chunkSize: chunkSize ?? this.chunkSize,
      chunkOverlap: chunkOverlap ?? this.chunkOverlap,
      isSyncEnabled: isSyncEnabled ?? this.isSyncEnabled,
      visualizerMode: visualizerMode ?? this.visualizerMode,
      coderMode: coderMode ?? this.coderMode,
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
      autoStartServer: autoStartServer ?? this.autoStartServer,
      engineFetchError: engineFetchError ?? this.engineFetchError,
      mobileGenModelPath: mobileGenModelPath ?? this.mobileGenModelPath,
      mobileEmbedModelPath: mobileEmbedModelPath ?? this.mobileEmbedModelPath,
      mobileTokenizerPath: mobileTokenizerPath ?? this.mobileTokenizerPath,
      mobileUseGpu: mobileUseGpu ?? this.mobileUseGpu,
      isMobileEngineInitialized: isMobileEngineInitialized ?? this.isMobileEngineInitialized,
      isMobileEmbedderInitialized: isMobileEmbedderInitialized ?? this.isMobileEmbedderInitialized,
      mobileImportProgress: mobileImportProgress ?? this.mobileImportProgress,
      isInitializingMobileEngine: isInitializingMobileEngine ?? this.isInitializingMobileEngine,
      mobileEngineError: mobileEngineError ?? this.mobileEngineError,
      autoInitMobileEngine: autoInitMobileEngine ?? this.autoInitMobileEngine,
      isDownloadingMobileBundle: isDownloadingMobileBundle ?? this.isDownloadingMobileBundle,
      mobileBundleProgress: mobileBundleProgress ?? this.mobileBundleProgress,
      mobileBundleStatus: mobileBundleStatus ?? this.mobileBundleStatus,
      isMobileBundleInstalled: isMobileBundleInstalled ?? this.isMobileBundleInstalled,
      isBrainstormMode: isBrainstormMode ?? this.isBrainstormMode,
      selectedBundleSize: selectedBundleSize ?? this.selectedBundleSize,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  final Ref _ref;
  final Dio _dio = Dio();
  final BackendDownloader _downloader = BackendDownloader();
  BackendDownloader get downloader => _downloader;

  final ModelPlatformService _modelPlatform = ModelPlatformService();
  final EmbeddingPlatformService _embeddingPlatform = EmbeddingPlatformService();

  SettingsController(this._ref) : super(const SettingsState()) {
    _loadSettings();
    _setupProgressHandlers();
  }

  void _setupProgressHandlers() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    
    _modelPlatform.progressStream.listen((progress) {
      state = state.copyWith(mobileImportProgress: progress);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await PortableSettings.getInstance();
    final url = prefs.getString('llamaServerUrl') ?? 'http://localhost:8080';
    final externalUrl = prefs.getString('externalLlamaServerUrl') ?? url;
    
    state = state.copyWith(
      llamaServerUrl: url,
      externalLlamaServerUrl: externalUrl,
      chatModel: prefs.getString('chatModel') ?? '',
      embeddingModel: prefs.getString('embeddingModel') ?? '',
      rerankModel: prefs.getString('rerankModel') ?? '',
      chunkSize: prefs.getInt('chunkSize') ?? 100,
      chunkOverlap: prefs.getInt('chunkOverlap') ?? 50,
      isSyncEnabled: prefs.getBool('isSyncEnabled') ?? true,
      visualizerMode: VisualizerMode.values[prefs.getInt('visualizerMode') ?? 0],
      coderMode: CoderMode.values[prefs.getInt('coderMode') ?? 0],
      backendType: BackendType.values[prefs.getInt('backendType') ?? 0],
      gpuDeviceIndex: prefs.getInt('gpuDeviceIndex') ?? 0,
      modelsPath: prefs.getString('modelsPath') ?? await _downloader.getModelsDirectory(),
      enginesPath: await _downloader.getEngineDirectory(),
      selectedEngine: prefs.getString('selectedEngine'),
      selectedDeviceId: prefs.getString('selectedDeviceId') ?? 'cpu',
      configPath: await _downloader.getConfigPath(),
      isSetupComplete: prefs.getBool('isSetupComplete') ?? false,
      autoStartServer: prefs.getBool('autoStartServer') ?? true,
      isSettingsLoaded: true,
      mobileGenModelPath: prefs.getString('mobileGenModelPath') ?? '',
      mobileEmbedModelPath: prefs.getString('mobileEmbedModelPath') ?? '',
      mobileTokenizerPath: prefs.getString('mobileTokenizerPath') ?? '',
      mobileUseGpu: prefs.getBool('mobileUseGpu') ?? false,
      autoInitMobileEngine: prefs.getBool('autoInitMobileEngine') ?? true,
      isBrainstormMode: prefs.getBool('isBrainstormMode') ?? false,
      selectedBundleSize: ModelBundleSize.values[prefs.getInt('selectedBundleSize') ?? 0],
    );
    
    // Auto-init mobile engine if preferred and running on internal backend
    if ((Platform.isAndroid || Platform.isIOS) && 
        state.backendType == BackendType.internal && 
        state.autoInitMobileEngine) {
      if (!state.isMobileEngineInitialized) {
        initializeMobileEngine();
      }
      if (!state.isMobileEmbedderInitialized) {
        initializeMobileEmbedder();
      }
    }
    
    // Verify engine + config integrity on disk (Desktop only)
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      await verifyEngineIntegrity();
      await verifyConfig();
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Auto-detect mobile bundle on startup
      await verifyMobileBundle();
    }

    // Only auto-fetch models if server is expected to be reachable
    if (state.backendType == BackendType.external) {
      fetchModels();
    }
    
    // Auto-start server (Desktop only)
    if (state.autoStartServer && 
        state.backendType == BackendType.internal && 
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS) &&
        state.isEngineVerified && 
        state.isConfigReady && 
        state.isInstructInstalled && 
        state.selectedDeviceId != null) {
      startServer(delaySeconds: 5);
    }

    // Fetch available engines and devices (Desktop only)
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      fetchEngines();
      if (state.selectedEngine != null && state.isEngineVerified) {
        fetchDevices();
      }
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
    final bool has4B = await File(p.join(modelsDir, 'Qwen3.5-4B-Q4_K_M.gguf')).exists();
    final bool has2B = await File(p.join(modelsDir, 'Qwen3.5-2B-Q4_K_M.gguf')).exists();

    state = state.copyWith(
      isInstructInstalled: has4B || has2B,
      isEmbeddingInstalled: await File(p.join(modelsDir, 'Qwen3-Embedding-0.6B-Q8_0.gguf')).exists(),
      isRerankerInstalled: await File(p.join(modelsDir, 'qwen3-reranker-0.6b-q8_0.gguf')).exists(),
    );
  }

  Future<void> verifyConfig() async {
    final exists = await _downloader.configExists();
    state = state.copyWith(isConfigReady: exists);
  }

  Future<void> verifyMobileBundle() async {
    final modelsDir = await _downloader.getModelsDirectory();
    final genPath = p.join(modelsDir, 'gemma3-1b-it-int4.litertlm');
    final embedPath = p.join(modelsDir, 'embeddinggemma-300M_seq512_mixed-precision.tflite');
    final tokenizerPath = p.join(modelsDir, 'sentencepiece.model');

    final bool genExists = await File(genPath).exists();
    final bool embedExists = await File(embedPath).exists();
    final bool tokenizerExists = await File(tokenizerPath).exists();

    final bool allInstalled = genExists && embedExists && tokenizerExists;

    state = state.copyWith(isMobileBundleInstalled: allInstalled);

    if (allInstalled) {
      // Auto-configure paths if they are empty
      final prefs = await PortableSettings.getInstance();
      bool changed = false;

      if (state.mobileGenModelPath.isEmpty) {
        await prefs.setString('mobileGenModelPath', genPath);
        state = state.copyWith(mobileGenModelPath: genPath);
        changed = true;
      }
      if (state.mobileEmbedModelPath.isEmpty) {
        await prefs.setString('mobileEmbedModelPath', embedPath);
        state = state.copyWith(mobileEmbedModelPath: embedPath);
        changed = true;
      }
      if (state.mobileTokenizerPath.isEmpty) {
        await prefs.setString('mobileTokenizerPath', tokenizerPath);
        state = state.copyWith(mobileTokenizerPath: tokenizerPath);
        changed = true;
      }

      if (changed && state.autoInitMobileEngine && state.backendType == BackendType.internal) {
        initializeMobileEngine();
        initializeMobileEmbedder();
      }
    }
  }

  // ─── Server Lifecycle ──────────────────────────────────────────

  Future<void> startServer({int delaySeconds = 2}) async {
    if (Platform.isAndroid || Platform.isIOS) return; // LiteRT handles its own lifecycle on mobile

    if (state.selectedEngine == null || !state.isEngineVerified) {
      appendLog('Cannot start: No verified engine found.');
      return;
    }

    if (!state.isInstructInstalled || !state.isEmbeddingInstalled || !state.isRerankerInstalled) {
      appendLog('Cannot start: One or more models are missing. Please download the model bundle.');
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
      Future.delayed(Duration(seconds: delaySeconds), () {
        if (state.isServerRunning) {
          fetchModels();
        }
      });
    } catch (e) {
      appendLog('Failed to start server: $e');
      state = state.copyWith(isServerRunning: false, availableModels: []);
    }
  }

  Future<void> stopServer() async {
    appendLog('Stopping server...');
    await _downloader.stopServer();
    state = state.copyWith(isServerRunning: false, availableModels: []);
    appendLog('Server stopped.');
  }

  // ─── Config Management ─────────────────────────────────────────

  Future<void> openConfig() async {
    await _downloader.openConfigFile();
  }

  Future<void> resetConfig() async {
    await _downloader.resetConfig(
      instructPath: state.chatModel,
      embeddingPath: state.embeddingModel,
      rerankerPath: state.rerankModel,
    );
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
    final prefs = await PortableSettings.getInstance();
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

  Future<void> fetchEngines({bool forceRefresh = false}) async {
    if (Platform.isAndroid || Platform.isIOS) return; // Engines (llama-server) are not for mobile

    state = state.copyWith(isFetchingEngines: true, engineFetchError: null);
    try {
      final engines = await _downloader.fetchAvailableEngines(forceRefresh: forceRefresh);
      await verifyEngineIntegrity();
      state = state.copyWith(availableEngines: engines, isFetchingEngines: false);
    } catch (e) {
      state = state.copyWith(
        availableEngines: [],
        isFetchingEngines: false,
        engineFetchError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setSelectedEngine(String name) {
    state = state.copyWith(selectedEngine: name);
  }

  Future<void> downloadEngine(GitHubAsset asset) async {
    state = state.copyWith(isDownloading: true, downloadProgress: 0, downloadStatus: 'Preparing...');
    try {
      await _downloader.downloadAndExtract(
        asset,
        onProgress: (p) => state = state.copyWith(downloadProgress: p),
        onStatus: (s) => state = state.copyWith(downloadStatus: s),
      );
      
      final prefs = await PortableSettings.getInstance();
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
        isFast: state.selectedBundleSize == ModelBundleSize.fast2B,
        onProgress: (p) => state = state.copyWith(bundleProgress: p),
        onStatus: (s) => state = state.copyWith(bundleStatus: s),
      );

      final modelsDir = await _downloader.getModelsDirectory();
      final modelFile = state.selectedBundleSize == ModelBundleSize.fast2B 
          ? 'Qwen3.5-2B-Q4_K_M.gguf' 
          : 'Qwen3.5-4B-Q4_K_M.gguf';
      
      await updateChatModel(p.join(modelsDir, modelFile));
      await updateEmbeddingModel(p.join(modelsDir, 'Qwen3-Embedding-0.6B-Q8_0.gguf'));
      await updateRerankModel(p.join(modelsDir, 'qwen3-reranker-0.6b-q8_0.gguf'));

      // Auto-generate config after bundle download with specific model paths
      appendLog('Generating default config (sift_config.ini)...');
      await _downloader.generateDefaultConfig(
        instructPath: p.join(modelsDir, modelFile),
        embeddingPath: p.join(modelsDir, 'Qwen3-Embedding-0.6B-Q8_0.gguf'),
        rerankerPath: p.join(modelsDir, 'qwen3-reranker-0.6b-q8_0.gguf'),
      );
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
    // For internal mode, always use the known port; for external, use the saved URL
    final serverUrl = state.backendType == BackendType.internal
        ? 'http://localhost:8080'
        : state.llamaServerUrl;
    if (serverUrl.isEmpty) return;
    // Don't attempt connection if internal server isn't running
    if (state.backendType == BackendType.internal && !state.isServerRunning) return;
    
    state = state.copyWith(isLoadingModels: true, error: null);
    
    try {
      final response = await _dio.get('$serverUrl/v1/models');
      
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

          // Auto-select bundled models if in Internal mode
          if (state.backendType == BackendType.internal) {
            final instruct = models.firstWhere((m) => m.contains('Instruct'), orElse: () => '');
            final embedding = models.firstWhere((m) => m.contains('Embedding'), orElse: () => '');
            final reranker = models.firstWhere((m) => m.toLowerCase().contains('reranker'), orElse: () => '');

            if (instruct.isNotEmpty) await updateChatModel(instruct);
            if (embedding.isNotEmpty) await updateEmbeddingModel(embedding);
            if (reranker.isNotEmpty) await updateRerankModel(reranker);
          }
          
          // Trigger dimension detection after fetching models if one is selected
          _detectEmbeddingDimension();
        }
      } else {
         state = state.copyWith(
            isLoadingModels: false, 
            error: 'Failed to fetch models: ${response.statusCode}'
         );
      }
    } catch (e) {
      appendLog('Connection error (fetchModels): $e');
      state = state.copyWith(
        isLoadingModels: false,
        availableModels: [],
        // error: 'Connection error: $e', // Silencing false error reports
      );
    }
  }

  // ─── Settings Updates ──────────────────────────────────────────

  Future<void> updateLlamaServerUrl(String url) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setString('llamaServerUrl', url);
    
    if (state.backendType == BackendType.external) {
      await prefs.setString('externalLlamaServerUrl', url);
      state = state.copyWith(llamaServerUrl: url, externalLlamaServerUrl: url, error: null);
    } else {
      state = state.copyWith(llamaServerUrl: url, error: null);
    }
  }

  Future<void> updateChatModel(String model) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setString('chatModel', model);
    state = state.copyWith(chatModel: model);
  }

  Future<void> updateEmbeddingModel(String model) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setString('embeddingModel', model);
    state = state.copyWith(embeddingModel: model, detectedEmbeddingDimension: null); // Reset dimension on model change
    _detectEmbeddingDimension();
  }

  Future<void> _detectEmbeddingDimension() async {
    if (state.embeddingModel.isEmpty) return;
    
    // Only attempt if it's external mode or if the internal server is running
    final isRunning = state.backendType == BackendType.external || state.isServerRunning;
    if (!isRunning) return;

    try {
      // Small delay to ensure the server has time to switch models if needed
      await Future.delayed(const Duration(milliseconds: 500));
      
      final embeddingService = _ref.read(embeddingServiceProvider);
      // Run a quick fetch of a single token to determine dimension size
      final embeddings = await embeddingService.getEmbeddings(['test']);
      if (embeddings.isNotEmpty && embeddings.first.isNotEmpty) {
        state = state.copyWith(detectedEmbeddingDimension: embeddings.first.length);
      }
    } catch (e) {
      // Ignore errors here, dimension is just a decorative hint for the user
      debugPrint('Could not detect embedding dimension: $e');
    }
  }

  Future<void> updateRerankModel(String model) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setString('rerankModel', model);
    state = state.copyWith(rerankModel: model);
  }

  Future<void> updateChunkSize(int size) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setInt('chunkSize', size);
    state = state.copyWith(chunkSize: size);
  }

  Future<void> updateChunkOverlap(int overlap) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setInt('chunkOverlap', overlap);
    state = state.copyWith(chunkOverlap: overlap);
  }

  Future<void> toggleSync(bool enabled) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setBool('isSyncEnabled', enabled);
    state = state.copyWith(isSyncEnabled: enabled);
  }

  Future<void> updateBrainstormMode(bool value) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setBool('isBrainstormMode', value);
    state = state.copyWith(isBrainstormMode: value);
  }

  Future<void> updateVisualizerMode(VisualizerMode mode) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setInt('visualizerMode', mode.index);
    state = state.copyWith(visualizerMode: mode);
  }

  Future<void> updateCoderMode(CoderMode mode) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setInt('coderMode', mode.index);
    state = state.copyWith(coderMode: mode);
  }

  Future<void> setSelectedBundleSize(ModelBundleSize size) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setInt('selectedBundleSize', size.index);
    state = state.copyWith(selectedBundleSize: size);
  }

  Future<void> updateBackendType(BackendType type) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setInt('backendType', type.index);
    
    // Clear any stale connection errors from the previous mode
    state = state.copyWith(backendType: type, error: null);

    // If switching to internal, default the URL
    if (type == BackendType.internal) {
      await updateLlamaServerUrl('http://localhost:8080');
    } else {
      // Restore user's preferred external URL
      await updateLlamaServerUrl(state.externalLlamaServerUrl);
      // External mode: try to reach the server right away
      fetchModels();
    }
  }

  Future<void> updateGpuDeviceIndex(int index) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setInt('gpuDeviceIndex', index);
    state = state.copyWith(gpuDeviceIndex: index);
  }

  Future<void> completeSetup() async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setBool('isSetupComplete', true);
    state = state.copyWith(isSetupComplete: true);

    // Auto-start server immediately after setup completion if conditions are met
    if (state.autoStartServer && 
        state.backendType == BackendType.internal && 
        state.isEngineVerified && 
        state.isConfigReady && 
        state.isInstructInstalled && 
        state.selectedDeviceId != null) {
      startServer(delaySeconds: 5);
    }
  }

  Future<void> updateModelsPath(String path) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setString('modelsPath', path);
    state = state.copyWith(modelsPath: path);
  }

  Future<void> updateAutoStartServer(bool value) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setBool('autoStartServer', value);
    state = state.copyWith(autoStartServer: value);
  }

  // ─── Mobile AI Engine ──────────────────────────────────────────

  Future<void> updateMobileUseGpu(bool useGpu) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setBool('mobileUseGpu', useGpu);
    state = state.copyWith(mobileUseGpu: useGpu);
    
    // Auto-reinitialize if already initialized to apply GPU change immediately
    if (state.isMobileEngineInitialized) {
      initializeMobileEngine();
    }
  }

  Future<void> pickMobileGenModel() async {
    final path = await _modelPlatform.pickModel();
    if (path != null) {
      final prefs = await PortableSettings.getInstance();
      await prefs.setString('mobileGenModelPath', path);
      state = state.copyWith(mobileGenModelPath: path, isMobileEngineInitialized: false);
    }
  }

  Future<void> updateAutoInitMobileEngine(bool autoInit) async {
    final prefs = await PortableSettings.getInstance();
    await prefs.setBool('autoInitMobileEngine', autoInit);
    state = state.copyWith(autoInitMobileEngine: autoInit);
    
    if (autoInit && state.backendType == BackendType.internal && (Platform.isAndroid || Platform.isIOS)) {
      if (!state.isMobileEngineInitialized) initializeMobileEngine();
      if (!state.isMobileEmbedderInitialized) initializeMobileEmbedder();
    }
  }

  Future<void> downloadMobileModelBundle() async {
    if (state.isDownloadingMobileBundle) return;
    
    state = state.copyWith(
      isDownloadingMobileBundle: true,
      mobileBundleProgress: 0,
      mobileBundleStatus: 'Initializing download...',
    );

    try {
      // Keep device awake during download
      WakelockPlus.enable();
      
      await _downloader.downloadMobileModelBundle(
        onProgress: (progress) {
          state = state.copyWith(mobileBundleProgress: progress);
        },
        onStatus: (status) {
          state = state.copyWith(mobileBundleStatus: status);
        },
      );
      
      // Auto-configure paths
      final modelsDir = await _downloader.getModelsDirectory();
      final prefs = await PortableSettings.getInstance();
      
      final genPath = p.join(modelsDir, 'gemma3-1b-it-int4.litertlm');
      final embedPath = p.join(modelsDir, 'embeddinggemma-300M_seq512_mixed-precision.tflite');
      final tokenizerPath = p.join(modelsDir, 'sentencepiece.model');
      
      await prefs.setString('mobileGenModelPath', genPath);
      await prefs.setString('mobileEmbedModelPath', embedPath);
      await prefs.setString('mobileTokenizerPath', tokenizerPath);
      
      state = state.copyWith(
        mobileGenModelPath: genPath,
        mobileEmbedModelPath: embedPath,
        mobileTokenizerPath: tokenizerPath,
        isDownloadingMobileBundle: false,
        mobileBundleStatus: 'Download complete! Auto-configuring...',
      );
      
      // Refresh bundle status
      await verifyMobileBundle();
      
      // Auto-initialize immediately after download complete
      initializeMobileEngine();
      initializeMobileEmbedder();
      
      // Clear status after delay so the progress bar disappears
      Future.delayed(const Duration(seconds: 3), () {
        state = state.copyWith(mobileBundleStatus: '');
      });
      
    } catch (e) {
      state = state.copyWith(
        isDownloadingMobileBundle: false,
        mobileBundleStatus: 'Download failed: $e',
      );
    } finally {
      // Re-enable sleep
      WakelockPlus.disable();
    }
  }

  Future<void> pickMobileEmbedModel() async {
    final path = await _modelPlatform.pickModel();
    if (path != null) {
      final prefs = await PortableSettings.getInstance();
      await prefs.setString('mobileEmbedModelPath', path);
      state = state.copyWith(mobileEmbedModelPath: path, isMobileEmbedderInitialized: false);
    }
  }

  Future<void> pickMobileTokenizer() async {
    final path = await _modelPlatform.pickModel();
    if (path != null) {
      final prefs = await PortableSettings.getInstance();
      await prefs.setString('mobileTokenizerPath', path);
      state = state.copyWith(mobileTokenizerPath: path, isMobileEmbedderInitialized: false);
    }
  }

  Future<void> clearMobileTokenizer() async {
    final prefs = await PortableSettings.getInstance();
    await prefs.remove('mobileTokenizerPath');
    state = state.copyWith(mobileTokenizerPath: '', isMobileEmbedderInitialized: false);
  }

  Future<void> resetMobileSettings() async {
    final modelsDir = await _downloader.getModelsDirectory();
    final genPath = p.join(modelsDir, 'gemma3-1b-it-int4.litertlm');
    final embedPath = p.join(modelsDir, 'embeddinggemma-300M_seq512_mixed-precision.tflite');
    final tokenizerPath = p.join(modelsDir, 'sentencepiece.model');

    final prefs = await PortableSettings.getInstance();
    await prefs.setString('mobileGenModelPath', genPath);
    await prefs.setString('mobileEmbedModelPath', embedPath);
    await prefs.setString('mobileTokenizerPath', tokenizerPath);

    state = state.copyWith(
      mobileGenModelPath: genPath,
      mobileEmbedModelPath: embedPath,
      mobileTokenizerPath: tokenizerPath,
      isMobileEngineInitialized: false,
      isMobileEmbedderInitialized: false,
    );
    
    if (state.autoInitMobileEngine && state.backendType == BackendType.internal && (Platform.isAndroid || Platform.isIOS)) {
      initializeMobileEngine();
      initializeMobileEmbedder();
    }
  }

  Future<void> initializeMobileEngine() async {
    if (state.mobileGenModelPath.isEmpty) return;
    
    state = state.copyWith(mobileEngineError: null, isInitializingMobileEngine: true);
    final success = await _modelPlatform.initializeModel(
      state.mobileGenModelPath,
      useGpu: state.mobileUseGpu,
    );
    
    state = state.copyWith(
      isMobileEngineInitialized: success,
      isInitializingMobileEngine: false,
      mobileEngineError: success ? null : 'Failed to initialize LiteRT generation engine',
    );
  }

  Future<void> initializeMobileEmbedder() async {
    if (state.mobileEmbedModelPath.isEmpty) return;
    
    state = state.copyWith(mobileEngineError: null);
    final success = await _embeddingPlatform.initializeEmbeddingModel(
      state.mobileEmbedModelPath,
      tokenizerPath: state.mobileTokenizerPath.isEmpty ? null : state.mobileTokenizerPath,
      useGpu: false, // Force CPU for embedding model as requested
    );
    
    state = state.copyWith(
      isMobileEmbedderInitialized: success,
      mobileEngineError: success ? null : 'Failed to initialize MediaPipe embedding engine',
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref);
});
