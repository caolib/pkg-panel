import 'dart:convert';
import 'dart:io';

import '../models/package_models.dart';
import 'shell_executor.dart';

class WingetPackageIconResolver {
  const WingetPackageIconResolver();

  Future<Map<String, String>> resolveIconPaths(
    ShellExecutor shell,
    List<ManagedPackage> packages,
  ) async {
    if (packages.isEmpty) {
      return const <String, String>{};
    }

    final cacheDir = await _resolveCacheDirectory();
    await _cleanupCacheDirectory(cacheDir);

    final entries = <_RegistryIconEntry>[
      ...await _loadRegistryEntries(shell),
      ...await _loadShortcutEntries(shell),
    ];
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
      if (match != null) {
        final materializedPath = await _materializeIconPath(
          shell,
          match.iconPath,
          cacheDir,
        );
        if (materializedPath != null && materializedPath.isNotEmpty) {
          output[package.key] = materializedPath;
        }
      }
    }
    return output;
  }

  Future<String?> _materializeIconPath(
    ShellExecutor shell,
    String iconPath,
    Directory cacheDir,
  ) async {
    final lowerPath = iconPath.toLowerCase();
    if (_isDirectImage(lowerPath)) {
      return iconPath;
    }

    if (!lowerPath.endsWith('.exe') && !lowerPath.endsWith('.ico')) {
      return null;
    }

    await cacheDir.create(recursive: true);
    final fileName = '${_sanitizeFileName(iconPath)}.png';
    final outputFile = File(
      '${cacheDir.path}${Platform.pathSeparator}$fileName',
    );
    if (await outputFile.exists()) {
      await outputFile.setLastModified(DateTime.now());
      return outputFile.path;
    }

    final result = await shell.run(
      _buildExtractScript(sourcePath: iconPath, outputPath: outputFile.path),
      timeout: const Duration(seconds: 30),
    );
    if (!result.isSuccess || !await outputFile.exists()) {
      return null;
    }
    return outputFile.path;
  }

  Future<List<_RegistryIconEntry>> _loadRegistryEntries(
    ShellExecutor shell,
  ) async {
    final result = await shell.run(
      _registryQueryScript,
      timeout: const Duration(seconds: 45),
    );
    if (!result.isSuccess) {
      return const <_RegistryIconEntry>[];
    }
    return _parseRegistryEntries(result.stdout);
  }

  Future<List<_RegistryIconEntry>> _loadShortcutEntries(
    ShellExecutor shell,
  ) async {
    final result = await shell.run(
      _startMenuShortcutQueryScript,
      timeout: const Duration(seconds: 45),
    );
    if (!result.isSuccess) {
      return const <_RegistryIconEntry>[];
    }
    return _parseRegistryEntries(result.stdout);
  }

  Future<void> _cleanupCacheDirectory(Directory cacheDir) async {
    if (!await cacheDir.exists()) {
      return;
    }

    final files = <File>[];
    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        files.add(entity);
      }
    }

    final expiry = DateTime.now().subtract(const Duration(days: 14));
    for (final file in files) {
      try {
        final stat = await file.stat();
        if (stat.modified.isBefore(expiry)) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cache cleanup failures.
      }
    }

    if (files.length <= 300) {
      return;
    }

    final liveFiles = <(File, DateTime)>[];
    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        try {
          liveFiles.add((entity, (await entity.stat()).modified));
        } catch (_) {
          // Ignore cache cleanup failures.
        }
      }
    }
    liveFiles.sort((a, b) => b.$2.compareTo(a.$2));
    for (final entry in liveFiles.skip(250)) {
      try {
        await entry.$1.delete();
      } catch (_) {
        // Ignore cache cleanup failures.
      }
    }
  }

  bool _isDirectImage(String lowerPath) {
    return lowerPath.endsWith('.svg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.webp') ||
        lowerPath.endsWith('.bmp') ||
        lowerPath.endsWith('.gif');
  }

  Future<Directory> _resolveCacheDirectory() async {
    final basePath =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    return Directory(
      '$basePath${Platform.pathSeparator}pkg_panel${Platform.pathSeparator}icon_cache',
    );
  }

  String _sanitizeFileName(String value) {
    final sanitized = value
        .toLowerCase()
        .replaceAll(RegExp(r'^[a-z]:'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (sanitized.isEmpty) {
      return 'icon';
    }
    return sanitized.length > 80 ? sanitized.substring(0, 80) : sanitized;
  }

  String _buildExtractScript({
    required String sourcePath,
    required String outputPath,
  }) {
    final source = _psQuote(sourcePath);
    final output = _psQuote(outputPath);
    return r'''
Add-Type -AssemblyName System.Drawing;
$source = ''' +
        source +
        r''';
$output = ''' +
        output +
        r''';
$directory = Split-Path -Parent $output;
New-Item -ItemType Directory -Force -Path $directory | Out-Null;
$bitmap = $null;
try {
  if ($source.ToLower().EndsWith('.exe')) {
    $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($source);
  } else {
    $stream = [System.IO.File]::OpenRead($source);
    try {
      $icon = [System.Drawing.Icon]::new($stream);
    } finally {
      $stream.Dispose();
    }
  }
  if ($null -eq $icon) {
    exit 1
  }
  $bitmap = $icon.ToBitmap();
  $bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png);
} catch {
  exit 1
} finally {
  if ($bitmap -ne $null) {
    $bitmap.Dispose();
  }
  if ($icon -ne $null) {
    $icon.Dispose();
  }
}
''';
  }

  String _psQuote(String value) {
    return "'${value.replaceAll("'", "''")}'";
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

  List<_RegistryIconEntry> _parseRegistryEntries(String stdout) {
    try {
      final decoded = jsonDecode(stdout);
      if (decoded is! List) {
        return const <_RegistryIconEntry>[];
      }

      final output = <_RegistryIconEntry>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final displayName = '${item['displayName'] ?? ''}'.trim();
        final iconPath = '${item['iconPath'] ?? ''}'.trim();
        if (displayName.isEmpty || iconPath.isEmpty) {
          continue;
        }
        output.add(
          _RegistryIconEntry(
            normalizedDisplayName: _normalizeName(displayName),
            iconPath: iconPath,
          ),
        );
      }
      return output;
    } catch (_) {
      return const <_RegistryIconEntry>[];
    }
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

const String _registryQueryScript = r'''
$roots = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$items = foreach ($root in $roots) {
  Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.DisplayIcon } |
    ForEach-Object {
      $iconPath = [Environment]::ExpandEnvironmentVariables([string]$_.DisplayIcon).Trim()
      if ($iconPath.StartsWith('"')) {
        $iconPath = $iconPath.Trim('"')
      }
      if ($iconPath -match '^(.*?\.(?:exe|ico|png|svg|jpg|jpeg|webp))(?:,.*)?$') {
        $iconPath = $matches[1]
      }
      if ([string]::IsNullOrWhiteSpace($iconPath) -or -not (Test-Path $iconPath)) {
        return
      }
      [pscustomobject]@{
        displayName = [string]$_.DisplayName
        iconPath = $iconPath
      }
    }
}
$items | ConvertTo-Json -Depth 3 -Compress
''';

const String _startMenuShortcutQueryScript = r'''
$shell = New-Object -ComObject WScript.Shell
$roots = @(
  "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
)
$items = foreach ($root in $roots) {
  if (-not (Test-Path $root)) {
    continue
  }
  Get-ChildItem -Path $root -Filter *.lnk -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
      try {
        $shortcut = $shell.CreateShortcut($_.FullName)
        $displayName = $_.BaseName
        $iconPath = [string]$shortcut.IconLocation
        if ([string]::IsNullOrWhiteSpace($iconPath)) {
          $iconPath = [string]$shortcut.TargetPath
        }
        $iconPath = [Environment]::ExpandEnvironmentVariables($iconPath).Trim()
        if ($iconPath.StartsWith('"')) {
          $iconPath = $iconPath.Trim('"')
        }
        if ($iconPath -match '^(.*?\.(?:exe|ico|png|svg|jpg|jpeg|webp))(?:,.*)?$') {
          $iconPath = $matches[1]
        }
        if ([string]::IsNullOrWhiteSpace($displayName) -or
            [string]::IsNullOrWhiteSpace($iconPath) -or
            -not (Test-Path $iconPath)) {
          return
        }
        [pscustomobject]@{
          displayName = $displayName
          iconPath = $iconPath
        }
      } catch {
        return
      }
    }
}
$items | ConvertTo-Json -Depth 3 -Compress
''';
