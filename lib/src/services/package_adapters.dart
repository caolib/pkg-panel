import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/package_models.dart';
import 'shell_executor.dart';

abstract class PackageManagerAdapter {
  const PackageManagerAdapter(this.definition);

  final PackageManagerDefinition definition;

  Future<List<ManagedPackage>> listPackages(ShellExecutor shell);

  PackageCommand buildCommand(PackageAction action, ManagedPackage package);

  PackageCommand? buildBatchUpdateCommand() => null;

  bool supportsLatestVersionLookup(ManagedPackage package) => false;

  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    throw UnsupportedError('${definition.displayName} 不支持查询最新版本。');
  }
}

class PackageManagerRegistry {
  static final List<PackageManagerAdapter> defaultAdapters =
      <PackageManagerAdapter>[
        const WingetAdapter(),
        const ChocolateyAdapter(),
        const ScoopAdapter(),
        const NpmAdapter(),
        const PnpmAdapter(),
        const BunAdapter(),
        const PipAdapter(),
        const UvToolAdapter(),
        const CargoAdapter(),
      ];
}

class NpmAdapter extends PackageManagerAdapter {
  const NpmAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'npm',
          displayName: 'npm',
          executable: 'npm',
          description: 'Node.js global packages',
          color: Color(0xFFE4572E),
          icon: Icons.hub_outlined,
          supportsBatchUpdate: true,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('npm ls -g --depth=0 --json');
    final payload = _decodeJsonObject(
      result,
      managerName: definition.displayName,
    );
    final dependencies = payload['dependencies'] is Map<String, dynamic>
        ? payload['dependencies'] as Map<String, dynamic>
        : <String, dynamic>{};

    return dependencies.entries.map((entry) {
      final package = entry.value is Map<String, dynamic>
          ? entry.value as Map<String, dynamic>
          : <String, dynamic>{};
      return ManagedPackage(
        name: entry.key,
        managerId: definition.id,
        managerName: definition.displayName,
        version: _stringOrUnknown(package['version']),
        source: _globalSourceLabel,
      );
    }).toList()..sort(_packageSort);
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'npm update -g ${_psQuote(package.name)}',
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '删除 ${package.name}',
        command: 'npm uninstall -g ${_psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return _command(
      managerId: definition.id,
      label: '批量更新 npm 包',
      command: 'npm update -g',
    );
  }

  @override
  bool supportsLatestVersionLookup(ManagedPackage package) => true;

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'npm view ${_psQuote(package.name)} version --json',
      timeout: const Duration(seconds: 45),
    );
    return _parseSingleVersionValue(
      result,
      managerName: definition.displayName,
    );
  }
}

class PnpmAdapter extends PackageManagerAdapter {
  const PnpmAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'pnpm',
          displayName: 'pnpm',
          executable: 'pnpm',
          description: 'pnpm global packages',
          color: Color(0xFFF59E0B),
          icon: Icons.account_tree_outlined,
          supportsBatchUpdate: true,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('pnpm ls -g --depth=0 --json');
    final payload = _decodeJson(result, managerName: definition.displayName);
    final packages = <ManagedPackage>[];

    if (payload is List) {
      for (final node in payload) {
        if (node is Map<String, dynamic>) {
          packages.addAll(_readPnpmDependencies(node));
        }
      }
    } else if (payload is Map<String, dynamic>) {
      packages.addAll(_readPnpmDependencies(payload));
    }

