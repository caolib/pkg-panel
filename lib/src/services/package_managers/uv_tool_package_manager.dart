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
    final result = await shell.run('uv tool list');
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
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      command: 'uv tool install ${psQuote(package.packageName)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '升级 ${package.name}',
        command: 'uv tool upgrade ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: 'uv tool uninstall ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量升级 uv 工具',
      command: 'uv tool upgrade --all',
    );
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'uv tool list',
      timeout: const Duration(seconds: 45),
    );
    return extractUvToolDetails(
      result,
      managerName: definition.displayName,
      packageName: package.name,
    );
  }

  @override
  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final result = await shell.run(
      'pip index versions ${psQuote(package.name)} --disable-pip-version-check --no-color',
      timeout: const Duration(seconds: 45),
    );
    return parsePipLatestVersion(result, managerName: definition.displayName);
  }
}
