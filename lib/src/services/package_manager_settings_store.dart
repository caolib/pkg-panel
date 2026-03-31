import 'dart:convert';
import 'dart:io';

import '../models/package_models.dart';

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

  Future<Set<String>?> loadManuallyHiddenManagerIds() async {
    try {
      final decoded = await _loadSettings();
      if (decoded == null || !decoded.containsKey('manuallyHiddenManagerIds')) {
        return null;
      }

      final values = decoded['manuallyHiddenManagerIds'];
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

  Future<void> saveManuallyHiddenManagerIds(Set<String> managerIds) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['manuallyHiddenManagerIds'] = managerIds.toList()..sort();
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

  Future<List<HomeFilterGroup>> loadHomeFilterGroups() async {
    try {
      final decoded = await _loadSettings();
      final values = decoded?['homeFilterGroups'];
      if (values is! List) {
        return const <HomeFilterGroup>[];
      }

      final groups = <HomeFilterGroup>[];
      for (final value in values) {
        if (value is! Map<String, dynamic>) {
          continue;
        }

        final id = '${value['id'] ?? ''}'.trim();
        final kindName = '${value['kind'] ?? ''}'.trim();
        final displayName = '${value['displayName'] ?? ''}'.trim();
        if (id.isEmpty || kindName.isEmpty || displayName.isEmpty) {
          continue;
        }

        final managerIds = (value['managerIds'] is List)
            ? (value['managerIds'] as List)
                  .map((item) => '$item'.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false)
            : const <String>[];
        final packageKeys = (value['packageKeys'] is List)
            ? (value['packageKeys'] as List)
                  .map((item) => '$item'.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false)
            : const <String>[];

        final kind = switch (kindName) {
          'all' => HomeFilterGroupKind.all,
          'updates' => HomeFilterGroupKind.updates,
          'custom' => HomeFilterGroupKind.custom,
          _ => null,
        };
        if (kind == null) {
          continue;
        }

        final iconPath = '${value['iconPath'] ?? ''}'.trim();
        groups.add(
          HomeFilterGroup(
            id: id,
            kind: kind,
            displayName: displayName,
            isVisible: value['isVisible'] != false,
            iconPath: iconPath.isEmpty ? null : iconPath,
            managerIds: managerIds,
            packageKeys: packageKeys,
          ),
        );
      }

      return groups;
    } catch (_) {
      return const <HomeFilterGroup>[];
    }
  }

  Future<void> saveHomeFilterGroups(List<HomeFilterGroup> groups) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['homeFilterGroups'] = groups
          .map(
            (group) => <String, dynamic>{
              'id': group.id,
              'kind': group.kind.name,
              'displayName': group.displayName,
              'isVisible': group.isVisible,
              if (group.iconPath != null && group.iconPath!.trim().isNotEmpty)
                'iconPath': group.iconPath!.trim(),
              'managerIds': group.managerIds,
              'packageKeys': group.packageKeys,
            },
          )
          .toList(growable: false);
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

  Future<String?> loadLocaleCode() async {
    try {
      final decoded = await _loadSettings();
      final value = '${decoded?['localeCode'] ?? ''}'.trim().toLowerCase();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocaleCode(String localeCode) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['localeCode'] = localeCode.trim().toLowerCase();
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<bool> loadAutoCheckAppUpdates() async {
    try {
      final decoded = await _loadSettings();
      final value = decoded?['autoCheckAppUpdates'];
      if (value is bool) {
        return value;
      }
      final normalized = '${value ?? ''}'.trim().toLowerCase();
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveAutoCheckAppUpdates(bool value) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['autoCheckAppUpdates'] = value;
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<bool> loadUseGithubMirrorForDownloads() async {
    try {
      final decoded = await _loadSettings();
      final value = decoded?['useGithubMirrorForDownloads'];
      if (value is bool) {
        return value;
      }
      final normalized = '${value ?? ''}'.trim().toLowerCase();
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveUseGithubMirrorForDownloads(bool value) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      payload['useGithubMirrorForDownloads'] = value;
      await _saveSettings(payload);
    } catch (_) {
      // Best-effort settings persistence.
    }
  }

  Future<String> loadGithubMirrorBaseUrl() async {
    try {
      final decoded = await _loadSettings();
      final value = '${decoded?['githubMirrorBaseUrl'] ?? ''}'.trim();
      return value.isEmpty ? 'https://ghproxy.net/' : value;
    } catch (_) {
      return 'https://ghproxy.net/';
    }
  }

  Future<void> saveGithubMirrorBaseUrl(String value) async {
    try {
      final payload = await _loadSettings() ?? <String, dynamic>{};
      final trimmed = value.trim();
      payload['githubMirrorBaseUrl'] = trimmed.isEmpty
          ? 'https://ghproxy.net/'
          : trimmed;
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