    packages.sort(_packageSort);
    return packages;
  }

  List<ManagedPackage> _readPnpmDependencies(Map<String, dynamic> node) {
    final output = <ManagedPackage>[];
    final dependencies = node['dependencies'];
    if (dependencies is Map<String, dynamic>) {
      for (final entry in dependencies.entries) {
        final dependency = entry.value is Map<String, dynamic>
            ? entry.value as Map<String, dynamic>
            : <String, dynamic>{};
        output.add(
          ManagedPackage(
            name: entry.key,
            managerId: definition.id,
            managerName: definition.displayName,
            version: _stringOrUnknown(dependency['version']),
            source: '${node['path'] ?? _globalSourceLabel}',
          ),
        );
      }
    }
    return output;
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'pnpm update -g --latest ${_psQuote(package.name)}',
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '删除 ${package.name}',
        command: 'pnpm remove -g ${_psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return _command(
      managerId: definition.id,
      label: '批量更新 pnpm 包',
      command: 'pnpm update -g --latest',
    );
  }

  @override
  bool supportsLatestVersionLookup(ManagedPackage package) => true;

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'pnpm view ${_psQuote(package.name)} version --json',
      timeout: const Duration(seconds: 45),
    );
    if (result.isSuccess) {
      return _parseSingleVersionValue(
        result,
        managerName: definition.displayName,
      );
    }

    final fallback = await shell.run(
      'npm view ${_psQuote(package.name)} version --json',
      timeout: const Duration(seconds: 45),
    );
    return _parseSingleVersionValue(
      fallback,
      managerName: definition.displayName,
    );
  }
}

class PipAdapter extends PackageManagerAdapter {
  const PipAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'pip',
          displayName: 'pip',
          executable: 'pip',
          description: 'Python site packages',
          color: Color(0xFF4B7BEC),
          icon: Icons.science_outlined,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('pip list --format=json');
    final payload = _decodeJsonArray(
      result,
      managerName: definition.displayName,
    );

    return payload.map((entry) {
      return ManagedPackage(
        name: _stringOrUnknown(entry['name']),
        managerId: definition.id,
        managerName: definition.displayName,
        version: _stringOrUnknown(entry['version']),
        notes: entry['editable_project_location'] == null
            ? null
            : '可编辑路径: ${entry['editable_project_location']}',
      );
    }).toList()..sort(_packageSort);
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '升级 ${package.name}',
        command: 'pip install --upgrade ${_psQuote(package.name)}',
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: 'pip uninstall -y ${_psQuote(package.name)}',
      ),
    };
  }

  @override
  bool supportsLatestVersionLookup(ManagedPackage package) => true;

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'pip index versions ${_psQuote(package.name)} --disable-pip-version-check --no-color',
      timeout: const Duration(seconds: 45),
    );
    return _parsePipLatestVersion(result, managerName: definition.displayName);
  }
}

class UvToolAdapter extends PackageManagerAdapter {
  const UvToolAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'uv',
          displayName: 'uv',
          executable: 'uv',
          description: 'Python command-line tools',
          color: Color(0xFF14B8A6),
          icon: Icons.flash_on_outlined,
          supportsBatchUpdate: true,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('uv tool list');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final lines = LineSplitter.split(
      result.stdout,
    ).map((line) => line.trimRight()).where((line) => line.isNotEmpty).toList();

    final packages = <ManagedPackage>[];
    String? currentName;
    String currentVersion = _unknownVersionLabel;
    final executables = <String>[];

    void flush() {
      if (currentName == null) {
        return;
      }
      packages.add(
        ManagedPackage(
          name: currentName!,
          managerId: definition.id,
          managerName: definition.displayName,
          version: currentVersion,
          executables: List<String>.from(executables),
          notes: executables.isEmpty ? null : '命令: ${executables.join(', ')}',
        ),
      );
      currentName = null;
      currentVersion = _unknownVersionLabel;
      executables.clear();
    }

    final headerPattern = RegExp(r'^(.+?)\s+v([^\s]+)$');
    for (final line in lines) {
      final header = headerPattern.firstMatch(line);
      if (header != null) {
        flush();
        currentName = header.group(1)?.trim();
        currentVersion = header.group(2)?.trim() ?? _unknownVersionLabel;
        continue;
      }

      final executable = line.trimLeft();
      if (executable.startsWith('- ')) {
        executables.add(executable.substring(2).trim());
      }
    }

    flush();
    packages.sort(_packageSort);
    return packages;
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '升级 ${package.name}',
        command: 'uv tool upgrade ${_psQuote(package.name)}',
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: 'uv tool uninstall ${_psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return _command(
      managerId: definition.id,
      label: '批量升级 uv 工具',
      command: 'uv tool upgrade --all',
    );
  }

  @override
  bool supportsLatestVersionLookup(ManagedPackage package) => true;

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'pip index versions ${_psQuote(package.name)} --disable-pip-version-check --no-color',
      timeout: const Duration(seconds: 45),
    );
    return _parsePipLatestVersion(result, managerName: definition.displayName);
  }
}

