import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// A portable key-value store that saves settings as JSON
/// in the same directory as the application executable.
/// Drop-in replacement for SharedPreferences with the same API.
class PortableSettings {
  static PortableSettings? _instance;
  final Map<String, dynamic> _data;
  final File _file;

  PortableSettings._(this._data, this._file);

  static Future<PortableSettings> getInstance() async {
    if (_instance != null) return _instance!;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final dataDir = Directory(p.join(exeDir, 'data'));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    final file = File(p.join(dataDir.path, 'sift_settings.json'));

    Map<String, dynamic> data = {};
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        // Corrupted file — start fresh
        data = {};
      }
    }

    _instance = PortableSettings._(data, file);
    return _instance!;
  }

  Future<void> _save() async {
    await _file.writeAsString(jsonEncode(_data));
  }

  // ─── Getters ──────────────────────────────────────────────────

  String? getString(String key) => _data[key] as String?;
  int? getInt(String key) => _data[key] as int?;
  double? getDouble(String key) => _data[key] as double?;
  bool? getBool(String key) => _data[key] as bool?;

  // ─── Setters ──────────────────────────────────────────────────

  Future<void> setString(String key, String value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setInt(String key, int value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setDouble(String key, double value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> setBool(String key, bool value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> remove(String key) async {
    _data.remove(key);
    await _save();
  }
}
