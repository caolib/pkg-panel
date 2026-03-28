import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class ScoopAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageSearchCapability,
        PackageInstallCapability,
        PackageActionCapability,
        PackageBatchUpdateCapability {
  const ScoopAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'scoop',
          displayName: 'scoop',
          executable: 'scoop',
          description: 'Windows command-line apps',
          color: Color(0xFF16A34A),
          icon: Icons.inventory_2_outlined,
          supportsBatchUpdate: true,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('scoop list');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final lines = LineSplitter.split(result.stdout)
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final headerLine = lines.cast<String?>().firstWhere(
      (line) => line != null && line.trimLeft().startsWith('Name'),
      orElse: () => null,
    );
    if (headerLine == null) {
      throw PackageAdapterException(definition.displayName, '无法解析 scoop 输出。');
    }

    final headerIndex = lines.indexOf(headerLine);
    final versionStart = headerLine.indexOf('Version');
    final sourceStart = headerLine.indexOf('Source');
    final updatedStart = headerLine.indexOf('Updated');
    final infoStart = headerLine.indexOf('Info');

    if (versionStart < 0 ||
        sourceStart < 0 ||
        updatedStart < 0 ||
        infoStart < 0) {
      throw PackageAdapterException(definition.displayName, '无法识别 scoop 的列布局。');
    }

    final packages = <ManagedPackage>[];
    for (final line in lines.skip(headerIndex + 2)) {
      final name = sliceColumn(line, 0, versionStart);
      if (name.isEmpty) {
        continue;
      }

      final version = sliceColumn(line, versionStart, sourceStart);
      final source = sliceColumn(line, sourceStart, updatedStart);
      final updated = sliceColumn(line, updatedStart, infoStart);
      final info = sliceColumn(line, infoStart, null);
      final details = <String>[
        if (updated.isNotEmpty) '更新于: $updated',
        if (info.isNotEmpty) info,
      ].join(' | ');

      packages.add(
        ManagedPackage(
          name: name,
          managerId: definition.id,
          managerName: definition.displayName,
          version: version.isEmpty ? unknownVersionLabel : version,
          source: source.isEmpty ? null : source,
          notes: details.isEmpty ? null : details,
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
      'scoop search ${psQuote(query)}',
      timeout: const Duration(seconds: 45),
    );
    return parseScoopSearchResults(result, manager: definition);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      command: 'scoop install ${psQuote(package.packageName)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'scoop update ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: 'scoop uninstall ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPackageCommand(
      managerId: definition.id,
      label: '批量更新 scoop 应用',
      command: 'scoop update *',
      timeout: const Duration(minutes: 8),
    );
  }
}