class CargoAdapter extends PackageManagerAdapter {
  const CargoAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'cargo',
          displayName: 'cargo',
          executable: 'cargo',
          description: 'Rust binaries and CLI tools',
          color: Color(0xFFB45309),
          icon: Icons.precision_manufacturing_outlined,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('cargo install --list');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final packages = <ManagedPackage>[];
    String? currentName;
    String currentVersion = _unknownVersionLabel;
    final binaries = <String>[];

    void flush() {
      if (currentName == null) {
        return;
      }
      packages.add(
        ManagedPackage(
          name: currentName!,
          managerId: definition.id,
          managerName: definition.displayName,
          version: currentVersion,
          executables: List<String>.from(binaries),
          notes: binaries.isEmpty ? null : '可执行文件: ${binaries.join(', ')}',
        ),
      );
      currentName = null;
      currentVersion = _unknownVersionLabel;
      binaries.clear();
    }

    final lines = LineSplitter.split(
      result.stdout,
    ).map((line) => line.trimRight()).where((line) => line.isNotEmpty).toList();
    final headerPattern = RegExp(r'^([\w\-.]+)\s+v([^\s:]+):$');

    for (final line in lines) {
      final header = headerPattern.firstMatch(line);
      if (header != null) {
        flush();
        currentName = header.group(1);
        currentVersion = header.group(2) ?? _unknownVersionLabel;
        continue;
      }

      if (line.startsWith('    ')) {
        binaries.add(line.trim());
      }
    }

    flush();
    packages.sort(_packageSort);
    return packages;
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '重装 ${package.name}',
        command: 'cargo install ${_psQuote(package.name)} --force',
        timeout: const Duration(minutes: 8),
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: 'cargo uninstall ${_psQuote(package.name)}',
      ),
    };
  }

  @override
  bool supportsLatestVersionLookup(ManagedPackage package) => true;

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'cargo search ${_psQuote(package.name)} --limit 5',
      timeout: const Duration(seconds: 45),
    );
    return _parseCargoLatestVersion(
      result,
      managerName: definition.displayName,
      packageName: package.name,
    );
  }
}

class ScoopAdapter extends PackageManagerAdapter {
  const ScoopAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'scoop',
          displayName: 'scoop',
          executable: 'scoop',
          description: 'Windows command-line apps',
          color: Color(0xFF16A34A),
          icon: Icons.inventory_2_outlined,
          supportsBatchUpdate: true,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('scoop list');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final lines = LineSplitter.split(result.stdout)
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final headerLine = lines.cast<String?>().firstWhere(
      (line) => line != null && line.trimLeft().startsWith('Name'),
      orElse: () => null,
    );
    if (headerLine == null) {
      throw PackageAdapterException(definition.displayName, '无法解析 scoop 输出。');
    }

    final headerIndex = lines.indexOf(headerLine);
    final versionStart = headerLine.indexOf('Version');
    final sourceStart = headerLine.indexOf('Source');
    final updatedStart = headerLine.indexOf('Updated');
    final infoStart = headerLine.indexOf('Info');

    if (versionStart < 0 ||
        sourceStart < 0 ||
        updatedStart < 0 ||
        infoStart < 0) {
      throw PackageAdapterException(definition.displayName, '无法识别 scoop 的列布局。');
    }

    final packages = <ManagedPackage>[];
    for (final line in lines.skip(headerIndex + 2)) {
      final name = _sliceColumn(line, 0, versionStart);
      if (name.isEmpty) {
        continue;
      }

      final version = _sliceColumn(line, versionStart, sourceStart);
      final source = _sliceColumn(line, sourceStart, updatedStart);
      final updated = _sliceColumn(line, updatedStart, infoStart);
      final info = _sliceColumn(line, infoStart, null);
      final details = <String>[
        if (updated.isNotEmpty) '更新于: $updated',
        if (info.isNotEmpty) info,
      ].join(' | ');

      packages.add(
        ManagedPackage(
          name: name,
          managerId: definition.id,
          managerName: definition.displayName,
          version: version.isEmpty ? _unknownVersionLabel : version,
          source: source.isEmpty ? null : source,
          notes: details.isEmpty ? null : details,
        ),
      );
    }

