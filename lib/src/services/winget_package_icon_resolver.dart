import 'dart:io';

import '../models/package_models.dart';
import 'shell_executor.dart';

class WingetPackageIconResolver {
  const WingetPackageIconResolver();

  Future<Map<String, String>> resolveIconPaths(
    ShellExecutor shell,
    List<ManagedPackage> packages,
  ) async {
    if (!Platform.isWindows || packages.isEmpty) {
      return const <String, String>{};
    }

    final entries = await _loadRegistryEntries(shell);
    if (entries.isEmpty) {
      return const <String, String>{};
    }

    final byDisplayName = <String, List<_RegistryIconEntry>>{};
    for (final entry in entries) {
      byDisplayName
          .putIfAbsent(
            entry.normalizedDisplayName,
            () => <_RegistryIconEntry>[],
          )
          .add(entry);
    }

    final output = <String, String>{};
    for (final package in packages) {
      final match = _matchEntry(package, byDisplayName);
      if (match == null) {
        continue;
      }

      final resolvedPath = await _resolveIconPath(shell, match.iconPath);
      if (resolvedPath != null && resolvedPath.isNotEmpty) {
        output[package.key] = resolvedPath;
      }
    }
    return output;
  }

  Future<List<_RegistryIconEntry>> _loadRegistryEntries(
    ShellExecutor shell,
  ) async {
    const roots = <String>[
      r'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
      r'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
      r'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    ];

    final output = <_RegistryIconEntry>[];
    for (final root in roots) {
      final result = await shell.runExecutable(
        'reg',
        <String>['query', root, '/s'],
        timeout: const Duration(seconds: 45),
        displayCommand: 'reg query ${_quoteDisplay(root)} /s',
      );
      if (!result.isSuccess) {
        continue;
      }
      output.addAll(_parseRegistryEntries(result.stdout));
    }
    return output;
  }

  List<_RegistryIconEntry> _parseRegistryEntries(String stdout) {
    final output = <_RegistryIconEntry>[];
    String? displayName;
    String? iconPath;

    void flush() {
      final normalizedName = _normalizeName(displayName ?? '');
      final normalizedPath = _normalizeIconPath(iconPath);
      if (normalizedName.isEmpty ||
          normalizedPath == null ||
          normalizedPath.isEmpty) {
        displayName = null;
        iconPath = null;
        return;
      }
      output.add(
        _RegistryIconEntry(
          normalizedDisplayName: normalizedName,
          iconPath: normalizedPath,
        ),
      );
      displayName = null;
      iconPath = null;
    }

    for (final rawLine in stdout.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        continue;
      }

      if (line.startsWith('HKEY_')) {
        flush();
        continue;
      }

      final trimmed = line.trimLeft();
      final parts = trimmed.split(RegExp(r'\s{2,}'));
      if (parts.length < 3) {
        continue;
      }

      final key = parts[0].trim();
      final value = parts.sublist(2).join('  ').trim();
      if (value.isEmpty) {
        continue;
      }

      if (key == 'DisplayName' || key == 'QuietDisplayName') {
        displayName = value;
      } else if (key == 'DisplayIcon') {
        iconPath = value;
      }
    }

    flush();
    return output;
  }

  String? _normalizeIconPath(String? rawValue) {
    final raw = rawValue?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    var path = _expandEnvironmentVariables(raw);
    if (path.startsWith('"') && path.endsWith('"') && path.length >= 2) {
      path = path.substring(1, path.length - 1);
    } else if (path.startsWith('"')) {
      final closingQuote = path.indexOf('"', 1);
      if (closingQuote > 1) {
        path = path.substring(1, closingQuote);
      }
    }

    final match = RegExp(
      r'^(.*?\.(?:exe|dll|ico|svg|png|jpg|jpeg|webp|bmp|gif))(?:,.*)?$',
      caseSensitive: false,
    ).firstMatch(path);
    if (match != null) {
      path = match.group(1)!.trim();
    }

    if (path.isEmpty || !_isSupportedIconFile(path)) {
      return null;
    }

    return File(path).existsSync() ? path : null;
  }

