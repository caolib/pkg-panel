import 'package:flutter/foundation.dart';

import '../models/package_models.dart';
import 'package_adapters.dart';
import 'package_latest_info_store.dart';
import 'shell_executor.dart';

class PackagePanelController extends ChangeNotifier {
  PackagePanelController({
    required ShellExecutor shell,
    required List<PackageManagerAdapter> adapters,
    List<ManagerSnapshot>? initialSnapshots,
    PackageLatestInfoStore? latestInfoStore,
    Map<String, PersistedPackageLatestInfo>? initialLatestInfo,
  }) : _shell = shell,
       _latestInfoStore = latestInfoStore ?? const PackageLatestInfoStore(),
       _latestInfo = Map<String, PersistedPackageLatestInfo>.from(
         initialLatestInfo ?? const <String, PersistedPackageLatestInfo>{},
       ),
       _adapters = List<PackageManagerAdapter>.from(adapters),
       _snapshots = List<ManagerSnapshot>.from(
         initialSnapshots ??
             adapters
                 .map((adapter) => ManagerSnapshot(manager: adapter.definition))
                 .toList(growable: false),
       ),
       _hasLoadedOnce = initialSnapshots != null;

  final ShellExecutor _shell;
  final PackageLatestInfoStore _latestInfoStore;
  final Map<String, PersistedPackageLatestInfo> _latestInfo;
  final List<PackageManagerAdapter> _adapters;
  final List<ManagerSnapshot> _snapshots;
  final List<ActivityEntry> _activity = <ActivityEntry>[];
  final Set<String> _runningCommands = <String>{};
  final Set<String> _selectedPackageKeys = <String>{};

  String _searchQuery = '';
  String? _selectedManagerId;
  ManagedPackage? _selectedPackage;
  String? _selectionAnchorKey;
  bool _isRefreshingAll = false;
  bool _hasLoadedOnce;

  List<ManagerSnapshot> get snapshots =>
      List<ManagerSnapshot>.unmodifiable(_snapshots);

  List<ActivityEntry> get activity =>
      List<ActivityEntry>.unmodifiable(_activity);

  String get searchQuery => _searchQuery;

  String? get selectedManagerId => _selectedManagerId;

  ManagedPackage? get selectedPackage => _selectedPackage;

  int get selectedPackageCount => _selectedPackageKeys.length;

  bool get isRefreshingAll => _isRefreshingAll;

  int get totalPackages =>
      _snapshots.fold<int>(0, (sum, item) => sum + item.packages.length);

  int get readyManagers => _snapshots
      .where((snapshot) => snapshot.loadState == ManagerLoadState.ready)
      .length;

  int get errorManagers => _snapshots
      .where((snapshot) => snapshot.loadState == ManagerLoadState.error)
      .length;

  int get updateCandidates =>
      visiblePackages.where((package) => package.hasUpdate).length;