    packages.sort(_packageSort);
    return packages;
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'scoop update ${_psQuote(package.name)}',
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: 'scoop uninstall ${_psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return _command(
      managerId: definition.id,
      label: '批量更新 scoop 应用',
      command: 'scoop update *',
      timeout: const Duration(minutes: 8),
    );
  }
}

class ChocolateyAdapter extends PackageManagerAdapter {
  const ChocolateyAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'choco',
          displayName: 'choco',
          executable: 'choco',
          description: 'Chocolatey packages',
          color: Color(0xFF7A3E1D),
          icon: Icons.local_cafe_outlined,
          supportsBatchUpdate: true,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('choco list --local-only --limit-output');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final packages = <ManagedPackage>[];
    for (final line in LineSplitter.split(result.stdout)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.startsWith('Chocolatey v')) {
        continue;
      }
      if (trimmed.startsWith('packages installed.')) {
        continue;
      }

      final separatorIndex = trimmed.indexOf('|');
      if (separatorIndex <= 0 || separatorIndex >= trimmed.length - 1) {
        continue;
      }

      final name = trimmed.substring(0, separatorIndex).trim();
      final version = trimmed.substring(separatorIndex + 1).trim();
      if (name.isEmpty || version.isEmpty) {
        continue;
      }

      packages.add(
        ManagedPackage(
          name: name,
          managerId: definition.id,
          managerName: definition.displayName,
          version: version,
          source: _globalSourceLabel,
        ),
      );
    }

    packages.sort(_packageSort);
    return packages;
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '升级 ${package.name}',
        command: 'choco upgrade ${_psQuote(package.name)} -y',
        timeout: const Duration(minutes: 10),
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: 'choco uninstall ${_psQuote(package.name)} -y',
        timeout: const Duration(minutes: 10),
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return _command(
      managerId: definition.id,
      label: '批量升级 choco 包',
      command: 'choco upgrade all -y',
      timeout: const Duration(minutes: 12),
    );
  }

  @override
  bool supportsLatestVersionLookup(ManagedPackage package) => true;

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'choco search ${_psQuote(package.name)} --exact --limit-output',
      timeout: const Duration(seconds: 45),
    );
    return _parseChocolateyLatestVersion(
      result,
      managerName: definition.displayName,
      packageName: package.name,
    );
  }
}

class WingetAdapter extends PackageManagerAdapter {
  const WingetAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'winget',
          displayName: 'winget',
          executable: 'winget',
          description: 'Installed Windows applications',
          color: Color(0xFF2563EB),
          icon: Icons.window_outlined,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('winget list --disable-interactivity');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final packages = <ManagedPackage>[];
    final lines = LineSplitter.split(result.stdout)
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();

    var contentStarted = false;
    for (final line in lines) {
      if (!contentStarted) {
        if (RegExp(r'^-+$').hasMatch(line.trim())) {
          contentStarted = true;
        }
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == r'\' || trimmed == '-') {
        continue;
      }

      final columns = trimmed.split(RegExp(r'\s{2,}'));
      if (columns.length < 3) {
        continue;
      }
      if (_looksLikeWingetHeaderRow(columns)) {
        continue;
      }

      String? latestVersion;
      String? source;
      if (columns.length >= 5) {
        latestVersion = columns[3];
        source = columns.sublist(4).join('  ');
      } else if (columns.length == 4) {
        source = columns[3];
      }

      packages.add(
        ManagedPackage(
          name: columns[0],
          managerId: definition.id,
          managerName: definition.displayName,
          version: columns[2],
          latestVersion: _normalizeVersion(latestVersion),
          identifier: columns[1],
          source: source,
          notes: latestVersion == null || latestVersion.isEmpty
              ? null
              : '有更新: $latestVersion',
        ),
      );
    }

