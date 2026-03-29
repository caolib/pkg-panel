import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ShellRequest {
  factory ShellRequest.process({
    required String executable,
    List<String> arguments = const <String>[],
    String? displayCommand,
  }) {
    return ShellRequest._(
      executable: executable,
      arguments: List<String>.unmodifiable(arguments),
      displayCommand:
          displayCommand ?? formatShellDisplayCommand(executable, arguments),
    );
  }

  const ShellRequest._({
    required this.executable,
    required this.arguments,
    required this.displayCommand,
  });

  final String executable;
  final List<String> arguments;
  final String displayCommand;
}

class ShellResult {
  const ShellResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get isSuccess => exitCode == 0;

  String get combinedOutput {
    return [
      stdout.trim(),
      stderr.trim(),
    ].where((part) => part.isNotEmpty).join('\n\n');
  }
}

class ShellExecutor {
  const ShellExecutor({
    Map<String, String>? processEnvironment,
    Future<Map<String, String>> Function()? windowsEnvironmentProvider,
  }) : _processEnvironment = processEnvironment,
       _windowsEnvironmentProvider = windowsEnvironmentProvider;
  static const Utf8Codec _utf8 = Utf8Codec();
  static final Map<String, String?> _resolvedExecutableCache =
      <String, String?>{};
  static Map<String, String>? _cachedWindowsEnvironmentOverrides;
  static DateTime? _cachedWindowsEnvironmentOverridesAt;
  static const Duration _windowsEnvironmentCacheTtl = Duration(seconds: 5);

  final Map<String, String>? _processEnvironment;
  final Future<Map<String, String>> Function()? _windowsEnvironmentProvider;

  Future<ShellResult> runRequest(
    ShellRequest request, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _runProcess(
      request.executable,
      request.arguments,
      timeout: timeout,
    );
  }

