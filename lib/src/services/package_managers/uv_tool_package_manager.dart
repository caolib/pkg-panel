import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class UvToolAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageInstallCapability,
        VersionedPackageInstallCapability,
        PackageActionCapability,
        PackageBatchUpdateCapability,
        LatestVersionLookupCapability,
        PackageDetailsCapability {
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
    final result = await shell.runExecutable(
      'uv',
      const <String>['tool', 'list'],
      displayCommand: 'uv tool list',
    );
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
    String currentVersion = unknownVersionLabel;
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
      currentVersion = unknownVersionLabel;
      executables.clear();
    }

    final headerPattern = RegExp(r'^(.+?)\s+v([^\s]+)$');
    for (final line in lines) {
      final header = headerPattern.firstMatch(line);
      if (header != null) {
        flush();
        currentName = header.group(1)?.trim();
        currentVersion = header.group(2)?.trim() ?? unknownVersionLabel;
        continue;
      }

      final executable = line.trimLeft();
      if (executable.startsWith('- ')) {
        executables.add(executable.substring(2).trim());
      }
    }

    flush();
    packages.sort(packageSort);
    return packages;
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    final target = package.identifier ?? package.packageName;
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      executable: 'uv',
      arguments: <String>['tool', 'install', target],
      command: 'uv tool install ${psQuote(target)}',
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
      'pip',
      <String>[
        'index',
        'versions',
        target,
        '--disable-pip-version-check',
        '--no-color',
      ],
      timeout: const Duration(seconds: 45),
      displayCommand:
          'pip index versions ${psQuote(target)} --disable-pip-version-check --no-color',
    );
    return PackageVersionQueryResult(
      versions: parsePipVersionList(
        result,
        managerName: definition.displayName,
      ),
    );
  }

  @override
  PackageCommand buildVersionedInstallCommand(
    SearchPackageInstallOption package,
    String version,
  ) {
    final target = package.identifier ?? package.packageName;
    final normalizedVersion = version.trim();
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}==$normalizedVersion',
      executable: 'uv',
      arguments: <String>[
        'tool',
        'install',
        '$target==$normalizedVersion',
        '--reinstall',
      ],
      command:
          'uv tool install ${psQuote('$target==$normalizedVersion')} --reinstall',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '升级 ${package.name}',
        executable: 'uv',
        arguments: <String>['tool', 'upgrade', package.name],
        command: 'uv tool upgrade ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        executable: 'uv',
        arguments: <String>['tool', 'uninstall', package.name],
        command: 'uv tool uninstall ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量升级 uv 工具',
      executable: 'uv',
      arguments: const <String>['tool', 'upgrade', '--all'],
      command: 'uv tool upgrade --all',
    );
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.runExecutable(
      'uv',
      const <String>['tool', 'list'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'uv tool list',
    );
    return extractUvToolDetails(
      result,
      managerName: definition.displayName,
      packageName: package.name,
    );
  }

  @override
  String latestVersionLookupCommand(ManagedPackage package) {
    return 'pip index versions ${psQuote(package.name)} --disable-pip-version-check --no-color';
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.runExecutable(
      'pip',
      <String>[
        'index',
        'versions',
        package.name,
        '--disable-pip-version-check',
        '--no-color',
      ],
      timeout: const Duration(seconds: 45),
      displayCommand:
          'pip index versions ${psQuote(package.name)} --disable-pip-version-check --no-color',
    );
    return parsePipLatestVersion(result, managerName: definition.displayName);
  }
}
