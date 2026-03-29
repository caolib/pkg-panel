import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class ChocolateyAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageSearchCapability,
        PackageInstallCapability,
        VersionedPackageInstallCapability,
        PackageActionCapability,
        PackageBatchUpdateCapability,
        LatestVersionLookupCapability,
        BatchLatestVersionLookupCapability {
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
    final result = await shell.runExecutable(
      'choco',
      const <String>['list', '--local-only', '--limit-output'],
      displayCommand: 'choco list --local-only --limit-output',
    );
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final packages = <ManagedPackage>[];
    for (final line in LineSplitter.split(result.stdout)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('Chocolatey v') ||
          trimmed.startsWith('packages installed.')) {
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
          source: globalSourceLabel,
        ),
      );
    }

    packages.sort(packageSort);
    return packages;
  }

  @override
  Future<List<SearchPackage>> searchPackages(
    ShellExecutor shell,
    String query,
  ) async {
    final result = await shell.runExecutable(
      'choco',
      <String>['search', query, '--limit-output'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'choco search ${psQuote(query)} --limit-output',
    );
    return parseChocolateySearchResults(result, manager: definition);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    final target = package.identifier ?? package.packageName;
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      executable: 'choco',
      arguments: <String>['install', target, '-y'],
      command: 'choco install ${psQuote(target)} -y',
      timeout: const Duration(minutes: 12),
    );
  }

  @override
  Future<PackageVersionQueryResult> listInstallableVersions(
    ShellExecutor shell,
    SearchPackageInstallOption package,
  ) async {
    final target = package.identifier ?? package.packageName;
    final result = await shell.runExecutable(
      'choco',
      <String>[
        'search',
        target,
        '--exact',
        '--all-versions',
        '--limit-output',
      ],
      timeout: const Duration(seconds: 45),
      displayCommand:
          'choco search ${psQuote(target)} --exact --all-versions --limit-output',
    );
    return PackageVersionQueryResult(
      versions: parseChocolateyVersionList(
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
      label: '安装 ${package.packageName}@$normalizedVersion',
      executable: 'choco',
      arguments: <String>[
        'install',
        target,
        '--version',
        normalizedVersion,
        '--allow-downgrade',
        '-y',
      ],
      command: [
        'choco install ${psQuote(target)}',
        '--version ${psQuote(normalizedVersion)}',
        '--allow-downgrade',
        '-y',
      ].join(' '),
      timeout: const Duration(minutes: 12),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '升级 ${package.name}',
        executable: 'choco',
        arguments: <String>['upgrade', package.name, '-y'],
        command: 'choco upgrade ${psQuote(package.name)} -y',
        timeout: const Duration(minutes: 10),
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        executable: 'choco',
        arguments: <String>['uninstall', package.name, '-y'],
        command: 'choco uninstall ${psQuote(package.name)} -y',
        timeout: const Duration(minutes: 10),
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量升级 choco 包',
      executable: 'choco',
      arguments: const <String>['upgrade', 'all', '-y'],
      command: 'choco upgrade all -y',
      timeout: const Duration(minutes: 12),
    );
  }

  @override
  String latestVersionLookupCommand(ManagedPackage package) {
    return 'choco outdated';
  }

  @override
  String batchLatestVersionLookupCommand(List<ManagedPackage> packages) {
    return 'choco outdated';
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final latestVersions = await lookupLatestVersions(shell, <ManagedPackage>[
      package,
    ]);
    return latestVersions[package.key] ?? package.version;
  }

  @override
  Future<Map<String, String>> lookupLatestVersions(
    ShellExecutor shell,
    List<ManagedPackage> packages,
  ) async {
    if (packages.isEmpty) {
      return const <String, String>{};
    }

    final result = await shell.runExecutable(
      'choco',
      const <String>['outdated'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'choco outdated',
    );
    final latestByName = parseChocolateyOutdatedLatestVersions(
      result,
      managerName: definition.displayName,
    );
    return <String, String>{
      for (final package in packages)
        package.key: latestByName[package.name.trim().toLowerCase()] ?? package.version,
    };
  }
}
