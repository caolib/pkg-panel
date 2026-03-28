import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class PnpmAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageSearchCapability,
        PackageInstallCapability,
        PackageActionCapability,
        PackageBatchUpdateCapability,
        LatestVersionLookupCapability,
        PackageDetailsCapability {
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
    final payload = decodeJson(result, managerName: definition.displayName);
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

    packages.sort(packageSort);
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
            version: stringOrUnknown(dependency['version']),
            source: '${node['path'] ?? globalSourceLabel}',
          ),
        );
      }
    }
    return output;
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
      command: 'pnpm add -g ${psQuote(package.packageName)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'pnpm update -g --latest ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '删除 ${package.name}',
        command: 'pnpm remove -g ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量更新 pnpm 包',
      command: 'pnpm update -g --latest',
    );
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'pnpm info ${psQuote(package.name)}',
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
      'pnpm view ${psQuote(package.name)} version --json',
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
}