  String _expandEnvironmentVariables(String value) {
    return value.replaceAllMapped(RegExp(r'%([^%]+)%'), (match) {
      final variable = match.group(1)?.trim();
      if (variable == null || variable.isEmpty) {
        return match.group(0) ?? '';
      }
      return Platform.environment[variable] ?? match.group(0) ?? '';
    });
  }

  bool _isSupportedIconFile(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.exe') ||
        lowerPath.endsWith('.dll') ||
        lowerPath.endsWith('.ico') ||
        lowerPath.endsWith('.svg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.webp') ||
        lowerPath.endsWith('.bmp') ||
        lowerPath.endsWith('.gif');
  }

  String _quoteDisplay(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  Future<String?> _resolveIconPath(ShellExecutor shell, String sourcePath) async {
    final lowerPath = sourcePath.toLowerCase();
    if (lowerPath.endsWith('.svg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.webp') ||
        lowerPath.endsWith('.bmp') ||
        lowerPath.endsWith('.gif')) {
      return sourcePath;
    }
    if (lowerPath.endsWith('.ico') ||
        lowerPath.endsWith('.exe') ||
        lowerPath.endsWith('.dll')) {
      return _extractWindowsIcon(shell, sourcePath);
    }
    return null;
  }

  Future<String?> _extractWindowsIcon(
    ShellExecutor shell,
    String sourcePath,
  ) async {
    final cacheDirectory = await _resolveCacheDirectory();
    await cacheDirectory.create(recursive: true);
    final outputPath =
        '${cacheDirectory.path}${Platform.pathSeparator}${_iconCacheKey(sourcePath)}.png';
    final outputFile = File(outputPath);
    if (outputFile.existsSync()) {
      return outputFile.path;
    }

    final command = '''
Add-Type -AssemblyName System.Drawing;
\$source = ${_quoteDisplay(sourcePath)};
\$target = ${_quoteDisplay(outputPath)};
\$extension = [System.IO.Path]::GetExtension(\$source).ToLowerInvariant();
if (\$extension -eq '.ico') {
  \$icon = New-Object System.Drawing.Icon(\$source);
} else {
  \$icon = [System.Drawing.Icon]::ExtractAssociatedIcon(\$source);
}
if (\$null -eq \$icon) {
  throw '无法提取图标。';
}
\$bitmap = \$icon.ToBitmap();
\$bitmap.Save(\$target, [System.Drawing.Imaging.ImageFormat]::Png);
\$bitmap.Dispose();
\$icon.Dispose();
''';
    final result = await shell.runPowerShell(
      command,
      timeout: const Duration(seconds: 20),
    );
    if (!result.isSuccess || !outputFile.existsSync()) {
      return null;
    }
    return outputFile.path;
  }

  Future<Directory> _resolveCacheDirectory() async {
    final basePath =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    return Directory(
      '$basePath${Platform.pathSeparator}pkg_panel${Platform.pathSeparator}winget_icons',
    );
  }

  String _iconCacheKey(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.toLowerCase().codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  _RegistryIconEntry? _matchEntry(
    ManagedPackage package,
    Map<String, List<_RegistryIconEntry>> byDisplayName,
  ) {
    final candidates = <String>{
      _normalizeName(package.name),
      if (package.identifier != null) _normalizeName(package.identifier!),
      ...package.executables.map(_normalizeName),
    }..removeWhere((value) => value.isEmpty);

    for (final candidate in candidates) {
      final exact = byDisplayName[candidate];
      if (exact != null && exact.isNotEmpty) {
        return exact.first;
      }
    }

    for (final candidate in candidates) {
      for (final entries in byDisplayName.values) {
        for (final entry in entries) {
          if (entry.normalizedDisplayName.contains(candidate) ||
              candidate.contains(entry.normalizedDisplayName)) {
            return entry;
          }
        }
      }
    }

    return null;
  }

  String _normalizeName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _RegistryIconEntry {
  const _RegistryIconEntry({
    required this.normalizedDisplayName,
    required this.iconPath,
  });

  final String normalizedDisplayName;
  final String iconPath;
}
