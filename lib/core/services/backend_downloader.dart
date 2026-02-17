import 'dart:io';
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
  final String id; // e.g., "Vulkan0"
  final String name; // e.g., "NVIDIA GeForce RTX 3050 Ti"
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

  Future<List<GitHubAsset>> fetchAvailableEngines() async {
    try {
      final response = await _dio.get('https://api.github.com/repos/$_repo/releases/latest');
      if (response.statusCode == 200) {
        final List<dynamic> assetsJson = response.data['assets'];
        final List<GitHubAsset> allAssets = assetsJson.map((json) => GitHubAsset.fromJson(json)).toList();

        // Detect OS and filter
        final String osName = Platform.isWindows ? 'win' : Platform.isLinux ? 'ubuntu' : Platform.isMacOS ? 'macos' : '';
        if (osName.isEmpty) return [];

        return allAssets.where((asset) {
          final name = asset.name.toLowerCase();
          // Filter for Vulkan binaries specifically
          return name.contains('-bin-') && 
                 name.contains(osName) && 
                 name.contains('vulkan') &&
                 (name.endsWith('.zip') || name.endsWith('.tar.gz'));
        }).toList();
      }
    } catch (e) {
      // Log error silently or handle it
    }
    return [];
  }

  Future<String> getEngineDirectory() async {
    // Portable Mode: Store 'engines' folder next to the app executable
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final engineDir = p.join(exeDir, 'engines');
    final dir = Directory(engineDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return engineDir;
  }

  Future<String> getModelsDirectory() async {
    // Portable Mode: Store 'models' folder next to the app executable
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final modelsDir = p.join(exeDir, 'models');
    final dir = Directory(modelsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<void> cleanupLegacyEngines(String currentEngineName) async {
    try {
      final engineDir = await getEngineDirectory();
      final dir = Directory(engineDir);
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            // Delete if it's not the currently selected engine
            if (name != currentEngineName && name != 'temp_download') {
              await entity.delete(recursive: true);
            }
          }
        }
      }
    } catch (e) {
      // Log cleanup error silently
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

      // Simple parsing logic for "Available devices:"
      final lines = rawOutput.split('\n');
      bool inAvailableDevices = false;

      for (var line in lines) {
        if (line.contains('Available devices:')) {
          inAvailableDevices = true;
          continue;
        }

        if (inAvailableDevices && line.trim().isNotEmpty) {
          // Format e.g.: "  Vulkan1: NVIDIA GeForce RTX 3050 Ti Laptop GPU (3962 MiB, 3367 MiB free)"
          final match = RegExp(r'\s*(Vulkan\d+):\s*([^(\n]+)').firstMatch(line);
          if (match != null) {
            final id = match.group(1)!;
            final name = match.group(2)!.trim();
            // Case-insensitive ID check to prevent duplicates
            if (!devices.any((d) => d.id == id)) {
              devices.add(DeviceInfo(
                id: id,
                name: name,
                isGpu: true,
              ));
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

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    if (Platform.isWindows) {
      await Process.run('explorer.exe', [engineDir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [engineDir]);
    } else    if (Platform.isMacOS) {
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

    // Check one level deep (standard for llama.cpp releases)
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

  Future<void> downloadAndExtract(
    GitHubAsset asset, {
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    final engineDir = await getEngineDirectory();
    final tempPath = p.join(engineDir, 'temp_download${p.extension(asset.name)}');
    final extractPath = p.join(engineDir, p.basenameWithoutExtension(asset.name));

    try {
      // Clean start: Wipe existing engine folder if present
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
            // Use system tar for reliable symlink and permission handling
            final res = await Process.run('tar', ['-xzf', tempPath, '-C', extractPath]);
            if (res.exitCode != 0) {
              throw Exception('System tar failed: ${res.stderr}');
            }
          } catch (e) {
            // Fallback to Dart archive package (might lose symlinks)
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
          // Windows or other: Fallback to Dart archive package
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


      // Set execution permissions for Linux/macOS
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
            // Aggregate progress: each model is 1/3 of total
            double aggregateProgress = (i + currentFileProgress) / models.length;
            onProgress(aggregateProgress);
          }
        },
      );
    }
    onStatus('Model bundle downloaded successfully!');
  }
}