    packages.sort(_packageSort);
    return packages;
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    final target = package.identifier ?? package.name;
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '升级 ${package.name}',
        command: [
          'winget upgrade',
          '--id ${_psQuote(target)}',
          '--exact',
          '--accept-package-agreements',
          '--accept-source-agreements',
          '--disable-interactivity',
        ].join(' '),
        timeout: const Duration(minutes: 10),
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: [
          'winget uninstall',
          '--id ${_psQuote(target)}',
          '--exact',
          '--accept-source-agreements',
          '--disable-interactivity',
        ].join(' '),
        timeout: const Duration(minutes: 10),
      ),
    };
  }
}

class BunAdapter extends PackageManagerAdapter {
  const BunAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'bun',
          displayName: 'bun',
          executable: 'bun',
          description: 'Bun global packages',
          color: Color(0xFFEAB308),
          icon: Icons.bubble_chart_outlined,
          supportsBatchUpdate: true,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('bun pm bin -g');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final binDirPath = _firstNonEmptyLine(result.stdout);
    if (binDirPath == null) {
      throw PackageAdapterException(
        definition.displayName,
        '无法解析 Bun 全局 bin 目录。',
      );
    }

    final binDir = Directory(binDirPath);
    final bunRoot = binDir.parent.path;
    final globalDir = Directory(
      '$bunRoot${Platform.pathSeparator}install${Platform.pathSeparator}global',
    );
    final globalPackageJson = File(
      '${globalDir.path}${Platform.pathSeparator}package.json',
    );

    if (await globalPackageJson.exists()) {
      final raw = await globalPackageJson.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final dependencies = decoded['dependencies'];
        if (dependencies is Map<String, dynamic>) {
          final packages = <ManagedPackage>[];
          for (final entry in dependencies.entries) {
            packages.add(
              await _readBunPackage(
                packageName: entry.key,
                requestedVersion: '${entry.value}',
                globalDir: globalDir.path,
                binDir: binDir.path,
              ),
            );
          }
          packages.sort(_packageSort);
          return packages;
        }
      }
    }

    return _scanBunBinFallback(binDir.path);
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => _command(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'bun update -g --latest ${_psQuote(package.name)}',
      ),
      PackageAction.remove => _command(
        managerId: definition.id,
        label: '删除 ${package.name}',
        command: 'bun remove -g ${_psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return _command(
      managerId: definition.id,
      label: '批量更新 bun 包',
      command: 'bun update -g --latest',
    );
  }

  @override
  bool supportsLatestVersionLookup(ManagedPackage package) => true;

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'bun pm view ${_psQuote(package.name)} version --json',
      timeout: const Duration(seconds: 45),
    );
    if (result.isSuccess) {
      return _parseSingleVersionValue(
        result,
        managerName: definition.displayName,
      );
    }

    final fallback = await shell.run(
      'npm view ${_psQuote(package.name)} version --json',
      timeout: const Duration(seconds: 45),
    );
    return _parseSingleVersionValue(
      fallback,
      managerName: definition.displayName,
    );
  }

  Future<ManagedPackage> _readBunPackage({
    required String packageName,
    required String requestedVersion,
    required String globalDir,
    required String binDir,
  }) async {
    final packageManifest = File(
      '$globalDir${Platform.pathSeparator}node_modules${Platform.pathSeparator}$packageName${Platform.pathSeparator}package.json',
    );

    if (!await packageManifest.exists()) {
      return ManagedPackage(
        name: packageName,
        managerId: definition.id,
        managerName: definition.displayName,
        version: requestedVersion,
        source: binDir,
      );
    }

    try {
      final raw = await packageManifest.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected object');
      }

      final manifestName = '${decoded['name'] ?? packageName}';
      final manifestVersion = '${decoded['version'] ?? requestedVersion}';
      final executables = _readBunBinEntries(decoded['bin']);

      return ManagedPackage(
        name: manifestName,
        managerId: definition.id,
        managerName: definition.displayName,
        version: manifestVersion,
        source: binDir,
        executables: executables,
        notes: executables.isEmpty ? null : '命令: ${executables.join(', ')}',
      );
    } catch (_) {
      return ManagedPackage(
        name: packageName,
        managerId: definition.id,
        managerName: definition.displayName,
        version: requestedVersion,
        source: binDir,
      );
    }
  }

  Future<List<ManagedPackage>> _scanBunBinFallback(String binDir) async {
    final directory = Directory(binDir);
    if (!await directory.exists()) {
      throw PackageAdapterException(
        definition.displayName,
        'Bun 全局 bin 目录不存在：$binDir',
      );
    }

    final entries = await directory.list().toList();
    final packages = <String, ManagedPackage>{};

    for (final entry in entries) {
      if (entry is! File) {
        continue;
      }

      final fileName = entry.uri.pathSegments.isEmpty
          ? entry.path
          : entry.uri.pathSegments.last;
      final normalized = fileName.toLowerCase();
      if (normalized == 'bun.exe' || normalized == 'bunx.exe') {
        continue;
      }

      final packageName = _normalizeBunExecutableName(fileName);
      if (packageName.isEmpty) {
        continue;
      }

      packages.putIfAbsent(
        packageName,
        () => ManagedPackage(
          name: packageName,
          managerId: definition.id,
          managerName: definition.displayName,
          version: _unknownVersionLabel,
          source: binDir,
          notes: '从 Bun bin 目录推断',
        ),
      );
    }

    final values = packages.values.toList()..sort(_packageSort);
    return values;
  }
}

