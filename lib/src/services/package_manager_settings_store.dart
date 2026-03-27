import 'dart:convert';
import 'dart:io';

class PackageManagerSettingsStore {
  const PackageManagerSettingsStore();

  Future<Set<String>?> loadVisibleManagerIds() async {
    try {
      final decoded = await _loadSettings();
      if (decoded == null) {
        return null;
      }

      final values = decoded['visibleManagerIds'];
      if (values is! List) {
        return null;
      }

      return values
          .map((value) => '$value'.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveVisibleManagerIds(Set<String> managerIds) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['visibleManagerIds'] = managerIds.toList()..sort();
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<List<String>> loadManagerOrderIds() async {
    try {
      final decoded = await _loadSettings();
      final values = decoded?['managerOrderIds'];
      if (values is! List) {
        return const <String>[];
      }
      return values
          .map((value) => '$value'.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> saveManagerOrderIds(List<String> managerIds) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['managerOrderIds'] = managerIds
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<Map<String, String>> loadCustomManagerIconPaths() async {
    try {
      final decoded = await _loadSettings();
      if (decoded == null) {
        return const <String, String>{};
      }

      final values = decoded['customManagerIconPaths'];
      if (values is! Map<String, dynamic>) {
        return const <String, String>{};
      }

      final output = <String, String>{};
      for (final entry in values.entries) {
        final key = entry.key.trim();
        final value = '${entry.value}'.trim();
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        output[key] = value;
      }
      return output;
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<void> saveCustomManagerIconPaths(Map<String, String> iconPaths) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['customManagerIconPaths'] = <String, String>{
        for (final entry in iconPaths.entries)
          if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
            entry.key: entry.value,
      };
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<Map<String, String>> loadCustomManagerDisplayNames() async {
    try {
      final decoded = await _loadSettings();
      if (decoded == null) {
        return const <String, String>{};
      }

      final values = decoded['customManagerDisplayNames'];
      if (values is! Map<String, dynamic>) {
        return const <String, String>{};
      }

      final output = <String, String>{};
      for (final entry in values.entries) {
        final key = entry.key.trim();
        final value = '${entry.value}'.trim();
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        output[key] = value;
      }
      return output;
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<void> saveCustomManagerDisplayNames(
    Map<String, String> displayNames,
  ) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['customManagerDisplayNames'] = <String, String>{
        for (final entry in displayNames.entries)
          if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
            entry.key: entry.value,
      };
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<String?> loadThemeModeName() async {
    try {
      final decoded = await _loadSettings();
      final value = '${decoded?['themeMode'] ?? ''}'.trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveThemeModeName(String themeMode) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['themeMode'] = themeMode.trim();
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<String?> loadCustomFontFamily() async {
    try {
      final decoded = await _loadSettings();
      final value = '${decoded?['customFontFamily'] ?? ''}'.trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCustomFontFamily(String? fontFamily) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      final trimmed = fontFamily?.trim() ?? '';
      if (trimmed.isEmpty) {
        payload.remove('customFontFamily');
      } else {
        payload['customFontFamily'] = trimmed;
      }
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<List<String>> loadCustomFallbackFontFamilies() async {
    try {
      final decoded = await _loadSettings();
      final values = decoded?['customFallbackFontFamilies'];
      if (values is! List) {
        return const <String>[];
      }
      return values
          .map((value) => '$value'.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> saveCustomFallbackFontFamilies(List<String> fontFamilies) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['customFallbackFontFamilies'] = fontFamilies
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<Map<String, dynamic>?> _loadSettings() async {
    final file = await _resolveFile();
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  Future<void> _saveSettings(Map<String, dynamic> payload) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));
  }

  Future<File> _resolveFile() async {
    final basePath =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final directory = Directory('$basePath${Platform.pathSeparator}pkg_panel');
    return File(
      '${directory.path}${Platform.pathSeparator}manager_settings.json',
    );
  }
}
