import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/package_models.dart';
import '../shell_executor.dart';
import 'package_manager_adapter.dart';
import 'package_manager_helpers.dart';

class WingetAdapter extends PackageManagerAdapter
    with
        InstalledPackageCapability,
        PackageSearchCapability,
        PackageInstallCapability,
        PackageActionCapability,
        PackageDetailsCapability {
  const WingetAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'winget',
          displayName: 'winget',
          executable: 'winget',
          description: 'Installed Windows applications',
          color: Color(0xFF2563EB),
          icon: Icons.window_outlined,
        ),
      );

  @override
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell) async {
    final result = await shell.run('winget list --disable-interactivity');
    if (!result.isSuccess) {
      throw PackageAdapterException(
        definition.displayName,
        result.combinedOutput,
      );
    }

    final packages = <ManagedPackage>[];
    final lines = LineSplitter.split(result.stdout)
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();

    var contentStarted = false;
    for (final line in lines) {
      if (!contentStarted) {
        if (RegExp(r'^-+$').hasMatch(line.trim())) {
          contentStarted = true;
        }
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == r'\' || trimmed == '-') {
        continue;
      }

      final columns = trimmed.split(RegExp(r'\s{2,}'));
      if (columns.length < 3 || looksLikeWingetHeaderRow(columns)) {
        continue;
      }

      String? latestVersion;
      String? source;
      if (columns.length >= 5) {
        latestVersion = columns[3];
        source = columns.sublist(4).join('  ');
      } else if (columns.length == 4) {
        source = columns[3];
      }

      packages.add(
        ManagedPackage(
          name: columns[0],
          managerId: definition.id,
          managerName: definition.displayName,
          version: columns[2],
          latestVersion: normalizeVersion(latestVersion),
          identifier: columns[1],
          source: source,
          notes: latestVersion == null || latestVersion.isEmpty
              ? null
              : '有更新: $latestVersion',
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
      'winget search ${psQuote(query)} --disable-interactivity',
      timeout: const Duration(seconds: 45),
    );
    return parseWingetSearchResults(result, manager: definition);
  }

  @override
  PackageCommand buildInstallCommand(SearchPackageInstallOption package) {
    final target = package.identifier ?? package.packageName;
    return buildPackageCommand(
      managerId: definition.id,
      label: '安装 ${package.packageName}',
      command: [
        'winget install',
        '--id ${psQuote(target)}',
        '--exact',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity',
      ].join(' '),
      timeout: const Duration(minutes: 15),
    );
  }

  @override
  PackageCommand buildCommand(PackageAction action, ManagedPackage package) {
    final target = package.identifier ?? package.name;
    return switch (action) {
      PackageAction.update => buildPackageCommand(
        managerId: definition.id,
        label: '升级 ${package.name}',
        command: [
          'winget upgrade',
          '--id ${psQuote(target)}',
          '--exact',
          '--accept-package-agreements',
          '--accept-source-agreements',
          '--disable-interactivity',
        ].join(' '),
        timeout: const Duration(minutes: 10),
      ),
      PackageAction.remove => buildPackageCommand(
        managerId: definition.id,
        label: '卸载 ${package.name}',
        command: [
          'winget uninstall',
          '--id ${psQuote(target)}',
          '--exact',
          '--accept-source-agreements',
          '--disable-interactivity',
        ].join(' '),
        timeout: const Duration(minutes: 10),
      ),
    };
  }

  @override
  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  ) async {
    final target = package.identifier ?? package.name;
    final result = await shell.run(
      [
        'winget show',
        '--id ${psQuote(target)}',
        '--exact',
        '--accept-source-agreements',
        '--disable-interactivity',
      ].join(' '),
      timeout: const Duration(seconds: 45),
    );
    return parseDetailOutput(result, managerName: definition.displayName);
  }
}
