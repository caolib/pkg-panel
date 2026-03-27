import 'dart:convert';
import 'dart:async';
import 'dart:io';

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

  static const Utf8Codec _utf8 = Utf8Codec(allowMalformed: true);

  Future<ShellResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!Platform.isWindows) {
      return const ShellResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Pkg Panel 目前仅支持 Windows 桌面端。',
      );
    }

    final executable = await _resolvePowerShellExecutable();
    final wrappedCommand = [
      r"""if ($PSStyle -and $PSStyle.PSObject.Properties['OutputRendering']) { $PSStyle.OutputRendering = 'PlainText' }""",
      r'[Console]::OutputEncoding = [System.Text.Encoding]::UTF8',
      r'$OutputEncoding = [System.Text.Encoding]::UTF8',
      command,
    ].join('; ');

    try {
      final result = await Process.run(
        executable,
        <String>[
          '-NoLogo',
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          wrappedCommand,
        ],
        stdoutEncoding: _utf8,
        stderrEncoding: _utf8,
      ).timeout(timeout);

      return ShellResult(
        exitCode: result.exitCode,
        stdout: '${result.stdout}',
        stderr: '${result.stderr}',
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

  Future<String> _resolvePowerShellExecutable() async {
    const pwshPath = r'C:\Program Files\PowerShell\7\pwsh.exe';
    if (await File(pwshPath).exists()) {
      return pwshPath;
    }
    return 'powershell.exe';
  }
}
