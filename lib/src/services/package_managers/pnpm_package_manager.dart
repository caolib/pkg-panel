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
        VersionedPackageInstallCapability,
        LatestTagInstallCapability,
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
    final result = await shell.runExecutable('pnpm', const <String>[
      'ls',
      '-g',
      '--depth=0',
      '--json',
    ], displayCommand: 'pnpm ls -g --depth=0 --json');
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
    final result = await shell.runExecutable(
      'pnpm',
      <String>['search', query, '--json', '--searchlimit=20'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'pnpm search ${psQuote(query)} --json --searchlimit=20',
    );
    return parseNpmSearchResults(result, manager: definition);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    final target = package.identifier ?? package.packageName;
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      executable: 'pnpm',
      arguments: <String>['add', '-g', target],
      command: 'pnpm add -g ${psQuote(target)}',
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
      'pnpm',
      <String>['view', target, 'versions', '--json'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'pnpm view ${psQuote(target)} versions --json',
    );
    if (result.isSuccess) {
      return PackageVersionQueryResult(
        versions: parseVersionListValue(
          result,
          managerName: definition.displayName,
          newestFirst: true,
        ),
      );
    }

    final fallback = await shell.runExecutable(
      'npm',
      <String>['view', target, 'versions', '--json'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'npm view ${psQuote(target)} versions --json',
    );
    return PackageVersionQueryResult(
      versions: parseVersionListValue(
        fallback,
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
      executable: 'pnpm',
      arguments: <String>['add', '-g', spec],
      command: 'pnpm add -g ${psQuote(spec)}',
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
      executable: 'pnpm',
      arguments: <String>['add', '-g', spec],
      command: 'pnpm add -g ${psQuote(spec)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '更新 ${package.name}',
        executable: 'pnpm',
        arguments: <String>['update', '-g', '--latest', package.name],
        command: 'pnpm update -g --latest ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '删除 ${package.name}',
        executable: 'pnpm',
        arguments: <String>['remove', '-g', package.name],
        command: 'pnpm remove -g ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量更新 pnpm 包',
      executable: 'pnpm',
      arguments: const <String>['update', '-g', '--latest'],
      command: 'pnpm update -g --latest',
    );
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.runExecutable(
      'pnpm',
      <String>['info', package.name],
      timeout: const Duration(seconds: 45),
      displayCommand: 'pnpm info ${psQuote(package.name)}',
    );
    return parseDetailOutput(result, managerName: definition.displayName);
  }

  @override
  String latestVersionLookupCommand(ManagedPackage package) {
    return 'pnpm view ${psQuote(package.name)} version --json';
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.runExecutable(
      'pnpm',
      <String>['view', package.name, 'version', '--json'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'pnpm view ${psQuote(package.name)} version --json',
    );
    if (result.isSuccess) {
      return parseSingleVersionValue(
        result,
        managerName: definition.displayName,
      );
    }

    final fallback = await shell.runExecutable(
      'npm',
      <String>['view', package.name, 'version', '--json'],
      timeout: const Duration(seconds: 45),
      displayCommand: 'npm view ${psQuote(package.name)} version --json',
    );
    return parseSingleVersionValue(
      fallback,
      managerName: definition.displayName,
    );
  }
}