  Future<ShellResult> runExecutable(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 30),
    String? displayCommand,
  }) async {
    return runRequest(
      ShellRequest.process(
        executable: executable,
        arguments: arguments,
        displayCommand: displayCommand,
      ),
      timeout: timeout,
    );
  }

  Future<ShellResult> runPowerShell(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final wrappedCommand = [
      r'$utf8NoBom = [System.Text.UTF8Encoding]::new($false)',
      r'[Console]::InputEncoding = $utf8NoBom',
      r'[Console]::OutputEncoding = $utf8NoBom',
      r'$OutputEncoding = $utf8NoBom',
      'chcp 65001 > \$null',
      command,
    ].join('; ');
    return runExecutable(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        wrappedCommand,
      ],
      timeout: timeout,
      displayCommand: command,
    );
  }

  Future<bool> isExecutableAvailable(String executable) async {
    final trimmed = executable.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (Platform.isWindows && !_looksLikePath(trimmed)) {
      final result = await runPowerShell(
        "if (Get-Command '${_escapePowerShellSingleQuoted(trimmed)}' "
        "-ErrorAction SilentlyContinue) { '1' } else { '0' }",
      );
      if (result.isSuccess) {
        return result.stdout.trim() == '1';
      }
    }

    return (await locateExecutable(trimmed)) != null;
  }

  Future<String?> locateExecutable(String executable) async {
    final trimmed = executable.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (_looksLikePath(trimmed)) {
      return _resolveExplicitExecutablePath(trimmed);
    }

    final searchEnvironment = await _executableSearchEnvironment();
    final cacheKey = [
      Platform.operatingSystem,
      trimmed.toLowerCase(),
      searchEnvironment.cacheSignature,
    ].join(':');
    if (_resolvedExecutableCache.containsKey(cacheKey)) {
      return _resolvedExecutableCache[cacheKey];
    }

    final resolved = await _resolveExecutableFromPath(
      trimmed,
      path: searchEnvironment.path,
      pathExt: searchEnvironment.pathExt,
    );
    if (resolved != null) {
      _resolvedExecutableCache[cacheKey] = resolved;
    }
    return resolved;
  }

  Future<ShellResult> _runProcess(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final workingDirectory = await _resolveWorkingDirectory();
    final searchEnvironment = await _executableSearchEnvironment();
    final resolvedExecutable =
        await locateExecutable(executable) ?? executable.trim();

    try {
      final result = await Process.run(
        resolvedExecutable,
        arguments,
        stdoutEncoding: null,
        stderrEncoding: null,
        workingDirectory: workingDirectory,
        environment: searchEnvironment.processOverrides,
        includeParentEnvironment: true,
      ).timeout(timeout);

      return ShellResult(
        exitCode: result.exitCode,
        stdout: _decodeProcessOutput(result.stdout),
        stderr: _decodeProcessOutput(result.stderr),
      );
    } on TimeoutException {
      return const ShellResult(
        exitCode: 124,
        stdout: '',
        stderr: '命令执行超时，未能在限定时间内完成。',
      );
    } on ProcessException catch (error) {
      return ShellResult(
        exitCode: error.errorCode,
        stdout: '',
        stderr: error.message,
      );
    } catch (error) {
      return ShellResult(exitCode: 1, stdout: '', stderr: '$error');
    }
  }

  Future<String?> _resolveExplicitExecutablePath(String executable) async {
    final file = File(executable);
    if (await file.exists()) {
      return file.path;
    }

    if (!Platform.isWindows || _hasExecutableExtension(executable)) {
      return null;
    }

    for (final extension in _windowsExecutableExtensions(
      _environmentValue('PATHEXT'),
    )) {
      final candidate = '$executable$extension';
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    return null;
  }

  Future<String?> _resolveExecutableFromPath(
    String executable, {
    required String path,
    required String pathExt,
  }) async {
    final rawPath = path;
    if (rawPath.trim().isEmpty) {
      return null;
    }

    final separator = Platform.isWindows ? ';' : ':';
    final directories = rawPath
        .split(separator)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (directories.isEmpty) {
      return null;
    }

    final candidates = Platform.isWindows
        ? _windowsCommandCandidates(executable, pathExt)
        : <String>[executable];

    String? resolved;
    var resolvedPriority = 1 << 20;

    for (final directory in directories) {
      for (final candidate in candidates) {
        final path = _joinPath(directory, candidate);
        final file = File(path);
        if (!await file.exists()) {
          continue;
        }
        if (!Platform.isWindows && !await _isExecutableFile(file)) {
          continue;
        }

        final priority = _candidatePriority(path);
        if (resolved == null || priority < resolvedPriority) {
          resolved = file.path;
          resolvedPriority = priority;
        }
      }
    }

    return resolved;
  }

  String _joinPath(String directory, String entry) {
    if (directory.endsWith(Platform.pathSeparator)) {
      return '$directory$entry';
    }
    return '$directory${Platform.pathSeparator}$entry';
  }

  bool _looksLikePath(String value) {
    return value.contains('\\') ||
        value.contains('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(value) ||
        value.startsWith('.');
  }

  bool _hasExecutableExtension(String executable) {
    final lower = executable.toLowerCase();
    return lower.endsWith('.exe') ||
        lower.endsWith('.cmd') ||
        lower.endsWith('.bat') ||
        lower.endsWith('.com') ||
        (!Platform.isWindows && lower.contains('.'));
  }

  List<String> _windowsCommandCandidates(String executable, String pathExt) {
    if (_hasExecutableExtension(executable)) {
      return <String>[executable];
    }

    final values = <String>[executable];
    for (final extension in _windowsExecutableExtensions(pathExt)) {
      values.add('$executable$extension');
    }
    return values;
  }

  List<String> _windowsExecutableExtensions(String pathExt) {
    final raw = pathExt.trim().isEmpty ? null : pathExt;
    final parts = (raw == null || raw.trim().isEmpty)
        ? const <String>['.EXE', '.CMD', '.BAT', '.COM']
        : raw
              .split(';')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList(growable: false);

    final unique = <String>{};
    final output = <String>[];
    for (final part in parts) {
      final normalized = part.startsWith('.') ? part : '.$part';
      final lower = normalized.toLowerCase();
      if (unique.add(lower)) {
        output.add(lower);
      }
    }
    return output;
  }

  int _candidatePriority(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.exe')) {
      return 0;
    }
    if (lower.endsWith('.cmd')) {
      return 1;
    }
    if (lower.endsWith('.bat')) {
      return 2;
    }
    if (lower.endsWith('.com')) {
      return 3;
    }
    return 4;
  }

  Future<bool> _isExecutableFile(File file) async {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      return false;
    }
    return (stat.mode & 0x49) != 0;
  }

  String _decodeProcessOutput(Object? output) {
    if (output == null) {
      return '';
    }
    if (output is String) {
      return output;
    }
    if (output is! List<int>) {
      return '$output';
    }
    if (output.isEmpty) {
      return '';
    }

    try {
      return _utf8.decode(output);
    } catch (_) {
      return systemEncoding.decode(output);
    }
  }

  String _escapePowerShellSingleQuoted(String value) {
    return value.replaceAll("'", "''");
  }

  Future<_ExecutableSearchEnvironment> _executableSearchEnvironment() async {
    final processPath = _environmentValue('PATH');
    final processPathExt = _environmentValue('PATHEXT');
    if (!Platform.isWindows) {
      return _ExecutableSearchEnvironment(
        path: processPath,
        pathExt: processPathExt,
        processOverrides: const <String, String>{},
      );
    }

    final windowsOverrides = await _windowsEnvironmentOverrides();
    final mergedPath = _mergeEnvironmentSegments(
      <String>[processPath, windowsOverrides['PATH'] ?? ''],
    );
    final mergedPathExt = _mergeEnvironmentSegments(
      <String>[processPathExt, windowsOverrides['PATHEXT'] ?? ''],
    );

    return _ExecutableSearchEnvironment(
      path: mergedPath,
      pathExt: mergedPathExt,
      processOverrides: <String, String>{
        if (mergedPath.isNotEmpty) 'PATH': mergedPath,
        if (mergedPathExt.isNotEmpty) 'PATHEXT': mergedPathExt,
      },
    );
  }

  Future<Map<String, String>> _windowsEnvironmentOverrides() async {
    final provider = _windowsEnvironmentProvider;
    if (provider != null) {
      return _normalizeEnvironmentOverrides(await provider());
    }

    final now = DateTime.now();
    final cached = _cachedWindowsEnvironmentOverrides;
    final cachedAt = _cachedWindowsEnvironmentOverridesAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _windowsEnvironmentCacheTtl) {
      return cached;
    }

    final loaded = await _loadWindowsEnvironmentOverrides();
    _cachedWindowsEnvironmentOverrides = loaded;
    _cachedWindowsEnvironmentOverridesAt = now;
    return loaded;
  }

  Future<Map<String, String>> _loadWindowsEnvironmentOverrides() async {
    final executable = _windowsPowerShellExecutablePath();
    final command = [
      r'$utf8NoBom = [System.Text.UTF8Encoding]::new($false)',
      r'[Console]::InputEncoding = $utf8NoBom',
      r'[Console]::OutputEncoding = $utf8NoBom',
      r'$OutputEncoding = $utf8NoBom',
      r'$payload = @{',
      r"  machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')",
      r"  userPath = [Environment]::GetEnvironmentVariable('Path', 'User')",
      r"  machinePathExt = [Environment]::GetEnvironmentVariable('PATHEXT', 'Machine')",
      r"  userPathExt = [Environment]::GetEnvironmentVariable('PATHEXT', 'User')",
      r'}',
      r'$payload | ConvertTo-Json -Compress',
    ].join('; ');

    try {
      final result = await Process.run(
        executable,
        <String>[
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          command,
        ],
        stdoutEncoding: null,
        stderrEncoding: null,
      ).timeout(const Duration(seconds: 5));
      if (result.exitCode != 0) {
        return const <String, String>{};
      }

      final stdout = _decodeProcessOutput(result.stdout).trim();
      if (stdout.isEmpty) {
        return const <String, String>{};
      }

      final decoded = jsonDecode(stdout);
      if (decoded is! Map) {
        return const <String, String>{};
      }

      return _normalizeEnvironmentOverrides(<String, String>{
        'PATH': _mergeEnvironmentSegments(<String>[
          '${decoded['machinePath'] ?? ''}',
          '${decoded['userPath'] ?? ''}',
        ]),
        'PATHEXT': _mergeEnvironmentSegments(<String>[
          '${decoded['machinePathExt'] ?? ''}',
          '${decoded['userPathExt'] ?? ''}',
        ]),
      });
    } catch (_) {
      return const <String, String>{};
    }
  }

  Map<String, String> _normalizeEnvironmentOverrides(Map<String, String> values) {
    final normalized = <String, String>{};
    final path = _mergeEnvironmentSegments(<String>[values['PATH'] ?? '']);
    final pathExt = _mergeEnvironmentSegments(<String>[values['PATHEXT'] ?? '']);
    if (path.isNotEmpty) {
      normalized['PATH'] = path;
    }
    if (pathExt.isNotEmpty) {
      normalized['PATHEXT'] = pathExt;
    }
    return normalized;
  }

  String _mergeEnvironmentSegments(List<String> values) {
    final separator = Platform.isWindows ? ';' : ':';
    final seen = <String>{};
    final segments = <String>[];
    for (final value in values) {
      for (final segment in value.split(separator)) {
        final trimmed = segment.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final key = Platform.isWindows ? trimmed.toLowerCase() : trimmed;
        if (seen.add(key)) {
          segments.add(trimmed);
        }
      }
    }
    return segments.join(separator);
  }

  String _environmentValue(String key) {
    final environment = _processEnvironment ?? Platform.environment;
    if (environment.containsKey(key)) {
      return environment[key] ?? '';
    }
    for (final entry in environment.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        return entry.value;
      }
    }
    return '';
  }

  String _windowsPowerShellExecutablePath() {
    final systemRoot = _environmentValue('SystemRoot');
    final base = systemRoot.trim().isEmpty ? r'C:\Windows' : systemRoot.trim();
    return [
      base,
      'System32',
      'WindowsPowerShell',
      'v1.0',
      'powershell.exe',
    ].join(Platform.pathSeparator);
  }

  Future<String> _resolveWorkingDirectory() async {
    const folderName = 'pkg_panel';
    const shellFolderName = 'shell';
    final candidates = <String>[
      _environmentValue('XDG_STATE_HOME'),
      _environmentValue('XDG_CACHE_HOME'),
      _environmentValue('LOCALAPPDATA'),
      _environmentValue('APPDATA'),
      _environmentValue('HOME'),
      _environmentValue('USERPROFILE'),
      Directory.systemTemp.path,
    ];

    for (final candidate in candidates) {
      final basePath = candidate.trim();
      if (basePath.isEmpty) {
        continue;
      }

      final directory = Directory(
        '$basePath${Platform.pathSeparator}$folderName${Platform.pathSeparator}$shellFolderName',
      );
      try {
        await directory.create(recursive: true);
        return directory.path;
      } catch (_) {
        continue;
      }
    }

    return Directory.systemTemp.path;
  }
}

String formatShellDisplayCommand(String executable, List<String> arguments) {
  return <String>[
    executable,
    ...arguments.map(_formatShellDisplayArgument),
  ].join(' ');
}

String _formatShellDisplayArgument(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return "''";
  }

  final isFlag = trimmed.startsWith('-');
  final needsQuotes = RegExp(r'''[\s'"`$&|<>*?()\[\]{};=,]''').hasMatch(trimmed);
  if (isFlag || !needsQuotes) {
    return trimmed;
  }
  return "'${trimmed.replaceAll("'", "''")}'";
}

class _ExecutableSearchEnvironment {
  const _ExecutableSearchEnvironment({
    required this.path,
    required this.pathExt,
    required this.processOverrides,
  });

  final String path;
  final String pathExt;
  final Map<String, String> processOverrides;

  String get cacheSignature => '$path::$pathExt';
}
