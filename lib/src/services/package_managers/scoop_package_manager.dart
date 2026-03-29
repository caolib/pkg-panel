import 'dart:convert';
import 'dart:io';

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
    if (!Platform.isWindows) {
      throw PackageAdapterException(
        definition.displayName,
        'scoop 仅在 Windows 平台可用。',
      );
    }

    final result = await shell.runPowerShell('scoop list');
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
      (line) {
        if (line == null) return false;
        final trimmed = line.trim();
        return trimmed.startsWith('Name') && trimmed.contains('Version');
      },
      orElse: () => null,
    );
    if (headerLine == null) {
      final debugOutput = lines.take(10).map((l) => '"$l"').join('\n');
      throw PackageAdapterException(
        definition.displayName,
        '无法解析 scoop 输出。前 10 行内容：\n$debugOutput\n\n完整输出：\n${result.stdout}',
      );
    }

    final headerIndex = lines.indexOf(headerLine);
    final versionStart = headerLine.indexOf('Version');
    final sourceStart = headerLine.indexOf('Source');
    final updatedStart = headerLine.indexOf('Updated');
    final infoStart = headerLine.indexOf('Info');

    if (versionStart < 0) {
      throw PackageAdapterException(definition.displayName, '无法识别 scoop 的列布局。');
    }

    final packages = <ManagedPackage>[];
    for (final line in lines.skip(headerIndex + 2)) {
      if (line.trim().startsWith('-')) {
        continue;
      }

      final name = sliceColumn(line, 0, versionStart);
      if (name.isEmpty) {
        continue;
      }

      final version = sourceStart > 0
          ? sliceColumn(line, versionStart, sourceStart)
          : sliceColumn(line, versionStart, null);
      final source = sourceStart > 0 && updatedStart > 0
          ? sliceColumn(line, sourceStart, updatedStart)
          : sourceStart > 0
              ? sliceColumn(line, sourceStart, null)
              : '';
      final updated = updatedStart > 0 && infoStart > 0
          ? sliceColumn(line, updatedStart, infoStart)
          : updatedStart > 0
              ? sliceColumn(line, updatedStart, null)
              : '';
      final info = infoStart > 0 ? sliceColumn(line, infoStart, null) : '';
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
    if (!Platform.isWindows) {
      throw PackageAdapterException(
        definition.displayName,
        'scoop 仅在 Windows 平台可用。',
      );
    }

    final result = await shell.runPowerShell(
      'scoop search ${psQuote(query)}',
      timeout: const Duration(seconds: 45),
    );
    return parseScoopSearchResults(result, manager: definition);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    return buildPowerShellCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      command: 'scoop install ${psQuote(package.packageName)}',
      timeout: const Duration(minutes: 10),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    return switch (action) {
      PackageAction.update => buildPowerShellCommand(
        managerId: definition.id,
        label: '更新 ${package.name}',
        command: 'scoop update ${psQuote(package.name)}',
      ),
      PackageAction.remove => buildPowerShellCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: 'scoop uninstall ${psQuote(package.name)}',
      ),
    };
  }

  @override
  PackageCommand buildBatchUpdateCommand() {
    return buildPowerShellCommand(
      managerId: definition.id,
      label: '批量更新 scoop 应用',
      command: 'scoop update *',
      timeout: const Duration(minutes: 8),
    );
  }
}
