import 'package:flutter/material.dart';

import '../services/shell_executor.dart';

enum ManagerLoadState { idle, loading, ready, error }

enum PackageAction { update, remove }

enum HomeFilterGroupKind { all, updates, custom }

class PackageManagerDefinition {
  const PackageManagerDefinition({
    required this.id,
    required this.displayName,
    required this.executable,
    required this.description,
    required this.color,
    required this.icon,
    this.supportsBatchUpdate = false,
  });

  final String id;
  final String displayName;
  final String executable;
  final String description;
  final Color color;
  final IconData icon;
  final bool supportsBatchUpdate;
}

class ManagedPackage {
  const ManagedPackage({
    required this.name,
    required this.managerId,
    required this.managerName,
    required this.version,
    this.latestVersion,
    this.latestVersionCheckedAt,
    this.identifier,
    this.source,
    this.notes,
    this.executables = const <String>[],
    this.metadata = const <String, String>{},
  });

  final String name;
  final String managerId;
  final String managerName;
  final String version;
  final String? latestVersion;
  final DateTime? latestVersionCheckedAt;
  final String? identifier;
  final String? source;
  final String? notes;
  final List<String> executables;
  final Map<String, String> metadata;

  String get key => '$managerId::$name::${identifier ?? ''}';

  bool get hasUpdate {
    final nextVersion = latestVersion?.trim();
    if (nextVersion == null || nextVersion.isEmpty) {
      return false;
    }
    return _compareVersions(nextVersion, version.trim()) > 0;
  }

