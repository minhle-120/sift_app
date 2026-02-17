import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';

class GitHubAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;

  GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'],
      browserDownloadUrl: json['browser_download_url'],
      size: json['size'],
    );
  }
}

class DeviceInfo {
  final String id;
  final String name;
  final bool isGpu;

  DeviceInfo({required this.id, required this.name, required this.isGpu});
}

class AuditResult {
  final List<DeviceInfo> devices;
  final String rawOutput;

  AuditResult({required this.devices, required this.rawOutput});
}

class BackendDownloader {
  final Dio _dio = Dio();
  static const String _repo = 'ggml-org/llama.cpp';
  Process? _serverProcess;

  // ─── Directory Management ──────────────────────────────────────

  Future<String> getEngineDirectory() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final engineDir = p.join(exeDir, 'engines');
    final dir = Directory(engineDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return engineDir;
  }

  Future<String> getModelsDirectory() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final modelsDir = p.join(exeDir, 'models');
    final dir = Directory(modelsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return modelsDir;
  }

  // ─── Config File Management ────────────────────────────────────

  Future<String> getConfigPath() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return p.join(exeDir, 'sift_config.ini');
  }

  Future<bool> configExists() async {
    final configPath = await getConfigPath();
    return File(configPath).exists();
  }

  Future<void> generateDefaultConfig() async {
    final modelsDir = await getModelsDirectory();
    final configPath = await getConfigPath();

    final instructPath = p.join(modelsDir, 'Qwen3-4B-Instruct-2507-UD-Q4_K_XL.gguf');
    final embeddingPath = p.join(modelsDir, 'Qwen3-Embedding-0.6B-Q8_0.gguf');
    final rerankerPath = p.join(modelsDir, 'qwen3-reranker-0.6b-q8_0.gguf');

    final config = '''[*]
flash-attn = on
no-warmup = true
parallel = 1
mlock = true
no-mmap = true

[Qwen3-4B-Instruct-2507]
model = $instructPath
ctx-size = 8192
cache-type-k = q8_0
cache-type-v = q8_0
n-gpu-layers = 99
temp = 0.7
min-p = 0.00
top-p = 0.80
top-k = 20
presence-penalty = 1.0

[Qwen3-Embedding-0.6B]
model = $embeddingPath
embedding = true
ctx-size = 2048
ubatch-size = 2048
batch-size = 2048
n-gpu-layers = 99

[Qwen3-Reranker-0.6B]
model = $rerankerPath
reranking = true
ctx-size = 2048
ubatch-size = 2048
batch-size = 2048
n-gpu-layers = 99
''';

    await File(configPath).writeAsString(config);
  }

  Future<void> resetConfig() async {
    final configPath = await getConfigPath();
    final file = File(configPath);
    if (await file.exists()) {
      await file.delete();
    }
    await generateDefaultConfig();
  }

  Future<void> openConfigFile() async {
    final configPath = await getConfigPath();
    final file = File(configPath);
    if (!await file.exists()) {
      await generateDefaultConfig();
    }

    if (Platform.isWindows) {
      await Process.start('notepad.exe', [configPath]);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [configPath]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [configPath]);
    }
  }

  // ─── Server Lifecycle ──────────────────────────────────────────

  Future<Process> startServer({
    required String engineName,
    required String deviceId,
    required Function(String) onLog,
  }) async {
    final engineDir = await getEngineDirectory();
    final extractPath = p.join(engineDir, p.basenameWithoutExtension(engineName));
    final serverPath = await _findServerBinary(extractPath);

    if (serverPath == null) {
      throw Exception('Engine binary not found in $extractPath');
    }

    // Ensure config exists
    final configPath = await getConfigPath();
    if (!await File(configPath).exists()) {
      await generateDefaultConfig();
    }

    // Build launch arguments
    final args = ['--port', '8080', '--models-max', '1', '--models-preset', configPath];
    if (deviceId != 'cpu') {
      args.addAll(['--device', deviceId]);
    }

    onLog('> ${p.basename(serverPath)} ${args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ')}');

    if (Platform.isWindows) {
      _serverProcess = await Process.start(
        serverPath,
        args,
      );
    } else {
      // Linux/macOS: Use setsid to create a new process group.
      // 'exec' replaces the shell so there's only one process to manage.
      // Killing the process group (-PGID) guarantees all children die.
      final quotedArgs = args.map((a) => "'$a'").join(' ');
      _serverProcess = await Process.start(
        'setsid',
        ['/bin/sh', '-c', "exec '${p.absolute(serverPath)}' $quotedArgs"],
        environment: Platform.isLinux ? {
          'LD_LIBRARY_PATH': '${p.dirname(serverPath)}:${p.dirname(p.dirname(serverPath))}',
        } : null,
      );
    }

    // Stream stdout and stderr
    _serverProcess!.stdout.transform(const SystemEncoding().decoder).listen((data) {
      for (final line in data.split('\n')) {
        if (line.trim().isNotEmpty) onLog(line);
      }
    });
    _serverProcess!.stderr.transform(const SystemEncoding().decoder).listen((data) {
      for (final line in data.split('\n')) {
        if (line.trim().isNotEmpty) onLog('[stderr] $line');
      }
    });

    return _serverProcess!;
  }

  Future<void> stopServer() async {
    if (_serverProcess != null) {
      final pid = _serverProcess!.pid;

      if (Platform.isWindows) {
        // /T kills the entire process tree, /F forces it
        Process.runSync('taskkill', ['/F', '/T', '/PID', '$pid']);
      } else {
        // Kill the entire process group (negative PID = group kill)
        // setsid made the server the group leader, so -PID kills it + all children
        Process.runSync('kill', ['--', '-$pid']);
      }

      try {
        await _serverProcess!.exitCode.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Nuclear option: SIGKILL the group
            if (!Platform.isWindows) {
              Process.runSync('kill', ['-9', '--', '-$pid']);
            }
            return -1;
          },
        );
      } catch (_) {}
      _serverProcess = null;
    }
  }

  bool get isServerRunning => _serverProcess != null;

  // ─── GitHub Engine Fetching ────────────────────────────────────

  Future<List<GitHubAsset>> fetchAvailableEngines() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_repo/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200) {
        // Handle both parsed JSON and raw string responses (Windows Dio quirk)
        dynamic data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        final List<dynamic> assetsJson = data['assets'];
        final List<GitHubAsset> allAssets = assetsJson.map((json) => GitHubAsset.fromJson(json)).toList();

        // Determine OS filter keyword
        final String osFilter;
        if (Platform.isWindows) {
          osFilter = '-win-';
        } else if (Platform.isLinux) {
          osFilter = '-ubuntu-';
        } else if (Platform.isMacOS) {
          osFilter = '-macos-';
        } else {
          return [];
        }

        return allAssets.where((asset) {
          final name = asset.name.toLowerCase();
          // Must be a binary release for this OS with Vulkan support
          return name.contains(osFilter) && 
                 name.contains('vulkan') &&
                 (name.endsWith('.zip') || name.endsWith('.tar.gz'));
        }).toList();
      }
    } catch (e) {
      // Silently handle - errors are expected when offline
    }
    return [];
  }

  // ─── Engine Cleanup & Verification ─────────────────────────────

  Future<void> cleanupLegacyEngines(String currentEngineName) async {
    try {
      final engineDir = await getEngineDirectory();
      final dir = Directory(engineDir);
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (name != currentEngineName && name != 'temp_download') {
              await entity.delete(recursive: true);
            }
          }
        }
      }
    } catch (e) {
      // Silently handle
    }
  }

  Future<AuditResult> listAvailableDevices(String engineName) async {
    final List<DeviceInfo> devices = [
      DeviceInfo(id: 'cpu', name: 'CPU Fallback', isGpu: false),
    ];
    String rawOutput = '';

    try {
      final engineDir = await getEngineDirectory();
      final extractPath = p.join(engineDir, p.basenameWithoutExtension(engineName));
      final serverPath = await _findServerBinary(extractPath);

      if (serverPath == null) {
        return AuditResult(devices: devices, rawOutput: 'Engine binary not found in $extractPath');
      }

      final result = await Process.run(
        serverPath, 
        ['--list-devices'],
        environment: Platform.isLinux ? {
          'LD_LIBRARY_PATH': '${p.dirname(serverPath)}:${p.dirname(p.dirname(serverPath))}',
        } : null,
      );
      rawOutput = result.stdout.toString() + result.stderr.toString();

      final lines = rawOutput.split('\n');
      bool inAvailableDevices = false;

      for (var line in lines) {
        if (line.contains('Available devices:')) {
          inAvailableDevices = true;
          continue;
        }

        if (inAvailableDevices && line.trim().isNotEmpty) {
          final match = RegExp(r'\s*(Vulkan\d+):\s*([^(\n]+)').firstMatch(line);
          if (match != null) {
            final id = match.group(1)!;
            final name = match.group(2)!.trim();
            if (!devices.any((d) => d.id == id)) {
              devices.add(DeviceInfo(id: id, name: name, isGpu: true));
            }
          }
        }
      }
    } catch (e) {
      rawOutput = 'Hardware audit failed: $e';
    }

    return AuditResult(devices: devices, rawOutput: rawOutput);
  }

  Future<void> openEngineFolder() async {
    final engineDir = await getEngineDirectory();
    final dir = Directory(engineDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    if (Platform.isWindows) {
      await Process.run('explorer.exe', [engineDir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [engineDir]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [engineDir]);
    }
  }

  Future<void> openModelsFolder() async {
    final modelsDir = await getModelsDirectory();
    final dir = Directory(modelsDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    if (Platform.isWindows) {
      await Process.run('explorer.exe', [modelsDir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [modelsDir]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [modelsDir]);
    }
  }

  Future<bool> isEngineDownloaded(String engineName) async {
    final engineDir = await getEngineDirectory();
    final extractPath = p.join(engineDir, p.basenameWithoutExtension(engineName));
    return (await _findServerBinary(extractPath)) != null;
  }

  Future<List<String>> getInstalledEngineNames() async {
    final engineDir = await getEngineDirectory();
    final dir = Directory(engineDir);
    if (!await dir.exists()) return [];

    final List<String> installed = [];
    final List<FileSystemEntity> entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (await _findServerBinary(entity.path) != null) {
          installed.add(name);
        }
      }
    }
    return installed;
  }

  Future<String?> _findServerBinary(String baseDir) async {
    final dir = Directory(baseDir);
    if (!await dir.exists()) return null;

    final serverExe = Platform.isWindows ? 'llama-server.exe' : 'llama-server';
    
    // Check root
    final rootPath = p.join(baseDir, serverExe);
    if (await File(rootPath).exists()) return rootPath;

    // Check one level deep
    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final subPath = p.join(entity.path, serverExe);
          if (await File(subPath).exists()) return subPath;
        }
      }
    } catch (_) {}

    return null;
  }

  // ─── Download & Extract ────────────────────────────────────────

  Future<void> downloadAndExtract(
    GitHubAsset asset, {
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    final engineDir = await getEngineDirectory();
    final tempPath = p.join(engineDir, 'temp_download${p.extension(asset.name)}');
    final extractPath = p.join(engineDir, p.basenameWithoutExtension(asset.name));

    try {
      final dir = Directory(extractPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);

      onStatus('Downloading ${asset.name}...');
      await _dio.download(
        asset.browserDownloadUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      onStatus('Extracting...');
      final bytes = await File(tempPath).readAsBytes();
      
      if (asset.name.endsWith('.zip')) {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            File(p.join(extractPath, filename))
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else {
            Directory(p.join(extractPath, filename)).createSync(recursive: true);
          }
        }
      } else if (asset.name.endsWith('.tar.gz')) {
        if (Platform.isLinux || Platform.isMacOS) {
          try {
            final res = await Process.run('tar', ['-xzf', tempPath, '-C', extractPath]);
            if (res.exitCode != 0) {
              throw Exception('System tar failed: ${res.stderr}');
            }
          } catch (e) {
            final gzipBytes = GZipDecoder().decodeBytes(bytes);
            final archive = TarDecoder().decodeBytes(gzipBytes);
            for (final file in archive) {
              final filename = file.name;
              final fullPath = p.join(extractPath, filename);
              if (file.isFile) {
                final data = file.content as List<int>;
                File(fullPath)
                  ..createSync(recursive: true)
                  ..writeAsBytesSync(data);
              } else {
                Directory(fullPath).createSync(recursive: true);
              }
            }
          }
        } else {
          final gzipBytes = GZipDecoder().decodeBytes(bytes);
          final archive = TarDecoder().decodeBytes(gzipBytes);
          for (final file in archive) {
            final filename = file.name;
            final fullPath = p.join(extractPath, filename);
            if (file.isFile) {
              final data = file.content as List<int>;
              File(fullPath)
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            } else {
              Directory(fullPath).createSync(recursive: true);
            }
          }
        }
      }

      // Set execution permissions
      if (!Platform.isWindows) {
        final serverPath = await _findServerBinary(extractPath);
        if (serverPath != null) {
          await Process.run('chmod', ['+x', serverPath]);
        }
      }

      onStatus('Ready');
    } catch (e) {
      onStatus('Error: $e');
      rethrow;
    } finally {
      if (await File(tempPath).exists()) {
        await File(tempPath).delete();
      }
    }
  }

  Future<void> downloadModelBundle({
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    final modelsDir = await getModelsDirectory();
    final models = [
      {
        'name': 'Qwen3-4B-Instruct-2507-UD-Q4_K_XL.gguf',
        'url': 'https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-UD-Q4_K_XL.gguf?download=true'
      },
      {
        'name': 'Qwen3-Embedding-0.6B-Q8_0.gguf',
        'url': 'https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/main/Qwen3-Embedding-0.6B-Q8_0.gguf?download=true'
      },
      {
        'name': 'qwen3-reranker-0.6b-q8_0.gguf',
        'url': 'https://huggingface.co/ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/resolve/main/qwen3-reranker-0.6b-q8_0.gguf?download=true'
      },
    ];

    for (int i = 0; i < models.length; i++) {
      final model = models[i];
      final modelPath = p.join(modelsDir, model['name']!);
      
      onStatus('Downloading ${model['name']} (${i + 1}/${models.length})...');
      
      await _dio.download(
        model['url']!,
        modelPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double currentFileProgress = received / total;
            double aggregateProgress = (i + currentFileProgress) / models.length;
            onProgress(aggregateProgress);
          }
        },
      );
    }
    onStatus('Model bundle downloaded successfully!');
  }
}