class PackageAdapterException implements Exception {
  const PackageAdapterException(this.managerName, this.message);

  final String managerName;
  final String message;

  @override
  String toString() => '$managerName 失败：$message';
}

PackageCommand _command({
  required String managerId,
  required String label,
  required String command,
  Duration timeout = const Duration(minutes: 5),
}) {
  return PackageCommand(
    managerId: managerId,
    busyKey: '$managerId::$label',
    label: label,
    command: command,
    timeout: timeout,
  );
}

dynamic _decodeJson(ShellResult result, {required String managerName}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final raw = _extractJsonPayload(result.stdout);
  try {
    return jsonDecode(raw);
  } on FormatException catch (error) {
    throw PackageAdapterException(managerName, '解析 JSON 输出失败：$error');
  }
}

Map<String, dynamic> _decodeJsonObject(
  ShellResult result, {
  required String managerName,
}) {
  final decoded = _decodeJson(result, managerName: managerName);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw PackageAdapterException(managerName, '返回结果不是 JSON 对象。');
}

List<Map<String, dynamic>> _decodeJsonArray(
  ShellResult result, {
  required String managerName,
}) {
  final decoded = _decodeJson(result, managerName: managerName);
  if (decoded is List) {
    return decoded.cast<Map<String, dynamic>>();
  }
  throw PackageAdapterException(managerName, '返回结果不是 JSON 数组。');
}

String _extractJsonPayload(String output) {
  final trimmed = output.trim();
  final arrayStart = trimmed.indexOf('[');
  final objectStart = trimmed.indexOf('{');

  final starts = <int>[
    if (arrayStart >= 0) arrayStart,
    if (objectStart >= 0) objectStart,
  ]..sort();

  if (starts.isEmpty) {
    return trimmed;
  }

  final start = starts.first;
  final end = [trimmed.lastIndexOf(']'), trimmed.lastIndexOf('}')]..sort();

  final last = end.last;
  if (last < start) {
    return trimmed.substring(start);
  }

  return trimmed.substring(start, last + 1);
}

String _psQuote(String value) {
  return "'${value.replaceAll("'", "''")}'";
}

String? _normalizeVersion(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return text;
}

String _stringOrUnknown(Object? value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty) {
    return _unknownVersionLabel;
  }
  return text;
}