  ManagedPackage copyWith({
    String? name,
    String? managerId,
    String? managerName,
    String? version,
    String? latestVersion,
    bool clearLatestVersion = false,
    DateTime? latestVersionCheckedAt,
    bool clearLatestVersionCheckedAt = false,
    String? identifier,
    String? source,
    String? notes,
    bool clearNotes = false,
    List<String>? executables,
    Map<String, String>? metadata,
  }) {
    return ManagedPackage(
      name: name ?? this.name,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      version: version ?? this.version,
      latestVersion: clearLatestVersion
          ? null
          : latestVersion ?? this.latestVersion,
      latestVersionCheckedAt: clearLatestVersionCheckedAt
          ? null
          : latestVersionCheckedAt ?? this.latestVersionCheckedAt,
      identifier: identifier ?? this.identifier,
      source: source ?? this.source,
      notes: clearNotes ? null : notes ?? this.notes,
      executables: executables ?? this.executables,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ManagerSnapshot {
  const ManagerSnapshot({
    required this.manager,
    this.packages = const <ManagedPackage>[],
    this.loadState = ManagerLoadState.idle,
    this.errorMessage,
    this.lastRefreshedAt,
  });

  final PackageManagerDefinition manager;
  final List<ManagedPackage> packages;
  final ManagerLoadState loadState;
  final String? errorMessage;
  final DateTime? lastRefreshedAt;

  bool get isReady => loadState == ManagerLoadState.ready;

  ManagerSnapshot copyWith({
    List<ManagedPackage>? packages,
    ManagerLoadState? loadState,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastRefreshedAt,
  }) {
    return ManagerSnapshot(
      manager: manager,
      packages: packages ?? this.packages,
      loadState: loadState ?? this.loadState,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }
}

class PackageCommand {
  const PackageCommand({
    required this.managerId,
    required this.busyKey,
    required this.label,
    required this.request,
    this.timeout = const Duration(minutes: 5),
  });

  final String managerId;
  final String busyKey;
  final String label;
  final ShellRequest request;
  final Duration timeout;

  String get command => request.displayCommand;

  PackageCommand copyWith({String? busyKey}) {
    return PackageCommand(
      managerId: managerId,
      busyKey: busyKey ?? this.busyKey,
      label: label,
      request: request,
      timeout: timeout,
    );
  }
}

class RunningCommandInfo {
  const RunningCommandInfo({
    required this.busyKey,
    required this.command,
    this.canCancel = false,
    this.isCancelling = false,
    this.statusLabel,
  });

  final String busyKey;
  final String command;
  final bool canCancel;
  final bool isCancelling;
  final String? statusLabel;

  RunningCommandInfo copyWith({
    String? busyKey,
    String? command,
    bool? canCancel,
    bool? isCancelling,
    String? statusLabel,
  }) {
    return RunningCommandInfo(
      busyKey: busyKey ?? this.busyKey,
      command: command ?? this.command,
      canCancel: canCancel ?? this.canCancel,
      isCancelling: isCancelling ?? this.isCancelling,
      statusLabel: statusLabel ?? this.statusLabel,
    );
  }
}

class PackageVersionQueryResult {
  const PackageVersionQueryResult({
    this.versions = const <String>[],
    this.note,
  });

  final List<String> versions;
  final String? note;
}

class SearchPackage {
  const SearchPackage({
    required this.name,
    required this.managerId,
    required this.managerName,
    this.version,
    this.description,
    this.identifier,
    this.source,
    this.installOptions = const <SearchPackageInstallOption>[],
  });

  final String name;
  final String managerId;
  final String managerName;
  final String? version;
  final String? description;
  final String? identifier;
  final String? source;
  final List<SearchPackageInstallOption> installOptions;

  String get key => '$managerId::$name::${identifier ?? ''}';

  bool get isInstalled => installOptions.any((option) => option.isInstalled);

  SearchPackage copyWith({
    String? name,
    String? managerId,
    String? managerName,
    String? version,
    String? description,
    String? identifier,
    String? source,
    List<SearchPackageInstallOption>? installOptions,
  }) {
    return SearchPackage(
      name: name ?? this.name,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      version: version ?? this.version,
      description: description ?? this.description,
      identifier: identifier ?? this.identifier,
      source: source ?? this.source,
      installOptions: installOptions ?? this.installOptions,
    );
  }
}

class SearchPackageInstallOption {
  const SearchPackageInstallOption({
    required this.managerId,
    required this.managerName,
    required this.packageName,
    this.identifier,
    this.version,
    this.source,
    this.isInstalled = false,
  });

  final String managerId;
  final String managerName;
  final String packageName;
  final String? identifier;
  final String? version;
  final String? source;
  final bool isInstalled;

  SearchPackageInstallOption copyWith({bool? isInstalled}) {
    return SearchPackageInstallOption(
      managerId: managerId,
      managerName: managerName,
      packageName: packageName,
      identifier: identifier,
      version: version,
      source: source,
      isInstalled: isInstalled ?? this.isInstalled,
    );
  }
}

class PackageManagerVisibilityState {
  const PackageManagerVisibilityState({
    required this.manager,
    required this.isVisible,
    required this.isAvailable,
  });

  final PackageManagerDefinition manager;
  final bool isVisible;
  final bool isAvailable;
}

class HomeFilterGroup {
  const HomeFilterGroup({
    required this.id,
    required this.kind,
    required this.displayName,
    this.isVisible = true,
    this.iconPath,
    this.managerIds = const <String>[],
    this.packageKeys = const <String>[],
  });

  final String id;
  final HomeFilterGroupKind kind;
  final String displayName;
  final bool isVisible;
  final String? iconPath;
  final List<String> managerIds;
  final List<String> packageKeys;

  bool get isBuiltIn => kind != HomeFilterGroupKind.custom;

  HomeFilterGroup copyWith({
    String? id,
    HomeFilterGroupKind? kind,
    String? displayName,
    bool? isVisible,
    String? iconPath,
    bool clearIconPath = false,
    List<String>? managerIds,
    List<String>? packageKeys,
  }) {
    return HomeFilterGroup(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      displayName: displayName ?? this.displayName,
      isVisible: isVisible ?? this.isVisible,
      iconPath: clearIconPath ? null : iconPath ?? this.iconPath,
      managerIds: managerIds ?? this.managerIds,
      packageKeys: packageKeys ?? this.packageKeys,
    );
  }
}

class ActivityEntry {
  const ActivityEntry({
    required this.timestamp,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final DateTime timestamp;
  final String title;
  final String message;
  final bool isError;
}

int _compareVersions(String a, String b) {
  final numPattern = RegExp(r'(\d+)');
  final aParts =
      numPattern.allMatches(a).map((m) => int.parse(m.group(1)!)).toList();
  final bParts =
      numPattern.allMatches(b).map((m) => int.parse(m.group(1)!)).toList();
  final maxLen = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < maxLen; i++) {
    final aVal = i < aParts.length ? aParts[i] : 0;
    final bVal = i < bParts.length ? bParts[i] : 0;
    if (aVal != bVal) return aVal.compareTo(bVal);
  }
  return 0;
}
