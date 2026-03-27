import 'dart:convert';
import 'dart:io';

class PersistedPackageLatestInfo {
  const PersistedPackageLatestInfo({
    required this.installedVersion,
    required this.latestVersion,
    required this.checkedAt,
  });

  final String installedVersion;
  final String latestVersion;
  final DateTime checkedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'installedVersion': installedVersion,
      'latestVersion': latestVersion,
      'checkedAt': checkedAt.toIso8601String(),
    };
  }

  static PersistedPackageLatestInfo? fromJson(Map<String, dynamic> json) {
    final installedVersion = '${json['installedVersion'] ?? ''}'.trim();
    final latestVersion = '${json['latestVersion'] ?? ''}'.trim();
    final checkedAtRaw = '${json['checkedAt'] ?? ''}'.trim();
    if (installedVersion.isEmpty ||
        latestVersion.isEmpty ||
        checkedAtRaw.isEmpty) {
      return null;
    }

    final checkedAt = DateTime.tryParse(checkedAtRaw);
    if (checkedAt == null) {
      return null;
    }

    return PersistedPackageLatestInfo(
      installedVersion: installedVersion,
      latestVersion: latestVersion,
      checkedAt: checkedAt,
    );
  }
}

class PackageLatestInfoStore {
  const PackageLatestInfoStore();

  Future<Map<String, PersistedPackageLatestInfo>> load() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return const <String, PersistedPackageLatestInfo>{};
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <String, PersistedPackageLatestInfo>{};
      }

      final output = <String, PersistedPackageLatestInfo>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) {
          continue;
        }
        final info = PersistedPackageLatestInfo.fromJson(value);
        if (info != null) {
          output[entry.key] = info;
        }
      }
      return output;
    } catch (_) {
      return const <String, PersistedPackageLatestInfo>{};
    }
  }

  Future<void> save(Map<String, PersistedPackageLatestInfo> entries) async {
    try {
      final file = await _resolveFile();
      if (entries.isEmpty) {
        if (await file.exists()) {
          await file.delete();
        }
        return;
      }

      await file.parent.create(recursive: true);
      final payload = <String, dynamic>{
        for (final entry in entries.entries) entry.key: entry.value.toJson(),
      };
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(payload));
    } catch (_) {
      // Best-effort cache persistence.
    }
  }

  Future<File> _resolveFile() async {
    final basePath =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final directory = Directory(
      '$basePath${Platform.pathSeparator}pkg_panel',
    );
    return File(
      '${directory.path}${Platform.pathSeparator}latest_versions.json',
    );
  }
}
