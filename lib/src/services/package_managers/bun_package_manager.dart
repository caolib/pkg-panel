import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class BunAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageSearchCapability,
        PackageInstallCapability,
        PackageActionCapability,
        PackageBatchUpdateCapability,
        LatestVersionLookupCapability,
        PackageDetailsCapability {
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

    final binDirPath = firstNonEmptyLine(result.stdout);
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
          packages.sort(packageSort);
          return packages;
        }
      }
    }

    return _scanBunBinFallback(binDir.path);
  }

  @override
  Future<List<SearchPackage>> searchPackages(
    ShellExecutor shell,
    String query,
  ) async {
    final result = await shell.run(
      'npm search ${psQuote(query)} --json --searchlimit=20',
      timeout: const Duration(seconds: 45),
    );
    return parseNpmSearchResults(result, manager: definition);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      command: 'bun add -g ${psQuote(package.packageName)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'bun update -g --latest ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '删除 ${package.name}',
        command: 'bun remove -g ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量更新 bun 包',
      command: 'bun update -g --latest',
    );
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'bun pm view ${psQuote(package.name)}',
      timeout: const Duration(seconds: 45),
    );
    if (result.isSuccess) {
      return parseDetailOutput(result, managerName: definition.displayName);
    }
    final fallback = await shell.run(
      'npm view ${psQuote(package.name)}',
      timeout: const Duration(seconds: 45),
    );
    return parseDetailOutput(fallback, managerName: definition.displayName);
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'bun pm view ${psQuote(package.name)} version --json',
      timeout: const Duration(seconds: 45),
    );
    if (result.isSuccess) {
      return parseSingleVersionValue(
        result,
        managerName: definition.displayName,
      );
    }

    final fallback = await shell.run(
      'npm view ${psQuote(package.name)} version --json',
      timeout: const Duration(seconds: 45),
    );
    return parseSingleVersionValue(
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
          version: unknownVersionLabel,
          source: binDir,
          notes: '从 Bun bin 目录推断',
        ),
      );
    }

    final values = packages.values.toList()..sort(packageSort);
    return values;
  }
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
