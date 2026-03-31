import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class CargoAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageSearchCapability,
        PackageInstallCapability,
        PackageActionCapability,
        LatestVersionLookupCapability,
        BatchLatestVersionLookupCapability,
        PackageDetailsCapability {
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
    final result = await shell.runExecutable('cargo', const <String>[
      'install',
      '--list',
    ], displayCommand: 'cargo install --list');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final packages = <ManagedPackage>[];
    String? currentName;
    String currentVersion = unknownVersionLabel;
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
          notes: binaries.isEmpty ? null : '文件 ${binaries.join(', ')}',
        ),
      );
      currentName = null;
      currentVersion = unknownVersionLabel;
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
        currentVersion = header.group(2) ?? unknownVersionLabel;
        continue;
      }

      if (line.startsWith('    ')) {
        binaries.add(line.trim());
      }
    }

    flush();
    packages.sort(packageSort);
    return packages;
  }

  @override
  Future<List<SearchPackage>> searchPackages(
    ShellExecutor shell,
    String query,
  ) async {
    final result = await shell.runExecutable(
      'cargo',
      <String>['search', query, '--registry', 'crates-io', '--limit', '20'],
      timeout: const Duration(seconds: 45),
      displayCommand:
          'cargo search ${psQuote(query)} --registry crates-io --limit 20',
    );
    return parseCargoSearchResults(result, manager: definition);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      executable: 'cargo',
      arguments: <String>['install', package.packageName],
      command: 'cargo install ${psQuote(package.packageName)}',
      timeout: const Duration(minutes: 12),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '重装 ${package.name}',
        executable: 'cargo',
        arguments: <String>['install', package.name, '--force'],
        command: 'cargo install ${psQuote(package.name)} --force',
        timeout: const Duration(minutes: 8),
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        executable: 'cargo',
        arguments: <String>['uninstall', package.name],
        command: 'cargo uninstall ${psQuote(package.name)}',
      ),
    };
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.runExecutable(
      'cargo',
      <String>['info', package.name, '--registry', 'crates-io'],
      timeout: const Duration(seconds: 45),
      displayCommand:
          'cargo info ${psQuote(package.name)} --registry crates-io',
    );
    return parseDetailOutput(result, managerName: definition.displayName);
  }

  @override
  String latestVersionLookupCommand(ManagedPackage package) {
    return 'cargo search ${psQuote(package.name)} --registry crates-io --limit 5';
  }

  @override
  String batchLatestVersionLookupCommand(List<ManagedPackage> packages) {
    return 'cargo search --registry crates-io（逐个查询 ${packages.length} 个包）';
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.runExecutable(
      'cargo',
      <String>[
        'search',
        package.name,
        '--registry',
        'crates-io',
        '--limit',
        '5',
      ],
      timeout: const Duration(seconds: 45),
      displayCommand: latestVersionLookupCommand(package),
    );
    return parseCargoLatestVersion(
      result,
      managerName: definition.displayName,
      packageName: package.name,
    );
  }

  @override
  Future<Map<String, String>> lookupLatestVersions(
    ShellExecutor shell,
    List<ManagedPackage> packages,
  ) async {
    if (packages.isEmpty) {
      return const <String, String>{};
    }

    final latestByPackageKey = <String, String>{};
    for (final package in packages) {
      final result = await shell.runExecutable(
        'cargo',
        <String>[
          'search',
          package.name,
          '--registry',
          'crates-io',
          '--limit',
          '5',
        ],
        timeout: const Duration(seconds: 45),
        displayCommand: latestVersionLookupCommand(package),
      );
      latestByPackageKey[package.key] = parseCargoLatestVersion(
        result,
        managerName: definition.displayName,
        packageName: package.name,
      );
    }
    return latestByPackageKey;
  }
}
