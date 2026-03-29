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
  const ShellExecutor();
  static const Utf8Codec _utf8 = Utf8Codec();
  static final Map<String, String?> _resolvedExecutableCache =
      <String, String?>{};

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
    return (await locateExecutable(executable)) != null;
  }

  Future<String?> locateExecutable(String executable) async {
    final trimmed = executable.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (_looksLikePath(trimmed)) {
      return _resolveExplicitExecutablePath(trimmed);
    }

    final cacheKey = '${Platform.operatingSystem}:${trimmed.toLowerCase()}';
    if (_resolvedExecutableCache.containsKey(cacheKey)) {
      return _resolvedExecutableCache[cacheKey];
    }

    final resolved = await _resolveExecutableFromPath(trimmed);
    _resolvedExecutableCache[cacheKey] = resolved;
    return resolved;
  }

  Future<ShellResult> _runProcess(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final workingDirectory = await _resolveWorkingDirectory();
    final resolvedExecutable =
        await locateExecutable(executable) ?? executable.trim();

    try {
      final result = await Process.run(
        resolvedExecutable,
        arguments,
        stdoutEncoding: null,
        stderrEncoding: null,
        workingDirectory: workingDirectory,
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

    for (final extension in _windowsExecutableExtensions()) {
      final candidate = '$executable$extension';
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    return null;
  }

  Future<String?> _resolveExecutableFromPath(String executable) async {
    final rawPath = Platform.environment['PATH'] ?? '';
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
        ? _windowsCommandCandidates(executable)
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

  List<String> _windowsCommandCandidates(String executable) {
    if (_hasExecutableExtension(executable)) {
      return <String>[executable];
    }

    final values = <String>[executable];
    for (final extension in _windowsExecutableExtensions()) {
      values.add('$executable$extension');
    }
    return values;
  }

  List<String> _windowsExecutableExtensions() {
    final raw = Platform.environment['PATHEXT'];
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

  Future<String> _resolveWorkingDirectory() async {
    const folderName = 'pkg_panel';
    const shellFolderName = 'shell';
    final candidates = <String>[
      Platform.environment['XDG_STATE_HOME'] ?? '',
      Platform.environment['XDG_CACHE_HOME'] ?? '',
      Platform.environment['LOCALAPPDATA'] ?? '',
      Platform.environment['APPDATA'] ?? '',
      Platform.environment['HOME'] ?? '',
      Platform.environment['USERPROFILE'] ?? '',
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
