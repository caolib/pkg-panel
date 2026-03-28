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
        PackageActionCapability,
        PackageBatchUpdateCapability,
        LatestVersionLookupCapability {
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
    final result = await shell.run(
      'choco search ${psQuote(query)} --limit-output',
      timeout: const Duration(seconds: 45),
    );
    return parseChocolateySearchResults(result, manager: definition);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      command: 'choco install ${psQuote(package.packageName)} -y',
      timeout: const Duration(minutes: 12),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '升级 ${package.name}',
        command: 'choco upgrade ${psQuote(package.name)} -y',
        timeout: const Duration(minutes: 10),
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
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
      command: 'choco upgrade all -y',
      timeout: const Duration(minutes: 12),
    );
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'choco search ${psQuote(package.name)} --exact --limit-output',
      timeout: const Duration(seconds: 45),
    );
    return parseChocolateyLatestVersion(
      result,
      managerName: definition.displayName,
      packageName: package.name,
    );
  }
}
