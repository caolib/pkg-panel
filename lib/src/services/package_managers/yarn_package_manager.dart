import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class YarnAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageInstallCapability,
        VersionedPackageInstallCapability,
        LatestTagInstallCapability,
        PackageActionCapability,
        PackageBatchUpdateCapability,
        LatestVersionLookupCapability,
        PackageDetailsCapability {
  const YarnAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'yarn',
          displayName: 'yarn',
          executable: 'yarn',
          description: 'Yarn Classic (v1) global packages（不支持 Yarn Berry v2+）',
          color: Color(0xFF2C8EBB),
          icon: Icons.change_history_outlined,
          supportsBatchUpdate: true,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.runExecutable('yarn', const <String>[
      'global',
      'dir',
    ], displayCommand: 'yarn global dir');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final globalDirPath = firstNonEmptyLine(result.stdout);
    if (globalDirPath == null) {
      throw PackageAdapterException(definition.displayName, '无法解析 Yarn 全局目录。');
    }

    final globalDir = Directory(globalDirPath);
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
              await _readYarnPackage(
                packageName: entry.key,
                requestedVersion: '${entry.value}',
                globalDirPath: globalDir.path,
              ),
            );
          }
          packages.sort(packageSort);
          return packages;
        }
      }
    }

    return _scanYarnNodeModulesFallback(globalDir.path);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    final target = package.identifier ?? package.packageName;
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      executable: 'yarn',
      arguments: <String>['global', 'add', target],
      command: 'yarn global add ${psQuote(target)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  Future<PackageVersionQueryResult> listInstallableVersions(
    ShellExecutor shell,
    SearchPackageInstallOption package,
  ) async {
    final target = package.identifier ?? package.packageName;
    final result = await shell.runExecutable(
      'npm',
      <String>['view', target, 'versions', '--json'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'npm view ${psQuote(target)} versions --json',
    );
    return PackageVersionQueryResult(
      versions: parseVersionListValue(
        result,
        managerName: definition.displayName,
        newestFirst: true,
      ),
    );
  }

  @override
  PackageCommand buildLatestInstallCommand(SearchPackageInstallOption package) {
    final target = package.identifier ?? package.packageName;
    final spec = '$target@latest';
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}@latest',
      executable: 'yarn',
      arguments: <String>['global', 'add', spec],
      command: 'yarn global add ${psQuote(spec)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildVersionedInstallCommand(
    SearchPackageInstallOption package,
    String version,
  ) {
    final target = package.identifier ?? package.packageName;
    final spec = '$target@${version.trim()}';
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}@${version.trim()}',
      executable: 'yarn',
      arguments: <String>['global', 'add', spec],
      command: 'yarn global add ${psQuote(spec)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '更新 ${package.name}',
        executable: 'yarn',
        arguments: <String>['global', 'upgrade', package.name],
        command: 'yarn global upgrade ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '删除 ${package.name}',
        executable: 'yarn',
        arguments: <String>['global', 'remove', package.name],
        command: 'yarn global remove ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量更新 yarn 包',
      executable: 'yarn',
      arguments: const <String>['global', 'upgrade'],
      command: 'yarn global upgrade',
    );
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final target = package.identifier ?? package.name;
    final result = await shell.runExecutable(
      'npm',
      <String>['view', target],
      timeout: const Duration(seconds: 45),
      displayCommand: 'npm view ${psQuote(target)}',
    );
    return parseDetailOutput(result, managerName: definition.displayName);
  }

  @override
  String latestVersionLookupCommand(ManagedPackage package) {
    final target = package.identifier ?? package.name;
    return 'npm view ${psQuote(target)} version --json';
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final target = package.identifier ?? package.name;
    final result = await shell.runExecutable(
      'npm',
      <String>['view', target, 'version', '--json'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'npm view ${psQuote(target)} version --json',
    );
    return parseSingleVersionValue(result, managerName: definition.displayName);
  }

  Future<ManagedPackage> _readYarnPackage({
    required String packageName,
    required String requestedVersion,
    required String globalDirPath,
  }) async {
    final manifestPath = [
      globalDirPath,
      'node_modules',
      ...packageName.split('/'),
      'package.json',
    ].join(Platform.pathSeparator);
    final packageManifest = File(manifestPath);

    if (!await packageManifest.exists()) {
      return ManagedPackage(
        name: packageName,
        managerId: definition.id,
        managerName: definition.displayName,
        version: requestedVersion,
        source: globalSourceLabel,
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
      final executables = _readNodeBinEntries(decoded['bin']);

      return ManagedPackage(
        name: manifestName,
        managerId: definition.id,
        managerName: definition.displayName,
        version: manifestVersion,
        source: globalSourceLabel,
        executables: executables,
        notes: executables.isEmpty ? null : '命令: ${executables.join(', ')}',
      );
    } catch (_) {
      return ManagedPackage(
        name: packageName,
        managerId: definition.id,
        managerName: definition.displayName,
        version: requestedVersion,
        source: globalSourceLabel,
      );
    }
  }

  Future<List<ManagedPackage>> _scanYarnNodeModulesFallback(
    String globalDirPath,
  ) async {
    final nodeModulesDir = Directory(
      '$globalDirPath${Platform.pathSeparator}node_modules',
    );
    if (!await nodeModulesDir.exists()) {
      throw PackageAdapterException(
        definition.displayName,
        'Yarn 全局 node_modules 目录不存在：${nodeModulesDir.path}',
      );
    }

    final packageNames = await _listYarnNodeModulePackageNames(nodeModulesDir);
    final packages = <ManagedPackage>[];
    for (final packageName in packageNames) {
      packages.add(
        await _readYarnPackage(
          packageName: packageName,
          requestedVersion: unknownVersionLabel,
          globalDirPath: globalDirPath,
        ),
      );
    }
    packages.sort(packageSort);
    return packages;
  }

  Future<List<String>> _listYarnNodeModulePackageNames(
    Directory nodeModulesDir,
  ) async {
    final packageNames = <String>[];
    await for (final entry in nodeModulesDir.list()) {
      if (entry is! Directory) {
        continue;
      }

      final name = entry.uri.pathSegments.isEmpty
          ? entry.path
          : entry.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);
      if (name.startsWith('.')) {
        continue;
      }

      if (name.startsWith('@')) {
        await for (final scopedEntry in entry.list()) {
          if (scopedEntry is! Directory) {
            continue;
          }
          final scopedName = scopedEntry.uri.pathSegments.lastWhere(
            (segment) => segment.isNotEmpty,
          );
          if (scopedName.startsWith('.')) {
            continue;
          }
          packageNames.add('$name/$scopedName');
        }
        continue;
      }

      packageNames.add(name);
    }
    return packageNames;
  }
}

List<String> _readNodeBinEntries(Object? value) {
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
