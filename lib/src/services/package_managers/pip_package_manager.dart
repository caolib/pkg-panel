import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class PipAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        VersionedPackageInstallCapability,
        PackageActionCapability,
        LatestVersionLookupCapability,
        PackageDetailsCapability {
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
    final result = await shell.runExecutable(
      'pip',
      const <String>['list', '--format=json'],
      displayCommand: 'pip list --format=json',
    );
    final payload = decodeJsonArray(
      result,
      managerName: definition.displayName,
    );

    return payload.map((entry) {
      return ManagedPackage(
        name: stringOrUnknown(entry['name']),
        managerId: definition.id,
        managerName: definition.displayName,
        version: stringOrUnknown(entry['version']),
        notes: entry['editable_project_location'] == null
            ? null
            : '可编辑路径: ${entry['editable_project_location']}',
      );
    }).toList()..sort(packageSort);
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
      executable: 'pip',
      arguments: <String>['install', '$target==$normalizedVersion'],
      command: 'pip install ${psQuote('$target==$normalizedVersion')}',
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '升级 ${package.name}',
        executable: 'pip',
        arguments: <String>['install', '--upgrade', package.name],
        command: 'pip install --upgrade ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        executable: 'pip',
        arguments: <String>['uninstall', '-y', package.name],
        command: 'pip uninstall -y ${psQuote(package.name)}',
      ),
    };
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.runExecutable(
      'pip',
      <String>['show', package.name],
      timeout: const Duration(seconds: 45),
      displayCommand: 'pip show ${psQuote(package.name)}',
    );
    return parseDetailOutput(result, managerName: definition.displayName);
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