int _packageSort(ManagedPackage a, ManagedPackage b) {
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

String _sliceColumn(String line, int start, int? end) {
  if (start >= line.length) {
    return '';
  }
  final raw = end == null || end > line.length
      ? line.substring(start)
      : line.substring(start, end);
  return raw.trim();
}

String? _firstNonEmptyLine(String text) {
  for (final line in LineSplitter.split(text)) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

List<String> _readBunBinEntries(Object? value) {
  if (value is String) {
    return const <String>[];
  }
  if (value is Map<String, dynamic>) {
    return value.keys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toList()
      ..sort();
  }
  return const <String>[];
}

String _normalizeBunExecutableName(String fileName) {
  var name = fileName.trim();
  final lower = name.toLowerCase();
  if (lower.endsWith('.exe')) {
    name = name.substring(0, name.length - 4);
  } else if (lower.endsWith('.bunx')) {
    name = name.substring(0, name.length - 5);
  } else if (lower.endsWith('.cmd')) {
    name = name.substring(0, name.length - 4);
  } else if (lower.endsWith('.ps1')) {
    name = name.substring(0, name.length - 4);
  }
  return name;
}

String _parseSingleVersionValue(
  ShellResult result, {
  required String managerName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final trimmed = result.stdout.trim();
  if (trimmed.isEmpty) {
    throw PackageAdapterException(managerName, '没有返回版本信息。');
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
  } catch (_) {
    // Fall back to plain-text parsing below.
  }

  final firstLine = _firstNonEmptyLine(trimmed);
  if (firstLine == null || firstLine.isEmpty) {
    throw PackageAdapterException(managerName, '没有返回版本信息。');
  }
  return firstLine.replaceAll('"', '').trim();
}

String _parsePipLatestVersion(
  ShellResult result, {
  required String managerName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    if (trimmed.startsWith('LATEST:')) {
      final latest = trimmed.substring('LATEST:'.length).trim();
      if (latest.isNotEmpty) {
        return latest;
      }
    }
  }

  throw PackageAdapterException(managerName, '无法从 pip 输出中解析最新版本。');
}

String _parseCargoLatestVersion(
  ShellResult result, {
  required String managerName,
  required String packageName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final exactPattern = RegExp(
    '^${RegExp.escape(packageName)}\\s*=\\s*"([^"]+)"',
    caseSensitive: false,
  );
  final genericPattern = RegExp(r'^[^=]+\s*=\s*"([^"]+)"');

  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    final exactMatch = exactPattern.firstMatch(trimmed);
    if (exactMatch != null) {
      return exactMatch.group(1)!.trim();
    }
  }

  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    final genericMatch = genericPattern.firstMatch(trimmed);
    if (genericMatch != null) {
      return genericMatch.group(1)!.trim();
    }
  }

  throw PackageAdapterException(managerName, '无法从 cargo 搜索结果中解析最新版本。');
}

String _parseChocolateyLatestVersion(
  ShellResult result, {
  required String managerName,
  required String packageName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('Chocolatey v') ||
        trimmed.startsWith('packages found.')) {
      continue;
    }

    final separatorIndex = trimmed.indexOf('|');
    if (separatorIndex <= 0 || separatorIndex >= trimmed.length - 1) {
      continue;
    }

    final name = trimmed.substring(0, separatorIndex).trim();
    final version = trimmed.substring(separatorIndex + 1).trim();
    if (name.toLowerCase() == packageName.toLowerCase() && version.isNotEmpty) {
      return version;
    }
  }

  throw PackageAdapterException(managerName, '无法从 choco 输出中解析最新版本。');
}

bool _looksLikeWingetHeaderRow(List<String> columns) {
  if (columns.length < 4) {
    return false;
  }

  final name = columns[0].trim().toLowerCase();
  final identifier = columns[1].trim().toLowerCase();
  final version = columns[2].trim().toLowerCase();
  final fourth = columns[3].trim().toLowerCase();
  final trailing = columns.length > 4
      ? columns.sublist(4).join(' ').trim().toLowerCase()
      : '';

  final headerNames = <String>{'name', '名称'};
  final headerIdentifiers = <String>{'id', 'identifier', '标识', '软件包标识'};
  final headerVersions = <String>{'version', '版本'};
  final headerAvailable = <String>{'available', '可用'};
  final headerSource = <String>{'source', '源'};

  final hasHeaderName = headerNames.contains(name);
  final hasHeaderIdentifier = headerIdentifiers.contains(identifier);
  final hasHeaderVersion = headerVersions.contains(version);
  final hasHeaderAvailable = headerAvailable.contains(fourth);
  final hasHeaderSource =
      headerSource.contains(fourth) || headerSource.contains(trailing);

  return hasHeaderName &&
      hasHeaderVersion &&
      (hasHeaderIdentifier || hasHeaderAvailable || hasHeaderSource);
}

const String _unknownVersionLabel = '未知';
const String _globalSourceLabel = '全局';