  List<ManagedPackage> get visiblePackages {
    final selectedSnapshots = _selectedManagerId == null
        ? _snapshots
        : _snapshots.where(
            (snapshot) => snapshot.manager.id == _selectedManagerId,
          );

    final query = _searchQuery.trim().toLowerCase();
    final packages = selectedSnapshots
        .expand((snapshot) => snapshot.packages)
        .where((package) {
          if (query.isEmpty) {
            return true;
          }

          return [
            package.name,
            package.managerName,
            package.source ?? '',
            package.notes ?? '',
          ].join(' ').toLowerCase().contains(query);
        })
        .toList();

    packages.sort((a, b) {
      final managerCompare = a.managerName.toLowerCase().compareTo(
        b.managerName.toLowerCase(),
      );
      if (managerCompare != 0) {
        return managerCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return packages;
  }

  ManagerSnapshot? get selectedManagerSnapshot {
    if (_selectedManagerId == null) {
      return null;
    }

    for (final snapshot in _snapshots) {
      if (snapshot.manager.id == _selectedManagerId) {
        return snapshot;
      }
    }
    return null;
  }

  PackageManagerAdapter? get selectedAdapter {
    final managerId = _selectedManagerId;
    if (managerId == null) {
      return null;
    }
    return _adapterFor(managerId);
  }

  bool get canBatchCheckLatestForSelectedManager {
    final snapshot = selectedManagerSnapshot;
    final adapter = selectedAdapter;
    if (snapshot == null || adapter == null) {
      return false;
    }

    return snapshot.packages.any(adapter.supportsLatestVersionLookup);
  }

  bool get isBatchCheckingLatestForSelectedManager {
    final managerId = _selectedManagerId;
    if (managerId == null) {
      return false;
    }
    return _runningCommands.contains(_batchLatestBusyKey(managerId));
  }

  bool isBusy(String busyKey) => _runningCommands.contains(busyKey);

  bool canCheckLatestVersion(ManagedPackage package) {
    final adapter = _adapterFor(package.managerId);
    return adapter?.supportsLatestVersionLookup(package) ?? false;
  }

  bool isCheckingLatestVersion(ManagedPackage package) {
    return _runningCommands.contains(_latestVersionBusyKey(package));
  }

  bool isPackageSelected(ManagedPackage package) {
    return _selectedPackageKeys.contains(package.key);
  }

  Future<void> ensureLoaded() async {
    if (_hasLoadedOnce) {
      _realignSelection();
      return;
    }

    _hasLoadedOnce = true;
    await loadAll();
  }

  Future<void> loadAll() async {
    _isRefreshingAll = true;
    for (var i = 0; i < _snapshots.length; i++) {
      _snapshots[i] = _snapshots[i].copyWith(
        loadState: ManagerLoadState.loading,
        clearError: true,
      );
    }
    notifyListeners();

    await Future.wait(_adapters.map(_loadAdapter));

    _isRefreshingAll = false;
    _realignSelection();
    notifyListeners();
  }

  Future<void> refreshManager(String managerId) async {
    final adapter = _adapterFor(managerId);
    if (adapter == null) {
      return;
    }
    await _loadAdapter(adapter);
    _realignSelection();
    notifyListeners();
  }

  Future<void> _loadAdapter(PackageManagerAdapter adapter) async {
    _setSnapshot(
      adapter.definition.id,
      _snapshotFor(
        adapter.definition.id,
      ).copyWith(loadState: ManagerLoadState.loading, clearError: true),
    );
    notifyListeners();

    try {
      final packages = _mergeLatestInfoIntoPackages(
        await adapter.listPackages(_shell),
      );
      _setSnapshot(
        adapter.definition.id,
        _snapshotFor(adapter.definition.id).copyWith(
          packages: packages,
          loadState: ManagerLoadState.ready,
          clearError: true,
          lastRefreshedAt: DateTime.now(),
        ),
      );
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '${adapter.definition.displayName} 已同步',
          message: '已加载 ${packages.length} 个已安装包。',
        ),
      );
    } catch (error) {
      _setSnapshot(
        adapter.definition.id,
        _snapshotFor(adapter.definition.id).copyWith(
          packages: const <ManagedPackage>[],
          loadState: ManagerLoadState.error,
          errorMessage: '$error',
          lastRefreshedAt: DateTime.now(),
        ),
      );
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '${adapter.definition.displayName} 加载失败',
          message: '$error',
          isError: true,
        ),
      );
    }
  }

  void selectManager(String? managerId) {
    _selectedManagerId = managerId;
    _realignSelection();
    notifyListeners();
  }

  void selectPackage(
    ManagedPackage package, {
    bool additive = false,
    bool range = false,
  }) {
    final packages = visiblePackages;
    if (packages.isEmpty) {
      return;
    }

    final targetKey = package.key;
    if (range) {
      final anchorKey = _selectionAnchorKey ?? _selectedPackage?.key ?? targetKey;
      final anchorIndex = _indexOfPackage(packages, anchorKey);
      final targetIndex = _indexOfPackage(packages, targetKey);
      if (anchorIndex >= 0 && targetIndex >= 0) {
        final start = anchorIndex < targetIndex ? anchorIndex : targetIndex;
        final end = anchorIndex > targetIndex ? anchorIndex : targetIndex;
        final rangeKeys = packages
            .sublist(start, end + 1)
            .map((item) => item.key)
            .toSet();
        if (additive) {
          _selectedPackageKeys.addAll(rangeKeys);
        } else {
          _selectedPackageKeys
            ..clear()
            ..addAll(rangeKeys);
        }
        _selectedPackage = package;
        _selectionAnchorKey = anchorKey;
        notifyListeners();
        return;
      }
    }

    if (additive) {
      if (_selectedPackageKeys.contains(targetKey)) {
        _selectedPackageKeys.remove(targetKey);
        if (_selectedPackage?.key == targetKey) {
          _selectedPackage = _firstSelectedVisiblePackage(packages);
        }
        if (_selectedPackageKeys.isEmpty) {
          _selectionAnchorKey = null;
        }
      } else {
        _selectedPackageKeys.add(targetKey);
        _selectedPackage = package;
        _selectionAnchorKey = targetKey;
      }
      notifyListeners();
      return;
    }

    _selectedPackage = package;
    _selectedPackageKeys
      ..clear()
      ..add(targetKey);
    _selectionAnchorKey = targetKey;
    notifyListeners();
  }

  void selectPackageForContextMenu(ManagedPackage package) {
    final targetKey = package.key;
    if (_selectedPackageKeys.contains(targetKey)) {
      _selectedPackage = package;
      _selectionAnchorKey = targetKey;
      notifyListeners();
      return;
    }

    _selectedPackage = package;
    _selectedPackageKeys
      ..clear()
      ..add(targetKey);
    _selectionAnchorKey = targetKey;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    _realignSelection();
    notifyListeners();
  }

  PackageCommand? commandFor(PackageAction action, ManagedPackage package) {
    final adapter = _adapterFor(package.managerId);
    return adapter?.buildCommand(action, package);
  }

  PackageCommand? batchUpdateCommandForSelectedManager() {
    final adapter = selectedAdapter;
    if (adapter == null) {
      return null;
    }
    return adapter.buildBatchUpdateCommand();
  }

  Future<void> batchCheckLatestVersionsForSelectedManager() async {
    final managerId = _selectedManagerId;
    final snapshot = selectedManagerSnapshot;
    final adapter = selectedAdapter;
    if (managerId == null || snapshot == null || adapter == null) {
      return;
    }

    final busyKey = _batchLatestBusyKey(managerId);
    if (_runningCommands.contains(busyKey)) {
      return;
    }

    final packages = snapshot.packages
        .where(adapter.supportsLatestVersionLookup)
        .toList(growable: false);
    if (packages.isEmpty) {
      return;
    }

    _runningCommands.add(busyKey);
    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: '正在批量检查 ${snapshot.manager.displayName}',
        message: '准备检查 ${packages.length} 个包的最新版本。',
      ),
    );
    notifyListeners();

    try {
      for (final package in packages) {
        await checkLatestVersion(package);
      }
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '${snapshot.manager.displayName} 批量检查更新完成',
          message: '已完成 ${packages.length} 个包的最新版本检查。',
        ),
      );
    } finally {
      _runningCommands.remove(busyKey);
      notifyListeners();
    }
  }

  Future<ShellResult> runCommand(PackageCommand command) async {
    _runningCommands.add(command.busyKey);
    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: command.label,
        message: command.command,
      ),
    );
    notifyListeners();

    final result = await _shell.run(command.command, timeout: command.timeout);
    _runningCommands.remove(command.busyKey);

    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: result.isSuccess
            ? '${command.label} 已完成'
            : '${command.label} 失败',
        message: result.combinedOutput.isEmpty
            ? '命令执行完成，但没有控制台输出。'
            : result.combinedOutput,
        isError: !result.isSuccess,
      ),
    );

    if (result.isSuccess) {
      await refreshManager(command.managerId);
    } else {
      notifyListeners();
    }

    return result;
  }

  Future<void> checkLatestVersion(ManagedPackage package) async {
    final adapter = _adapterFor(package.managerId);
    if (adapter == null || !adapter.supportsLatestVersionLookup(package)) {
      return;
    }

    final busyKey = _latestVersionBusyKey(package);
    if (_runningCommands.contains(busyKey)) {
      return;
    }

    _runningCommands.add(busyKey);
    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: '正在检查 ${package.name}',
        message: '正在检查 ${package.managerName} 的最新版本。',
      ),
    );
    notifyListeners();

    try {
      final checkedAt = DateTime.now();
      final latestVersion = await adapter.lookupLatestVersion(_shell, package);
      final updatedPackage = package.copyWith(
        latestVersion: latestVersion,
        latestVersionCheckedAt: checkedAt,
        notes: package.notes,
      );
      _replacePackage(updatedPackage);
      _latestInfo[updatedPackage.key] = PersistedPackageLatestInfo(
        installedVersion: updatedPackage.version.trim(),
        latestVersion: latestVersion.trim(),
        checkedAt: checkedAt,
      );
      await _latestInfoStore.save(_latestInfo);
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '已检查 ${package.name}',
          message: latestVersion == package.version
              ? '当前已是最新版本：$latestVersion。'
              : '最新版本：$latestVersion。',
        ),
      );
    } catch (error) {
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '检查 ${package.name} 失败',
          message: '$error',
          isError: true,
        ),
      );
    } finally {
      _runningCommands.remove(busyKey);
      notifyListeners();
    }
  }

  void _setSnapshot(String managerId, ManagerSnapshot next) {
    for (var i = 0; i < _snapshots.length; i++) {
      if (_snapshots[i].manager.id == managerId) {
        _snapshots[i] = next;
        return;
      }
    }
  }

  void _replacePackage(ManagedPackage nextPackage) {
    for (var i = 0; i < _snapshots.length; i++) {
      final snapshot = _snapshots[i];
      if (snapshot.manager.id != nextPackage.managerId) {
        continue;
      }

      final nextPackages = snapshot.packages
          .map((package) {
            return package.key == nextPackage.key ? nextPackage : package;
          })
          .toList(growable: false);

      _snapshots[i] = snapshot.copyWith(packages: nextPackages);
      if (_selectedPackage?.key == nextPackage.key) {
        _selectedPackage = nextPackage;
      }
      return;
    }
  }

  ManagerSnapshot _snapshotFor(String managerId) {
    for (final snapshot in _snapshots) {
      if (snapshot.manager.id == managerId) {
        return snapshot;
      }
    }
    throw StateError('Unknown manager: $managerId');
  }

  PackageManagerAdapter? _adapterFor(String managerId) {
    for (final adapter in _adapters) {
      if (adapter.definition.id == managerId) {
        return adapter;
      }
    }
    return null;
  }

  void _realignSelection() {
    final packages = visiblePackages;
    if (packages.isEmpty) {
      _selectedPackage = null;
      _selectedPackageKeys.clear();
      _selectionAnchorKey = null;
      return;
    }

    final visibleKeys = packages.map((package) => package.key).toSet();
    _selectedPackageKeys.removeWhere((key) => !visibleKeys.contains(key));

    final selectedKey = _selectedPackage?.key;
    if (selectedKey != null && visibleKeys.contains(selectedKey)) {
      _selectedPackage = packages[_indexOfPackage(packages, selectedKey)];
    } else {
      _selectedPackage = null;
    }

    if (_selectedPackageKeys.isEmpty) {
      final firstPackage = packages.first;
      _selectedPackage = firstPackage;
      _selectedPackageKeys
        ..clear()
        ..add(firstPackage.key);
      _selectionAnchorKey = firstPackage.key;
      return;
    }

    _selectedPackage ??= _firstSelectedVisiblePackage(packages);
    if (_selectionAnchorKey == null ||
        !_selectedPackageKeys.contains(_selectionAnchorKey) ||
        !visibleKeys.contains(_selectionAnchorKey)) {
      _selectionAnchorKey = _selectedPackage?.key;
    }
  }

  void _pushActivity(ActivityEntry entry) {
    _activity.insert(0, entry);
    if (_activity.length > 24) {
      _activity.removeRange(24, _activity.length);
    }
  }

  String _latestVersionBusyKey(ManagedPackage package) {
    return 'latest-version::${package.key}';
  }

  String _batchLatestBusyKey(String managerId) {
    return 'batch-latest::$managerId';
  }

  List<ManagedPackage> _mergeLatestInfoIntoPackages(List<ManagedPackage> packages) {
    return packages.map((package) {
      final cached = _latestInfo[package.key];
      if (cached == null) {
        return package;
      }

      if (cached.installedVersion.trim() != package.version.trim()) {
        return package;
      }

      return package.copyWith(
        latestVersion: cached.latestVersion,
        latestVersionCheckedAt: cached.checkedAt,
      );
    }).toList(growable: false);
  }

  int _indexOfPackage(List<ManagedPackage> packages, String key) {
    for (var i = 0; i < packages.length; i++) {
      if (packages[i].key == key) {
        return i;
      }
    }
    return -1;
  }

  ManagedPackage? _firstSelectedVisiblePackage(List<ManagedPackage> packages) {
    for (final package in packages) {
      if (_selectedPackageKeys.contains(package.key)) {
        return package;
      }
    }
    return null;
  }
}
