import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
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
          // Filter for binaries and skip extra packages like 'cudart' or 'avx' unless they are core
          // We look for name patterns like llama-bXXXX-bin-win-vulkan-x64.zip
          return name.contains('-bin-') && name.contains(osName) && (name.endsWith('.zip') || name.endsWith('.tar.gz'));
        }).toList();
      }
    } catch (e) {
      // Log error silently or handle it
    }
    return [];
  }

  Future<String> getEngineDirectory() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final engineDir = p.join(appSupportDir.path, 'engines');
    final dir = Directory(engineDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return engineDir;
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
        final gzipBytes = GZipDecoder().decodeBytes(bytes);
        final archive = TarDecoder().decodeBytes(gzipBytes);
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
      }

      // Cleanup
      await File(tempPath).delete();
      
      // Set execution permissions for Linux/macOS
      if (!Platform.isWindows) {
        final serverFile = File(p.join(extractPath, 'llama-server'));
        if (await serverFile.exists()) {
           await Process.run('chmod', ['+x', serverFile.path]);
        }
      }

      onStatus('Ready');
    } catch (e) {
      onStatus('Error: $e');
      rethrow;
    }
  }
}
