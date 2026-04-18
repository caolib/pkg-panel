import 'dart:convert';
import 'dart:io';

import '../models/package_models.dart';

class PackageSnapshotStore {
  const PackageSnapshotStore();

  Future<List<ManagerSnapshot>> load(
    List<PackageManagerDefinition> managers,
  ) async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return const <ManagerSnapshot>[];
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <ManagerSnapshot>[];
      }

      final items = decoded['snapshots'];
      if (items is! List) {
        return const <ManagerSnapshot>[];
      }

      final definitions = <String, PackageManagerDefinition>{
        for (final manager in managers) manager.id: manager,
      };
      final snapshots = <ManagerSnapshot>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final managerId = '${item['managerId'] ?? ''}'.trim();
        final definition = definitions[managerId];
        if (definition == null) {
          continue;
        }
        final snapshot = _snapshotFromJson(item, definition);
        if (snapshot != null) {
          snapshots.add(snapshot);
        }
      }
      return snapshots;
    } catch (_) {
      return const <ManagerSnapshot>[];
    }
  }

  Future<void> save(List<ManagerSnapshot> snapshots) async {
    try {
      final file = await _resolveFile();
      final payload = <String, dynamic>{
        'snapshots': snapshots.map(_snapshotToJson).toList(growable: false),
      };
      await file.parent.create(recursive: true);
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(payload));
    } catch (_) {
      // Best-effort snapshot persistence.
    }
  }

  Map<String, dynamic> _snapshotToJson(ManagerSnapshot snapshot) {
    return <String, dynamic>{
      'managerId': snapshot.manager.id,
      'lastRefreshedAt': snapshot.lastRefreshedAt?.toIso8601String(),
      'packages': snapshot.packages.map(_packageToJson).toList(growable: false),
    };
  }

  ManagerSnapshot? _snapshotFromJson(
    Map<String, dynamic> json,
    PackageManagerDefinition manager,
  ) {
    final packagesRaw = json['packages'];
    if (packagesRaw is! List) {
      return null;
    }

    final packages = <ManagedPackage>[];
    for (final item in packagesRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final package = _packageFromJson(item, manager);
      if (package != null) {
        packages.add(package);
      }
    }

    final lastRefreshedAtRaw = '${json['lastRefreshedAt'] ?? ''}'.trim();
    return ManagerSnapshot(
      manager: manager,
      packages: packages,
      loadState: packages.isEmpty
          ? ManagerLoadState.idle
          : ManagerLoadState.ready,
      lastRefreshedAt: lastRefreshedAtRaw.isEmpty
          ? null
          : DateTime.tryParse(lastRefreshedAtRaw),
    );
  }

  Map<String, dynamic> _packageToJson(ManagedPackage package) {
    return <String, dynamic>{
      'name': package.name,
      'managerId': package.managerId,
      'managerName': package.managerName,
      'version': package.version,
      'identifier': package.identifier,
      'source': package.source,
      'notes': package.notes,
      'executables': package.executables,
      'metadata': package.metadata,
    };
  }

  ManagedPackage? _packageFromJson(
    Map<String, dynamic> json,
    PackageManagerDefinition manager,
  ) {
    final name = '${json['name'] ?? ''}'.trim();
    final version = '${json['version'] ?? ''}'.trim();
    if (name.isEmpty || version.isEmpty) {
      return null;
    }

    final executablesRaw = json['executables'];
    final metadataRaw = json['metadata'];
    return ManagedPackage(
      name: name,
      managerId: manager.id,
      managerName: manager.displayName,
      version: version,
      identifier: _nullableString(json['identifier']),
      source: _nullableString(json['source']),
      notes: _nullableString(json['notes']),
      executables: executablesRaw is List
          ? executablesRaw
                .map((item) => '$item'.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      metadata: metadataRaw is Map
          ? <String, String>{
              for (final entry in metadataRaw.entries)
                '${entry.key}'.trim(): '${entry.value}'.trim(),
            }
          : const <String, String>{},
    );
  }

  String? _nullableString(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }

  Future<File> _resolveFile() async {
    final basePath =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final directory = Directory('$basePath${Platform.pathSeparator}pkg_panel');
    return File(
      '${directory.path}${Platform.pathSeparator}package_snapshots.json',
    );
  }
}
