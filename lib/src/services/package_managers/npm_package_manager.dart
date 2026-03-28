import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class NpmAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageSearchCapability,
        PackageInstallCapability,
        PackageActionCapability,
        PackageBatchUpdateCapability,
        LatestVersionLookupCapability,
        PackageDetailsCapability {
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
    final payload = decodeJsonObject(
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
        version: stringOrUnknown(package['version']),
        source: globalSourceLabel,
      );
    }).toList()..sort(packageSort);
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
      command: 'npm install -g ${psQuote(package.packageName)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'npm update -g ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '删除 ${package.name}',
        command: 'npm uninstall -g ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量更新 npm 包',
      command: 'npm update -g',
    );
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'npm view ${psQuote(package.name)}',
      timeout: const Duration(seconds: 45),
    );
    return parseDetailOutput(result, managerName: definition.displayName);
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'npm view ${psQuote(package.name)} version --json',
      timeout: const Duration(seconds: 45),
    );
    return parseSingleVersionValue(result, managerName: definition.displayName);
  }
}
