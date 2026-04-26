import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_theme_palette.dart';
import '../models/package_models.dart';
import 'app_update_service.dart';
import 'package_adapters.dart';
import 'package_manager_settings_store.dart';
import 'package_snapshot_store.dart';
import 'shell_executor.dart';
import 'winget_package_icon_resolver.dart';

const String allFilterId = '__all__';
const String updateFilterId = '__updates__';
const String _nodeRegistrySearchGroupId = 'node_registry';
const List<String> _nodeRegistrySearchPriority = <String>['npm', 'pnpm'];
const List<String> _nodeRegistryInstallPriority = <String>[
  'npm',
  'pnpm',
  'yarn',
  'bun',
];

class PackagePanelController extends ChangeNotifier {
  PackagePanelController({
    required ShellExecutor shell,
    required List<PackageManagerAdapter> adapters,
    List<ManagerSnapshot>? initialSnapshots,
    PackageManagerSettingsStore? settingsStore,
    PackageSnapshotStore? snapshotStore,
    Set<String>? initialVisibleManagerIds,
    List<HomeFilterGroup>? initialHomeFilterGroups,
    List<String>? initialManagerOrderIds,
    Map<String, bool>? initialManagerAvailability,
    Set<String>? initialManuallyHiddenManagerIds,
    Map<String, String>? initialCustomManagerIconPaths,
    Map<String, String>? initialCustomManagerDisplayNames,
    Locale? initialLocale,
    String? initialThemePaletteId,
    ThemeMode? initialThemeMode,
    int? initialCustomThemeSeedColorValue,
    bool? initialAutoCheckAppUpdates,
    bool? initialRememberWindowPlacement,
    bool? initialUseGithubMirrorForDownloads,
    String? initialGithubMirrorBaseUrl,
    String? initialCustomFontFamily,
    List<String>? initialCustomFallbackFontFamilies,
    AppUpdateService? appUpdateService,
    WingetPackageIconResolver? wingetIconResolver,
  }) : _shell = shell,
       _appUpdateService = appUpdateService ?? const AppUpdateService(),
       _settingsStore = settingsStore ?? const PackageManagerSettingsStore(),
       _snapshotStore = snapshotStore ?? const PackageSnapshotStore(),
       _wingetIconResolver =
           wingetIconResolver ?? const WingetPackageIconResolver(),
       _adapters = List<PackageManagerAdapter>.from(adapters),
       _homeFilterGroups = _normalizeHomeFilterGroups(initialHomeFilterGroups),
       _snapshots = _normalizeSnapshots(adapters, initialSnapshots),
       _visibleManagerIds = Set<String>.from(
         initialVisibleManagerIds ??
             adapters.map((adapter) => adapter.definition.id).toSet(),
       ),
       _manuallyHiddenManagerIds = Set<String>.from(
         initialManuallyHiddenManagerIds ?? const <String>{},
       ),
       _managerAvailability = Map<String, bool>.from(
         initialManagerAvailability ?? const <String, bool>{},
       ),
       _customManagerIconPaths = Map<String, String>.from(
         initialCustomManagerIconPaths ?? const <String, String>{},
       ),
       _customManagerDisplayNames = Map<String, String>.from(
         initialCustomManagerDisplayNames ?? const <String, String>{},
       ),
       _locale = _normalizeLocale(initialLocale),
       _themePaletteId = _normalizeThemePaletteId(initialThemePaletteId),
       _customThemeSeedColor = _normalizeThemeSeedColor(
         initialCustomThemeSeedColorValue,
       ),
       _themeMode = initialThemeMode ?? ThemeMode.system,
       _autoCheckAppUpdates = initialAutoCheckAppUpdates ?? true,
       _rememberWindowPlacement = initialRememberWindowPlacement ?? true,
       _useGithubMirrorForDownloads =
           initialUseGithubMirrorForDownloads ?? true,
       _githubMirrorBaseUrl =
           initialGithubMirrorBaseUrl?.trim().isNotEmpty == true
           ? initialGithubMirrorBaseUrl!.trim()
           : defaultGithubMirrorBaseUrl,
       _customFontFamily = initialCustomFontFamily?.trim(),
       _customFallbackFontFamilies = List<String>.from(
         initialCustomFallbackFontFamilies ?? const <String>[],
       ),
       _hasCachedSnapshots = initialSnapshots != null,
       _hasInitializedManagerVisibility =
           initialVisibleManagerIds != null ||
           initialManuallyHiddenManagerIds != null {
    _applyManagerOrder(initialManagerOrderIds ?? const <String>[]);
  }

  final ShellExecutor _shell;
  final AppUpdateService _appUpdateService;
  final PackageManagerSettingsStore _settingsStore;
  final PackageSnapshotStore _snapshotStore;
  final WingetPackageIconResolver _wingetIconResolver;
  final List<PackageManagerAdapter> _adapters;
  final List<HomeFilterGroup> _homeFilterGroups;
  final List<ManagerSnapshot> _snapshots;
  final List<ActivityEntry> _activity = <ActivityEntry>[];
  final Set<String> _runningCommands = <String>{};
  final Set<String> _queuedCommands = <String>{};
  final Map<String, RunningCommandInfo> _runningCommandInfo =
      <String, RunningCommandInfo>{};
  final Map<String, RunningCommandInfo> _queuedCommandInfo =
      <String, RunningCommandInfo>{};
  final Map<String, String> _activeManagerCommandBusyKeys = <String, String>{};
  final Map<String, List<_QueuedPackageCommand>> _queuedManagerCommands =
      <String, List<_QueuedPackageCommand>>{};
  final Set<String> _selectedPackageKeys = <String>{};
  final Set<String> _visibleManagerIds;
  final Set<String> _manuallyHiddenManagerIds;
  final Map<String, bool> _managerAvailability;
  final Map<String, String> _customManagerIconPaths;
  final Map<String, String> _customManagerDisplayNames;
  final Map<String, String> _packageIconPaths = <String, String>{};
  final List<SearchPackage> _searchResults = <SearchPackage>[];
  int _searchRequestId = 0;

  String _searchQuery = '';
  String _installSearchQuery = '';
  String? _customFontFamily;
  final List<String> _customFallbackFontFamilies;
  String? _selectedManagerId;
  ManagedPackage? _selectedPackage;
  String? _selectionAnchorKey;
  bool _isRefreshingAll = false;
  bool _isRefreshingManagerAvailability = false;
  bool _isSearchingPackages = false;
  bool _hasCachedSnapshots;
  bool _hasTriggeredInitialRefresh = false;
  bool _hasInitializedManagerVisibility;
  bool _isCheckingAppUpdate = false;
  bool _isBatchCheckingLatestForGroup = false;
  Locale _locale;
  String _themePaletteId;
  Color _customThemeSeedColor;
  ThemeMode _themeMode;
  bool _autoCheckAppUpdates;
  bool _rememberWindowPlacement;
  bool _useGithubMirrorForDownloads;
  String _githubMirrorBaseUrl;
  int _visiblePackagesDataStamp = 0;
  int _cachedVisiblePackagesDataStamp = -1;
  String _cachedVisiblePackagesQuery = '';
  String? _cachedVisiblePackagesManagerId;
  List<ManagedPackage>? _cachedVisiblePackages;

  List<ManagerSnapshot> get snapshots =>
      List<ManagerSnapshot>.unmodifiable(_snapshots);

  List<ManagerSnapshot> get visibleSnapshots => _snapshots
      .where(
        (snapshot) =>
            isManagerVisible(snapshot.manager.id) &&
            _supportsInstalledPackagesById(snapshot.manager.id),
      )
      .toList(growable: false);

  List<ManagerSnapshot> get _homeSnapshots => _snapshots
      .where(
        (snapshot) =>
            _shouldLoadManagerForHome(snapshot.manager.id) &&
            _supportsInstalledPackagesById(snapshot.manager.id),
      )
      .toList(growable: false);

  List<ActivityEntry> get activity =>
      List<ActivityEntry>.unmodifiable(_activity);

  List<SearchPackage> get searchResults =>
      List<SearchPackage>.unmodifiable(_searchResults);

  String get searchQuery => _searchQuery;

  String get installSearchQuery => _installSearchQuery;

  String? get selectedManagerId => _selectedManagerId;

  ManagedPackage? get selectedPackage => _selectedPackage;

  int get selectedPackageCount => _selectedPackageKeys.length;

  bool get isRefreshingAll => _isRefreshingAll;

  bool get isRefreshingManagerAvailability => _isRefreshingManagerAvailability;

  bool get isRefreshingCurrentSelection {
    if (_selectedHomeFilterGroup != null || _selectedManagerId == null) {
      return _isRefreshingAll;
    }
    return selectedManagerSnapshot?.loadState == ManagerLoadState.loading;
  }

  bool get isSearchingPackages => _isSearchingPackages;

  Locale get locale => _locale;

  String get themePaletteId => _themePaletteId;

  Color get customThemeSeedColor => _customThemeSeedColor;

  Color get activeThemeSeedColor => _themePaletteId == customAppThemePaletteId
      ? _customThemeSeedColor
      : (appThemePaletteById(_themePaletteId)?.seedColor ??
            defaultCustomAppThemeSeedColor);

  ThemeMode get themeMode => _themeMode;

  bool get autoCheckAppUpdates => _autoCheckAppUpdates;

  bool get rememberWindowPlacement => _rememberWindowPlacement;

  bool get useGithubMirrorForDownloads => _useGithubMirrorForDownloads;

  String get githubMirrorBaseUrl => _githubMirrorBaseUrl;

  bool get isCheckingAppUpdate => _isCheckingAppUpdate;

  String? get customFontFamily =>
      _customFontFamily == null || _customFontFamily!.trim().isEmpty
      ? null
      : _customFontFamily!.trim();

  List<String> get customFallbackFontFamilies =>
      List<String>.unmodifiable(_customFallbackFontFamilies);

  int get totalPackages =>
      visibleSnapshots.fold<int>(0, (sum, item) => sum + item.packages.length);

  int get readyManagers => _snapshots
      .where(
        (snapshot) =>
            isManagerVisible(snapshot.manager.id) &&
            _supportsInstalledPackagesById(snapshot.manager.id),
      )
      .where((snapshot) => snapshot.loadState == ManagerLoadState.ready)
      .length;

  int get errorManagers => _snapshots
      .where(
        (snapshot) =>
            _shouldLoadManagerForHome(snapshot.manager.id) &&
            _supportsInstalledPackagesById(snapshot.manager.id),
      )
      .where((snapshot) => snapshot.loadState == ManagerLoadState.error)
      .length;

  int get updateCandidates =>
      visiblePackages.where((package) => package.hasUpdate).length;

  bool get hasVisibleLocalManagers => _adapters.any((adapter) {
    final managerId = adapter.definition.id;
    if (!_supportsInstalledPackages(adapter)) {
      return false;
    }
    final selectedGroup = _selectedHomeFilterGroup;
    if (selectedGroup != null) {
      return _managerIdsReferencedByHomeFilterGroup(
        selectedGroup,
      ).contains(managerId);
    }
    return _shouldLoadManagerForHome(managerId);
  });

  List<ManagedPackage> get visiblePackages {
    final selectedManagerId = _selectedManagerId;
    final selectedGroup = _selectedHomeFilterGroup;
    final query = _searchQuery.trim().toLowerCase();
    final cached = _cachedVisiblePackages;
    if (cached != null &&
        _cachedVisiblePackagesDataStamp == _visiblePackagesDataStamp &&
        _cachedVisiblePackagesQuery == query &&
        _cachedVisiblePackagesManagerId == selectedManagerId) {
      return cached;
    }

    final selectedSnapshots = _snapshotsForCurrentSelection();
    final packages = selectedSnapshots
        .expand((snapshot) => snapshot.packages)
        .where((package) {
          if (selectedGroup != null &&
              !_homeFilterGroupMatchesPackage(selectedGroup, package)) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }

          return [
            package.name,
            displayNameForPackage(package),
            package.source ?? '',
            package.notes ?? '',
          ].join(' ').toLowerCase().contains(query);
        })
        .toList();

    packages.sort((a, b) {
      final managerCompare = displayNameForPackage(
        a,
      ).toLowerCase().compareTo(displayNameForPackage(b).toLowerCase());
      if (managerCompare != 0) {
        return managerCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final computed = List<ManagedPackage>.unmodifiable(packages);
    _cachedVisiblePackages = computed;
    _cachedVisiblePackagesDataStamp = _visiblePackagesDataStamp;
    _cachedVisiblePackagesQuery = query;
    _cachedVisiblePackagesManagerId = selectedManagerId;
    return computed;
  }

  ManagerSnapshot? get selectedManagerSnapshot {
    if (_selectedManagerId == null || _selectedHomeFilterGroup != null) {
      return null;
    }

    for (final snapshot in _snapshots) {
      if (snapshot.manager.id == _selectedManagerId) {
        if (!isManagerVisible(snapshot.manager.id) ||
            !_supportsInstalledPackagesById(snapshot.manager.id)) {
          return null;
        }
        return snapshot;
      }
    }
    return null;
  }

  PackageManagerAdapter? get selectedAdapter {
    final managerId = _selectedManagerId;
    if (managerId == null || _selectedHomeFilterGroup != null) {
      return null;
    }
    return _adapterFor(managerId);
  }

  HomeFilterGroup? get selectedHomeFilterGroup {
    return _selectedHomeFilterGroup;
  }

  List<HomeFilterGroup> get homeFilterGroups =>
      List<HomeFilterGroup>.unmodifiable(_homeFilterGroups);

  List<HomeFilterGroup> get visibleHomeFilterGroups => _homeFilterGroups
      .where((group) => group.isVisible)
      .toList(growable: false);

  bool get canBatchCheckLatestForSelectedManager {
    final snapshot = selectedManagerSnapshot;
    final capability = _capabilityOf<LatestVersionLookupCapability>(
      selectedAdapter,
    );
    if (snapshot == null || capability == null) {
      return false;
    }

    final packages = snapshot.packages
        .where(capability.supportsLatestVersionLookup)
        .toList(growable: false);
    if (packages.isEmpty) {
      return false;
    }
    return capability.supportsBatchLatestVersionLookup(packages);
  }

  bool get canBatchCheckLatestForCurrentSelection {
    if (_selectedHomeFilterGroup != null || _selectedManagerId == null) {
      return visiblePackages.any(canCheckLatestVersion);
    }
    return canBatchCheckLatestForSelectedManager;
  }

  bool get isBatchCheckingLatestForSelectedManager {
    final managerId = _selectedManagerId;
    if (managerId == null) {
      return false;
    }
    return _runningCommands.contains(_batchLatestBusyKey(managerId));
  }

  bool get isBatchCheckingLatestForCurrentSelection {
    if (_isBatchCheckingLatestForGroup) {
      return true;
    }
    return isBatchCheckingLatestForSelectedManager;
  }

  bool isBusy(String busyKey) =>
      _runningCommands.contains(busyKey) || _queuedCommands.contains(busyKey);

  List<RunningCommandInfo> get runningCommands =>
      List<RunningCommandInfo>.unmodifiable(<RunningCommandInfo>[
        ..._runningCommandInfo.values,
        ..._queuedCommandInfo.values,
      ]);

  Future<bool> cancelRunningCommand(String busyKey) async {
    if (_queuedCommands.contains(busyKey)) {
      return _cancelQueuedCommand(busyKey);
    }

    final command = _runningCommandInfo[busyKey];
    if (command == null || !command.canCancel || command.isCancelling) {
      return false;
    }

    _runningCommandInfo[busyKey] = command.copyWith(isCancelling: true);
    final managerId = _managerIdForBusyKey(busyKey);
    final cancelledQueuedCount = managerId == null
        ? 0
        : _cancelQueuedCommandsForManager(managerId);
    if (cancelledQueuedCount > 0) {
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '已清空后续排队命令',
          message: '已移除 $cancelledQueuedCount 个待执行命令。',
        ),
      );
    }
    notifyListeners();

    final cancelled = await _shell.cancelExecution(busyKey, force: true);
    if (!cancelled) {
      final current = _runningCommandInfo[busyKey];
      if (current != null) {
        _runningCommandInfo[busyKey] = current.copyWith(isCancelling: false);
        notifyListeners();
      }
      return false;
    }

    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: '正在取消命令',
        message: command.command,
      ),
    );
    notifyListeners();
    return true;
  }

  Future<void> cancelAllRunningCommands() async {
    final busyKeys = _runningCommandInfo.values
        .where((command) => command.canCancel && !command.isCancelling)
        .map((command) => command.busyKey)
        .toList(growable: false);
    for (final busyKey in busyKeys) {
      await cancelRunningCommand(busyKey);
    }
  }

  String? _managerIdForBusyKey(String busyKey) {
    for (final entry in _activeManagerCommandBusyKeys.entries) {
      if (entry.value == busyKey) {
        return entry.key;
      }
    }
    return null;
  }

  int _cancelQueuedCommandsForManager(String managerId) {
    final queue = _queuedManagerCommands.remove(managerId);
    if (queue == null || queue.isEmpty) {
      return 0;
    }

    for (final queued in queue) {
      _queuedCommands.remove(queued.command.busyKey);
      _queuedCommandInfo.remove(queued.command.busyKey);
      if (!queued.completer.isCompleted) {
        queued.completer.complete(
          const ShellResult(
            exitCode: 130,
            stdout: '',
            stderr: '命令已取消。',
            wasCancelled: true,
          ),
        );
      }
    }
    return queue.length;
  }

  bool _cancelQueuedCommand(String busyKey) {
    for (final entry in _queuedManagerCommands.entries.toList()) {
      final queue = entry.value;
      final index = queue.indexWhere(
        (queued) => queued.command.busyKey == busyKey,
      );
      if (index < 0) {
        continue;
      }

      final queued = queue.removeAt(index);
      if (queue.isEmpty) {
        _queuedManagerCommands.remove(entry.key);
      }
      _queuedCommands.remove(busyKey);
      _queuedCommandInfo.remove(busyKey);
      if (!queued.completer.isCompleted) {
        queued.completer.complete(
          const ShellResult(
            exitCode: 130,
            stdout: '',
            stderr: '命令已取消。',
            wasCancelled: true,
          ),
        );
      }
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '${queued.command.label} 已取消',
          message: queued.command.command,
        ),
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  bool canCheckLatestVersion(ManagedPackage package) {
    final capability = _capabilityOf<LatestVersionLookupCapability>(
      _adapterFor(package.managerId),
    );
    return capability?.supportsLatestVersionLookup(package) ?? false;
  }

  Future<PackageCommand?>
  batchLatestVersionPrerequisiteCommandForSelectedManager() async {
    final snapshot = selectedManagerSnapshot;
    final capability = _capabilityOf<LatestVersionLookupCapability>(
      selectedAdapter,
    );
    if (snapshot == null || capability == null) {
      return null;
    }

    final packages = snapshot.packages
        .where(capability.supportsLatestVersionLookup)
        .toList(growable: false);
    if (packages.isEmpty ||
        !capability.supportsBatchLatestVersionLookup(packages) ||
        capability is! BatchLatestVersionPrerequisiteCapability) {
      return null;
    }

    return capability.batchLatestVersionPrerequisiteCommand(_shell, packages);
  }

  String? batchLatestVersionPrerequisitePromptForSelectedManager() {
    final snapshot = selectedManagerSnapshot;
    final capability = _capabilityOf<LatestVersionLookupCapability>(
      selectedAdapter,
    );
    if (snapshot == null ||
        capability == null ||
        capability is! BatchLatestVersionPrerequisiteCapability) {
      return null;
    }

    final packages = snapshot.packages
        .where(capability.supportsLatestVersionLookup)
        .toList(growable: false);
    if (packages.isEmpty ||
        !capability.supportsBatchLatestVersionLookup(packages)) {
      return null;
    }
    return capability.batchLatestVersionPrerequisitePrompt(packages);
  }

  bool canViewPackageDetails(ManagedPackage package) {
    final capability = _capabilityOf<PackageDetailsCapability>(
      _adapterFor(package.managerId),
    );
    return capability?.supportsPackageDetails(package) ?? false;
  }

  bool isCheckingLatestVersion(ManagedPackage package) {
    return _runningCommands.contains(_latestVersionBusyKey(package));
  }

  bool isLoadingPackageDetails(ManagedPackage package) {
    return _runningCommands.contains(_packageDetailsBusyKey(package));
  }

  bool isInstallingPackage(SearchPackage package) {
    return package.installOptions.any(isInstallingSearchOption);
  }

  bool isInstallingSearchOption(SearchPackageInstallOption option) {
    final prefix = _installBusyKeyPrefix(option);
    return _runningCommands.any(
          (key) => key == prefix || key.startsWith('$prefix::'),
        ) ||
        _queuedCommands.any(
          (key) => key == prefix || key.startsWith('$prefix::'),
        );
  }

  bool isPackageSelected(ManagedPackage package) {
    return _selectedPackageKeys.contains(package.key);
  }

  bool isManagerVisible(String managerId) =>
      _visibleManagerIds.contains(managerId);

  bool isManagerAvailable(String managerId) =>
      _managerAvailability[managerId] ?? false;

  bool isHomeFilterGroupId(String id) => _homeFilterGroupById(id) != null;

  List<PackageManagerVisibilityState> get managerVisibilityStates => _adapters
      .map(
        (adapter) => PackageManagerVisibilityState(
          manager: adapter.definition,
          isVisible: isManagerVisible(adapter.definition.id),
          isAvailable: isManagerAvailable(adapter.definition.id),
        ),
      )
      .toList(growable: false);

  List<String> get managerOrderIds => List<String>.unmodifiable(
    _adapters.map((adapter) => adapter.definition.id).toList(growable: false),
  );

  String? customManagerIconPath(String managerId) {
    final value = _customManagerIconPaths[managerId]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? packageIconPath(ManagedPackage package) {
    final value = _packageIconPaths[package.key]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? customManagerDisplayName(String managerId) {
    final value = _customManagerDisplayNames[managerId]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String displayNameForManagerId(String managerId) {
    return customManagerDisplayName(managerId) ??
        _adapters
            .firstWhere((adapter) => adapter.definition.id == managerId)
            .definition
            .displayName;
  }

  String displayNameForHomeFilterGroup(String groupId) {
    final group = _homeFilterGroupById(groupId);
    if (group == null) {
      return groupId;
    }
    return group.displayName;
  }

  String? iconPathForHomeFilterGroup(String groupId) {
    final group = _homeFilterGroupById(groupId);
    final value = group?.iconPath?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String displayNameForPackage(ManagedPackage package) {
    return displayNameForManagerId(package.managerId);
  }

  Future<void> setLocale(Locale value) async {
    _locale = _normalizeLocale(value);
    await _settingsStore.saveLocaleCode(_locale.languageCode);
    notifyListeners();
  }

  Future<void> setThemePaletteId(String value) async {
    _themePaletteId = _normalizeThemePaletteId(value);
    await _settingsStore.saveThemePaletteId(_themePaletteId);
    notifyListeners();
  }

  Future<void> setCustomThemeSeedColor(
    Color value, {
    bool selectCustomPalette = false,
  }) async {
    _customThemeSeedColor = _normalizeThemeSeedColor(value.toARGB32());
    await _settingsStore.saveCustomThemeSeedColorValue(
      _customThemeSeedColor.toARGB32(),
    );
    if (selectCustomPalette) {
      _themePaletteId = customAppThemePaletteId;
      await _settingsStore.saveThemePaletteId(_themePaletteId);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await _settingsStore.saveThemeModeName(value.name);
    notifyListeners();
  }

  Future<void> setAutoCheckAppUpdates(bool value) async {
    _autoCheckAppUpdates = value;
    await _settingsStore.saveAutoCheckAppUpdates(value);
    notifyListeners();
  }

  Future<void> setRememberWindowPlacement(bool value) async {
    _rememberWindowPlacement = value;
    await _settingsStore.saveRememberWindowPlacement(value);
    notifyListeners();
  }

  Future<void> setUseGithubMirrorForDownloads(bool value) async {
    _useGithubMirrorForDownloads = value;
    await _settingsStore.saveUseGithubMirrorForDownloads(value);
    notifyListeners();
  }

  Future<void> setGithubMirrorBaseUrl(String value) async {
    final trimmed = value.trim();
    _githubMirrorBaseUrl = trimmed.isEmpty
        ? defaultGithubMirrorBaseUrl
        : trimmed;
    await _settingsStore.saveGithubMirrorBaseUrl(_githubMirrorBaseUrl);
    notifyListeners();
  }

  Future<AppUpdateInfo> checkForAppUpdate() async {
    if (_isCheckingAppUpdate) {
      throw StateError('正在检查更新，请稍候。');
    }

    _isCheckingAppUpdate = true;
    notifyListeners();
    try {
      return await _appUpdateService.checkForUpdate();
    } finally {
      _isCheckingAppUpdate = false;
      notifyListeners();
    }
  }

  Future<AppUpdateDownloadResult> downloadAppUpdateAsset(
    AppReleaseAsset asset, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) {
    return _appUpdateService.downloadAsset(
      asset,
      onProgress: onProgress,
      useGithubMirror: _useGithubMirrorForDownloads,
      githubMirrorBaseUrl: _githubMirrorBaseUrl,
    );
  }

  Future<void> setCustomFontFamily(String? value) async {
    final trimmed = value?.trim();
    _customFontFamily = trimmed == null || trimmed.isEmpty ? null : trimmed;
    await _settingsStore.saveCustomFontFamily(_customFontFamily);
    notifyListeners();
  }

  Future<void> setCustomFallbackFontFamilies(List<String> values) async {
    _customFallbackFontFamilies
      ..clear()
      ..addAll(values.map((value) => value.trim()).where((v) => v.isNotEmpty));
    await _settingsStore.saveCustomFallbackFontFamilies(
      _customFallbackFontFamilies,
    );
    notifyListeners();
  }

  Future<void> setFontFamilyStack(List<String> values) async {
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || normalized.contains(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }

    _customFontFamily = normalized.isEmpty ? null : normalized.first;
    _customFallbackFontFamilies
      ..clear()
      ..addAll(
        normalized.length <= 1 ? const <String>[] : normalized.sublist(1),
      );

    await _settingsStore.saveCustomFontFamily(_customFontFamily);
    await _settingsStore.saveCustomFallbackFontFamilies(
      _customFallbackFontFamilies,
    );
    notifyListeners();
  }

  List<PackageManagerAdapter> get searchableAdapters =>
      _searchAdaptersForScope(null);

  List<String> get installSearchFilterIds {
    final filterIds = <String>[];
    if (_preferredNodeRegistrySearchAdapter() != null &&
        _availableNodeRegistryInstallManagerIds().isNotEmpty) {
      filterIds.add(_nodeRegistrySearchGroupId);
    }
    for (final adapter in _adapters) {
      if (!_supportsSearchFilter(adapter) ||
          _isNodeRegistryManagerId(adapter.definition.id)) {
        continue;
      }
      filterIds.add(adapter.definition.id);
    }
    return filterIds;
  }

  String installSearchFilterLabel(String filterId) {
    return filterId == _nodeRegistrySearchGroupId
        ? _availableNodeRegistryInstallManagerIds()
              .map(displayNameForManagerId)
              .join('/')
        : displayNameForManagerId(filterId);
  }

  List<String> installSearchFilterManagerIds(String filterId) {
    if (filterId == _nodeRegistrySearchGroupId) {
      return _availableNodeRegistryInstallManagerIds();
    }
    return <String>[filterId];
  }

  String? installSearchFilterRepresentativeManagerId(String filterId) {
    if (filterId == _nodeRegistrySearchGroupId) {
      final managerIds = _availableNodeRegistryInstallManagerIds();
      return managerIds.isEmpty ? null : managerIds.first;
    }
    return filterId;
  }

  bool searchResultMatchesFilter(SearchPackage package, String? filterId) {
    if (filterId == null) {
      return true;
    }
    if (filterId == _nodeRegistrySearchGroupId) {
      return package.installOptions.any(
        (option) => _isNodeRegistryManagerId(option.managerId),
      );
    }
    return package.installOptions.any((option) => option.managerId == filterId);
  }

  Future<void> searchPackages({
    String? managerId,
    required String query,
  }) async {
    final trimmed = query.trim();
    final requestId = ++_searchRequestId;
    _installSearchQuery = query;
    if (trimmed.isEmpty) {
      _searchResults.clear();
      _isSearchingPackages = false;
      notifyListeners();
      return;
    }

    final adapters = _searchAdaptersForScope(managerId);

    _isSearchingPackages = true;
    _searchResults.clear();
    notifyListeners();

    if (adapters.isEmpty) {
      _isSearchingPackages = false;
      notifyListeners();
      return;
    }

    final partialResults = <String, List<SearchPackage>>{};
    var remaining = adapters.length;

    void publish() {
      if (requestId != _searchRequestId) {
        return;
      }
      final flattened = <SearchPackage>[];
      for (final adapter in adapters) {
        flattened.addAll(
          partialResults[adapter.definition.id] ?? const <SearchPackage>[],
        );
      }
      final merged = managerId == null
          ? _mergeSearchResults(flattened)
          : flattened.map(_markInstalledSearchPackage).toList(growable: false);
      _searchResults
        ..clear()
        ..addAll(merged);
      _isSearchingPackages = remaining > 0;
      notifyListeners();
    }

    for (final adapter in adapters) {
      unawaited(() async {
        List<SearchPackage> items;
        try {
          final capability = adapter as PackageSearchCapability;
          items = await capability.searchPackages(_shell, trimmed);
          if (_isNodeRegistryManagerId(adapter.definition.id)) {
            items = items
                .map(_expandNodeRegistrySearchPackage)
                .toList(growable: false);
          }
        } catch (_) {
          items = const <SearchPackage>[];
        }
        if (requestId != _searchRequestId) {
          return;
        }
        partialResults[adapter.definition.id] = items;
        remaining -= 1;
        publish();
      }());
    }
  }

  PackageCommand? installCommandFor(SearchPackageInstallOption option) {
    final capability = _capabilityOf<PackageInstallCapability>(
      _adapterFor(option.managerId),
    );
    if (capability == null) {
      return null;
    }
    return capability
        .buildInstallCommand(option)
        .copyWith(busyKey: _installBusyKey(option));
  }

  bool canInstallSpecificVersion(SearchPackageInstallOption option) {
    return _capabilityOf<VersionedPackageInstallCapability>(
          _adapterFor(option.managerId),
        ) !=
        null;
  }

  bool canInstallLatestTag(SearchPackageInstallOption option) {
    return _capabilityOf<LatestTagInstallCapability>(
          _adapterFor(option.managerId),
        ) !=
        null;
  }

  Future<PackageVersionQueryResult> loadInstallableVersions(
    SearchPackageInstallOption option,
  ) async {
    final capability = _capabilityOf<VersionedPackageInstallCapability>(
      _adapterFor(option.managerId),
    );
    if (capability == null) {
      return const PackageVersionQueryResult();
    }

    final result = await capability.listInstallableVersions(_shell, option);
    final versions = <String>[];
    final seen = <String>{};
    for (final value in result.versions) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      versions.add(trimmed);
    }
    return PackageVersionQueryResult(versions: versions, note: result.note);
  }

  PackageCommand? installCommandForLatest(SearchPackageInstallOption option) {
    final capability = _capabilityOf<LatestTagInstallCapability>(
      _adapterFor(option.managerId),
    );
    if (capability == null) {
      return null;
    }

    return capability
        .buildLatestInstallCommand(option)
        .copyWith(busyKey: _installBusyKey(option, version: 'latest'));
  }

  PackageCommand? installCommandForVersion(
    SearchPackageInstallOption option,
    String version,
  ) {
    final normalizedVersion = version.trim();
    if (normalizedVersion.isEmpty) {
      return null;
    }

    final capability = _capabilityOf<VersionedPackageInstallCapability>(
      _adapterFor(option.managerId),
    );
    if (capability == null) {
      return null;
    }

    return capability
        .buildVersionedInstallCommand(option, normalizedVersion)
        .copyWith(busyKey: _installBusyKey(option, version: normalizedVersion));
  }

  Future<void> reorderManager(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _adapters.length) {
      return;
    }
    if (newIndex < 0 || newIndex >= _adapters.length) {
      return;
    }

    final adapter = _adapters.removeAt(oldIndex);
    _adapters.insert(newIndex, adapter);

    final snapshotIndex = _snapshots.indexWhere(
      (snapshot) => snapshot.manager.id == adapter.definition.id,
    );
    if (snapshotIndex >= 0) {
      final snapshot = _snapshots.removeAt(snapshotIndex);
      final targetSnapshotIndex = _adapters.indexWhere(
        (item) => item.definition.id == snapshot.manager.id,
      );
      _snapshots.insert(targetSnapshotIndex, snapshot);
    }

    notifyListeners();

    unawaited(
      _settingsStore.saveManagerOrderIds(
        _adapters.map((item) => item.definition.id).toList(growable: false),
      ),
    );
  }

  Future<void> ensureLoaded() async {
    await _ensureManagerVisibilityInitialized();
    if (_hasTriggeredInitialRefresh) {
      _realignSelection();
      notifyListeners();
      return;
    }

    _hasTriggeredInitialRefresh = true;
    _realignSelection();
    notifyListeners();
    if (_hasCachedSnapshots) {
      unawaited(loadAll());
      return;
    }

    await loadAll();
  }

  Future<void> loadAll() async {
    await _ensureManagerVisibilityInitialized();

    final visibleAdapters = _adapters
        .where(
          (adapter) =>
              _shouldLoadManagerForHome(adapter.definition.id) &&
              _supportsInstalledPackages(adapter),
        )
        .toList(growable: false);

    if (visibleAdapters.isEmpty) {
      _isRefreshingAll = false;
      _realignSelection();
      notifyListeners();
      return;
    }

    _isRefreshingAll = true;
    for (var i = 0; i < _snapshots.length; i++) {
      if (!_shouldLoadManagerForHome(_snapshots[i].manager.id)) {
        continue;
      }
      _snapshots[i] = _snapshots[i].copyWith(
        loadState: ManagerLoadState.loading,
        clearError: true,
      );
    }
    notifyListeners();

    await Future.wait(visibleAdapters.map(_loadAdapter));

    _isRefreshingAll = false;
    _realignSelection();
    notifyListeners();
  }

  Future<void> refreshManager(String managerId) async {
    if (!_shouldLoadManagerForHome(managerId)) {
      return;
    }

    final adapter = _adapterFor(managerId);
    if (adapter == null || !_supportsInstalledPackages(adapter)) {
      return;
    }
    await _loadAdapter(adapter);
    _realignSelection();
    notifyListeners();
  }

  Future<void> refreshCurrentSelection() async {
    final managerId = _selectedManagerId;
    if (managerId == null || _selectedHomeFilterGroup != null) {
      await loadAll();
      return;
    }
    await refreshManager(managerId);
  }

  Future<void> _loadAdapter(PackageManagerAdapter adapter) async {
    final capability = _capabilityOf<InstalledPackageCapability>(adapter);
    if (capability == null) {
      return;
    }

    _setSnapshot(
      adapter.definition.id,
      _snapshotFor(
        adapter.definition.id,
      ).copyWith(loadState: ManagerLoadState.loading, clearError: true),
    );
    notifyListeners();

    try {
      final packages = await capability.listPackages(_shell);
      await _resolvePackageIcons(adapter.definition.id, packages);
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
          title: '${displayNameForManagerId(adapter.definition.id)} 已同步',
          message: '已加载 ${packages.length} 个已安装包。',
        ),
      );
      _hasCachedSnapshots = true;
      await _snapshotStore.save(_snapshots);
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
          title: '${displayNameForManagerId(adapter.definition.id)} 加载失败',
          message: '$error',
          isError: true,
        ),
      );
      await _snapshotStore.save(_snapshots);
    }
  }

  void selectManager(String? managerId) {
    if (managerId == null || managerId == allFilterId) {
      _selectedManagerId = null;
      _realignSelection();
      notifyListeners();
      return;
    }

    if (isHomeFilterGroupId(managerId)) {
      final group = _homeFilterGroupById(managerId);
      if (group == null || !group.isVisible) {
        return;
      }
      _selectedManagerId = managerId;
      _realignSelection();
      notifyListeners();
      return;
    }

    if (!isManagerVisible(managerId) ||
        !_supportsInstalledPackagesById(managerId)) {
      return;
    }

    _selectedManagerId = managerId;
    _realignSelection();
    notifyListeners();
  }

  Future<void> setManagerVisibility(String managerId, bool isVisible) async {
    if (isVisible) {
      _visibleManagerIds.add(managerId);
      _manuallyHiddenManagerIds.remove(managerId);
    } else {
      _visibleManagerIds.remove(managerId);
      _manuallyHiddenManagerIds.add(managerId);
      if (!isHomeFilterGroupId(managerId)) {
        final snapshot = _snapshotFor(managerId);
        _setSnapshot(
          managerId,
          snapshot.copyWith(
            packages: const <ManagedPackage>[],
            loadState: ManagerLoadState.idle,
            clearError: true,
          ),
        );
        _clearPackageIconsForManager(managerId);
      }
    }

    await _settingsStore.saveVisibleManagerIds(_visibleManagerIds);
    await _settingsStore.saveManuallyHiddenManagerIds(
      _manuallyHiddenManagerIds,
    );

    if (_selectedManagerId != null &&
        !isHomeFilterGroupId(_selectedManagerId!) &&
        !isManagerVisible(_selectedManagerId!)) {
      _selectedManagerId = null;
    }

    _invalidateVisiblePackagesCache();
    _realignSelection();
    notifyListeners();

    if (isVisible &&
        _hasTriggeredInitialRefresh &&
        !isHomeFilterGroupId(managerId)) {
      await refreshManager(managerId);
    }
  }

  Future<void> setHomeFilterGroupVisibility(
    String groupId,
    bool isVisible,
  ) async {
    final index = _indexOfHomeFilterGroup(groupId);
    if (index < 0) {
      return;
    }

    _homeFilterGroups[index] = _homeFilterGroups[index].copyWith(
      isVisible: isVisible,
    );
    if (_selectedManagerId == groupId && !isVisible) {
      _selectedManagerId = null;
    }
    _invalidateVisiblePackagesCache();
    _realignSelection();
    await _settingsStore.saveHomeFilterGroups(_homeFilterGroups);
    notifyListeners();
    if (isVisible) {
      await _loadManagersForHomeFilterGroup(_homeFilterGroups[index]);
    }
  }

  Future<void> reorderHomeFilterGroup(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _homeFilterGroups.length) {
      return;
    }
    if (newIndex < 0 || newIndex >= _homeFilterGroups.length) {
      return;
    }

    final group = _homeFilterGroups.removeAt(oldIndex);
    _homeFilterGroups.insert(newIndex, group);
    _invalidateVisiblePackagesCache();
    await _settingsStore.saveHomeFilterGroups(_homeFilterGroups);
    notifyListeners();
  }

  Future<void> createHomeFilterGroup({
    required String displayName,
    String? iconPath,
    List<String> managerIds = const <String>[],
    List<String> packageKeys = const <String>[],
  }) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final nextGroup = HomeFilterGroup(
      id: 'group_${DateTime.now().microsecondsSinceEpoch}',
      kind: HomeFilterGroupKind.custom,
      displayName: normalizedName,
      iconPath: _normalizeOptionalText(iconPath),
      managerIds: _normalizeStringList(managerIds),
      packageKeys: _normalizeStringList(packageKeys),
    );
    _homeFilterGroups.add(nextGroup);
    _invalidateVisiblePackagesCache();
    await _settingsStore.saveHomeFilterGroups(_homeFilterGroups);
    notifyListeners();
    await _loadManagersForHomeFilterGroup(nextGroup);
  }

  Future<void> updateHomeFilterGroup(HomeFilterGroup nextGroup) async {
    final index = _indexOfHomeFilterGroup(nextGroup.id);
    if (index < 0) {
      return;
    }

    final normalizedName = nextGroup.displayName.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final normalizedGroup = nextGroup.copyWith(
      displayName: normalizedName,
      iconPath: _normalizeOptionalText(nextGroup.iconPath),
      managerIds: _normalizeStringList(nextGroup.managerIds),
      packageKeys: _normalizeStringList(nextGroup.packageKeys),
    );
    _homeFilterGroups[index] = normalizedGroup;
    _invalidateVisiblePackagesCache();
    await _settingsStore.saveHomeFilterGroups(_homeFilterGroups);
    notifyListeners();
    await _loadManagersForHomeFilterGroup(normalizedGroup);
  }

  Future<void> deleteHomeFilterGroup(String groupId) async {
    final index = _indexOfHomeFilterGroup(groupId);
    if (index < 0 || _homeFilterGroups[index].isBuiltIn) {
      return;
    }

    _homeFilterGroups.removeAt(index);
    if (_selectedManagerId == groupId) {
      _selectedManagerId = null;
    }
    _invalidateVisiblePackagesCache();
    _realignSelection();
    await _settingsStore.saveHomeFilterGroups(_homeFilterGroups);
    notifyListeners();
  }

  Future<void> refreshManagerAvailability() async {
    if (_isRefreshingManagerAvailability) {
      return;
    }

    _isRefreshingManagerAvailability = true;
    notifyListeners();

    try {
      final availability = await _detectManagerAvailability();
      final managersToDisable = _visibleManagerIds
          .where(
            (managerId) =>
                !isHomeFilterGroupId(managerId) &&
                !(availability[managerId] ?? false),
          )
          .toList(growable: false);

      _managerAvailability
        ..clear()
        ..addAll(availability);

      for (final managerId in managersToDisable) {
        _visibleManagerIds.remove(managerId);
        final snapshot = _snapshotFor(managerId);
        _setSnapshot(
          managerId,
          snapshot.copyWith(
            packages: const <ManagedPackage>[],
            loadState: ManagerLoadState.idle,
            clearError: true,
          ),
        );
        _clearPackageIconsForManager(managerId);
      }

      if (_selectedManagerId != null &&
          !isHomeFilterGroupId(_selectedManagerId!) &&
          !isManagerVisible(_selectedManagerId!)) {
        _selectedManagerId = null;
      }

      _realignSelection();
      await _settingsStore.saveVisibleManagerIds(_visibleManagerIds);
    } finally {
      _isRefreshingManagerAvailability = false;
      notifyListeners();
    }
  }

  Future<void> setCustomManagerIconPath(String managerId, String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      _customManagerIconPaths.remove(managerId);
    } else {
      _customManagerIconPaths[managerId] = trimmed;
    }

    await _settingsStore.saveCustomManagerIconPaths(_customManagerIconPaths);
    notifyListeners();
  }

  Future<void> clearCustomManagerIconPath(String managerId) async {
    if (_customManagerIconPaths.remove(managerId) == null) {
      return;
    }

    await _settingsStore.saveCustomManagerIconPaths(_customManagerIconPaths);
    notifyListeners();
  }

  Future<void> setCustomManagerDisplayName(
    String managerId,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _customManagerDisplayNames.remove(managerId);
    } else {
      _customManagerDisplayNames[managerId] = trimmed;
    }

    await _settingsStore.saveCustomManagerDisplayNames(
      _customManagerDisplayNames,
    );
    _invalidateVisiblePackagesCache();
    notifyListeners();
  }

  Future<void> clearCustomManagerDisplayName(String managerId) async {
    if (_customManagerDisplayNames.remove(managerId) == null) {
      return;
    }

    await _settingsStore.saveCustomManagerDisplayNames(
      _customManagerDisplayNames,
    );
    _invalidateVisiblePackagesCache();
    notifyListeners();
  }

  Future<void> _resolvePackageIcons(
    String managerId,
    List<ManagedPackage> packages,
  ) async {
    _clearPackageIconsForManager(managerId);

    if (managerId != 'winget' || packages.isEmpty) {
      return;
    }

    final resolved = await _wingetIconResolver.resolveIconPaths(
      _shell,
      packages,
    );
    _packageIconPaths.addAll(resolved);
  }

  void _clearPackageIconsForManager(String managerId) {
    _packageIconPaths.removeWhere((key, _) => key.startsWith('$managerId::'));
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
    if (!additive &&
        !range &&
        _selectedPackage?.key == targetKey &&
        _selectedPackageKeys.length == 1 &&
        _selectedPackageKeys.contains(targetKey)) {
      return;
    }
    if (range) {
      final anchorKey =
          _selectionAnchorKey ?? _selectedPackage?.key ?? targetKey;
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
      if (_selectedPackage?.key == targetKey &&
          _selectionAnchorKey == targetKey) {
        return;
      }
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
    final capability = _capabilityOf<PackageActionCapability>(
      _adapterFor(package.managerId),
    );
    return capability?.buildCommand(action, package);
  }

  PackageCommand? batchUpdateCommandForSelectedManager() {
    final capability = _capabilityOf<PackageBatchUpdateCapability>(
      selectedAdapter,
    );
    if (capability == null) {
      return null;
    }
    return capability.buildBatchUpdateCommand();
  }

  Future<void> batchCheckLatestVersionsForSelectedManager() async {
    final managerId = _selectedManagerId;
    final snapshot = selectedManagerSnapshot;
    final capability = _capabilityOf<LatestVersionLookupCapability>(
      selectedAdapter,
    );
    if (managerId == null || snapshot == null || capability == null) {
      return;
    }

    final busyKey = _batchLatestBusyKey(managerId);
    if (_runningCommands.contains(busyKey)) {
      return;
    }

    final packages = snapshot.packages
        .where(capability.supportsLatestVersionLookup)
        .toList(growable: false);
    if (packages.isEmpty ||
        !capability.supportsBatchLatestVersionLookup(packages)) {
      return;
    }

    final batchCapability = capability is BatchLatestVersionLookupCapability
        ? capability
        : null;
    final packageBusyKeys = batchCapability == null
        ? const <String>[]
        : packages.map(_latestVersionBusyKey).toList(growable: false);

    _runningCommands.add(busyKey);
    if (batchCapability != null) {
      _runningCommandInfo[busyKey] = RunningCommandInfo(
        busyKey: busyKey,
        command: batchCapability.batchLatestVersionLookupCommand(packages),
      );
    }
    _runningCommands.addAll(packageBusyKeys);
    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: '正在批量检查 ${displayNameForManagerId(snapshot.manager.id)}',
        message: '准备检查 ${packages.length} 个包的最新版本。',
      ),
    );
    notifyListeners();

    try {
      if (batchCapability != null) {
        await _checkLatestVersionsInBatch(packages, batchCapability);
      } else {
        for (final package in packages) {
          await checkLatestVersion(package);
        }
      }
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '${displayNameForManagerId(snapshot.manager.id)} 批量检查更新完成',
          message: '已完成 ${packages.length} 个包的最新版本检查。',
        ),
      );
    } catch (error) {
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '${displayNameForManagerId(snapshot.manager.id)} 批量检查更新失败',
          message: '$error',
          isError: true,
        ),
      );
    } finally {
      _runningCommands.remove(busyKey);
      _runningCommandInfo.remove(busyKey);
      _runningCommands.removeAll(packageBusyKeys);
      notifyListeners();
    }
  }

  Future<void> batchCheckLatestVersionsForCurrentSelection() async {
    final selectedGroup = _selectedHomeFilterGroup;
    if (selectedGroup == null && _selectedManagerId != null) {
      await batchCheckLatestVersionsForSelectedManager();
      return;
    }

    if (_isBatchCheckingLatestForGroup) {
      return;
    }

    final packages = visiblePackages
        .where(canCheckLatestVersion)
        .toList(growable: false);
    if (packages.isEmpty) {
      return;
    }

    _isBatchCheckingLatestForGroup = true;
    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: '正在批量检查更新',
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
          title: '批量检查更新完成',
          message: '已完成 ${packages.length} 个包的最新版本检查。',
        ),
      );
    } catch (error) {
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '批量检查更新失败',
          message: '$error',
          isError: true,
        ),
      );
    } finally {
      _isBatchCheckingLatestForGroup = false;
      notifyListeners();
    }
  }

  Future<ShellResult> runCommand(PackageCommand command) async {
    if (isBusy(command.busyKey)) {
      return const ShellResult(
        exitCode: 125,
        stdout: '',
        stderr: '该命令已在执行中或已在队列中，请勿重复启动。',
      );
    }

    final activeManagerBusyKey =
        _activeManagerCommandBusyKeys[command.managerId];
    final hasQueuedManagerCommands =
        _queuedManagerCommands[command.managerId]?.isNotEmpty ?? false;
    if (activeManagerBusyKey != null || hasQueuedManagerCommands) {
      final completer = Completer<ShellResult>();
      (_queuedManagerCommands[command.managerId] ??= <_QueuedPackageCommand>[])
          .add(_QueuedPackageCommand(command: command, completer: completer));
      _queuedCommands.add(command.busyKey);
      _queuedCommandInfo[command.busyKey] = RunningCommandInfo(
        busyKey: command.busyKey,
        command: command.command,
        canCancel: true,
        statusLabel: '排队中',
      );
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '${command.label} 已加入队列',
          message: command.command,
        ),
      );
      notifyListeners();
      return completer.future;
    }

    return _runCommandNow(command);
  }

  Future<ShellResult> _runCommandNow(PackageCommand command) async {
    _runningCommands.add(command.busyKey);
    _activeManagerCommandBusyKeys[command.managerId] = command.busyKey;
    _runningCommandInfo[command.busyKey] = RunningCommandInfo(
      busyKey: command.busyKey,
      command: command.command,
      canCancel: true,
    );
    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: command.label,
        message: command.command,
      ),
    );
    notifyListeners();

    try {
      final result = await _shell.runRequest(
        command.request,
        timeout: command.timeout,
        executionKey: command.busyKey,
      );

      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: result.isSuccess
              ? '${command.label} 已完成'
              : result.wasCancelled
              ? '${command.label} 已取消'
              : '${command.label} 失败',
          message: result.wasCancelled
              ? (result.combinedOutput.isEmpty
                    ? '命令已取消。'
                    : result.combinedOutput)
              : result.combinedOutput.isEmpty
              ? '命令执行完成，但没有控制台输出。'
              : result.combinedOutput,
          isError: !result.isSuccess && !result.wasCancelled,
        ),
      );

      if (result.isSuccess) {
        await refreshManager(command.managerId);
      }

      return result;
    } finally {
      _runningCommands.remove(command.busyKey);
      _runningCommandInfo.remove(command.busyKey);
      if (_activeManagerCommandBusyKeys[command.managerId] == command.busyKey) {
        _activeManagerCommandBusyKeys.remove(command.managerId);
      }
      notifyListeners();
      _startNextQueuedCommand(command.managerId);
    }
  }

  void _startNextQueuedCommand(String managerId) {
    if (_activeManagerCommandBusyKeys.containsKey(managerId)) {
      return;
    }

    final queue = _queuedManagerCommands[managerId];
    if (queue == null || queue.isEmpty) {
      _queuedManagerCommands.remove(managerId);
      return;
    }

    final next = queue.removeAt(0);
    if (queue.isEmpty) {
      _queuedManagerCommands.remove(managerId);
    }
    _queuedCommands.remove(next.command.busyKey);
    _queuedCommandInfo.remove(next.command.busyKey);
    notifyListeners();
    unawaited(() async {
      try {
        next.completer.complete(await _runCommandNow(next.command));
      } catch (error, stackTrace) {
        next.completer.completeError(error, stackTrace);
      }
    }());
  }

  Future<String?> checkLatestVersion(ManagedPackage package) async {
    final capability = _capabilityOf<LatestVersionLookupCapability>(
      _adapterFor(package.managerId),
    );
    if (capability == null ||
        !capability.supportsLatestVersionLookup(package)) {
      return null;
    }

    final busyKey = _latestVersionBusyKey(package);
    if (_runningCommands.contains(busyKey)) {
      return null;
    }

    _runningCommands.add(busyKey);
    _runningCommandInfo[busyKey] = RunningCommandInfo(
      busyKey: busyKey,
      command: capability.latestVersionLookupCommand(package),
    );
    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: '正在检查 ${package.name}',
        message: '正在检查 ${displayNameForPackage(package)} 的最新版本。',
      ),
    );
    notifyListeners();

    try {
      final checkedAt = DateTime.now();
      final latestVersion = await capability.lookupLatestVersion(
        _shell,
        package,
      );
      _applyLatestVersionResult(package, latestVersion, checkedAt);
      await _persistLatestVersionInfo();
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '已检查 ${package.name}',
          message: latestVersion == package.version
              ? '当前已是最新版本：$latestVersion。'
              : '最新版本：$latestVersion。',
        ),
      );
      return latestVersion;
    } catch (error) {
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '检查 ${package.name} 失败',
          message: '$error',
          isError: true,
        ),
      );
      return null;
    } finally {
      _runningCommands.remove(busyKey);
      _runningCommandInfo.remove(busyKey);
      notifyListeners();
    }
  }

  Future<String?> loadPackageDetails(ManagedPackage package) async {
    final capability = _capabilityOf<PackageDetailsCapability>(
      _adapterFor(package.managerId),
    );
    if (capability == null || !capability.supportsPackageDetails(package)) {
      return null;
    }

    final busyKey = _packageDetailsBusyKey(package);
    if (_runningCommands.contains(busyKey)) {
      return null;
    }

    _runningCommands.add(busyKey);
    _pushActivity(
      ActivityEntry(
        timestamp: DateTime.now(),
        title: '正在查看 ${package.name}',
        message: '正在读取 ${displayNameForPackage(package)} 的详情信息。',
      ),
    );
    notifyListeners();

    try {
      final details = await capability.loadPackageDetails(_shell, package);
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '已读取 ${package.name} 详情',
          message: '详情信息已就绪。',
        ),
      );
      return details;
    } catch (error) {
      _pushActivity(
        ActivityEntry(
          timestamp: DateTime.now(),
          title: '读取 ${package.name} 详情失败',
          message: '$error',
          isError: true,
        ),
      );
      return null;
    } finally {
      _runningCommands.remove(busyKey);
      notifyListeners();
    }
  }

  void _setSnapshot(String managerId, ManagerSnapshot next) {
    for (var i = 0; i < _snapshots.length; i++) {
      if (_snapshots[i].manager.id == managerId) {
        _snapshots[i] = next;
        _invalidateVisiblePackagesCache();
        return;
      }
    }
  }

  void _invalidateVisiblePackagesCache() {
    _visiblePackagesDataStamp += 1;
    _cachedVisiblePackages = null;
  }

  Future<void> _ensureManagerVisibilityInitialized() async {
    if (_hasInitializedManagerVisibility) {
      if (_managerAvailability.isEmpty) {
        _managerAvailability.addAll(await _detectManagerAvailability());
      }
      if (_manuallyHiddenManagerIds.isEmpty) {
        _manuallyHiddenManagerIds.addAll(
          await _settingsStore.loadManuallyHiddenManagerIds() ??
              const <String>{},
        );
      }
      if (_customManagerIconPaths.isEmpty) {
        _customManagerIconPaths.addAll(
          await _settingsStore.loadCustomManagerIconPaths(),
        );
      }
      if (_customManagerDisplayNames.isEmpty) {
        _customManagerDisplayNames.addAll(
          await _settingsStore.loadCustomManagerDisplayNames(),
        );
      }
      if (managerOrderIds.isEmpty) {
        _applyManagerOrder(await _settingsStore.loadManagerOrderIds());
      }
      final savedCustomFontFamily = await _settingsStore.loadCustomFontFamily();
      final savedFallbackFonts = await _settingsStore
          .loadCustomFallbackFontFamilies();
      _locale = _normalizeLocale(
        Locale(await _settingsStore.loadLocaleCode() ?? _locale.languageCode),
      );
      _themePaletteId = _normalizeThemePaletteId(
        await _settingsStore.loadThemePaletteId(),
      );
      _customThemeSeedColor = _normalizeThemeSeedColor(
        await _settingsStore.loadCustomThemeSeedColorValue(),
      );
      _themeMode = _parseThemeModeName(
        await _settingsStore.loadThemeModeName(),
        fallback: _themeMode,
      );
      _autoCheckAppUpdates = await _settingsStore.loadAutoCheckAppUpdates();
      _rememberWindowPlacement =
          await _settingsStore.loadRememberWindowPlacement();
      _useGithubMirrorForDownloads = await _settingsStore
          .loadUseGithubMirrorForDownloads();
      _githubMirrorBaseUrl = await _settingsStore.loadGithubMirrorBaseUrl();
      _customFontFamily = savedCustomFontFamily?.trim().isEmpty ?? true
          ? null
          : savedCustomFontFamily?.trim();
      _customFallbackFontFamilies
        ..clear()
        ..addAll(savedFallbackFonts);
      _invalidateVisiblePackagesCache();
      return;
    }

    final savedVisibleManagerIds = await _settingsStore.loadVisibleManagerIds();
    final savedManuallyHiddenManagerIds = await _settingsStore
        .loadManuallyHiddenManagerIds();
    final savedCustomManagerIconPaths = await _settingsStore
        .loadCustomManagerIconPaths();
    final savedCustomManagerDisplayNames = await _settingsStore
        .loadCustomManagerDisplayNames();
    final savedManagerOrderIds = await _settingsStore.loadManagerOrderIds();
    final savedLocaleCode = await _settingsStore.loadLocaleCode();
    final savedThemePaletteId = await _settingsStore.loadThemePaletteId();
    final savedThemeModeName = await _settingsStore.loadThemeModeName();
    final savedCustomThemeSeedColorValue = await _settingsStore
        .loadCustomThemeSeedColorValue();
    final savedAutoCheckAppUpdates = await _settingsStore
        .loadAutoCheckAppUpdates();
    final savedRememberWindowPlacement = await _settingsStore
        .loadRememberWindowPlacement();
    final savedUseGithubMirrorForDownloads = await _settingsStore
        .loadUseGithubMirrorForDownloads();
    final savedGithubMirrorBaseUrl = await _settingsStore
        .loadGithubMirrorBaseUrl();
    final savedCustomFontFamily = await _settingsStore.loadCustomFontFamily();
    final savedFallbackFonts = await _settingsStore
        .loadCustomFallbackFontFamilies();
    final availability = await _detectManagerAvailability();
    _managerAvailability
      ..clear()
      ..addAll(availability);

    final manuallyHiddenManagerIds =
        savedManuallyHiddenManagerIds ??
        _inferLegacyManuallyHiddenManagerIds(
          savedVisibleManagerIds: savedVisibleManagerIds,
          savedManagerOrderIds: savedManagerOrderIds,
        );
    _manuallyHiddenManagerIds
      ..clear()
      ..addAll(manuallyHiddenManagerIds);

    _visibleManagerIds
      ..clear()
      ..addAll(
        _resolveVisibleManagerIds(
          baseVisibleManagerIds: savedVisibleManagerIds,
          availability: availability,
          manuallyHiddenManagerIds: _manuallyHiddenManagerIds,
        ),
      );

    _customManagerIconPaths
      ..clear()
      ..addAll(savedCustomManagerIconPaths);

    _customManagerDisplayNames
      ..clear()
      ..addAll(savedCustomManagerDisplayNames);
    _applyManagerOrder(savedManagerOrderIds);

    _locale = _normalizeLocale(
      Locale(savedLocaleCode?.trim().isEmpty ?? true ? 'zh' : savedLocaleCode!),
    );
    _themePaletteId = _normalizeThemePaletteId(savedThemePaletteId);
    _customThemeSeedColor = _normalizeThemeSeedColor(
      savedCustomThemeSeedColorValue,
    );
    _themeMode = _parseThemeModeName(savedThemeModeName);
    _autoCheckAppUpdates = savedAutoCheckAppUpdates;
    _rememberWindowPlacement = savedRememberWindowPlacement;
    _useGithubMirrorForDownloads = savedUseGithubMirrorForDownloads;
    _githubMirrorBaseUrl = savedGithubMirrorBaseUrl;
    _customFontFamily = savedCustomFontFamily?.trim().isEmpty ?? true
        ? null
        : savedCustomFontFamily?.trim();
    _customFallbackFontFamilies
      ..clear()
      ..addAll(savedFallbackFonts);

    _hasInitializedManagerVisibility = true;

    if (savedVisibleManagerIds == null ||
        !_sameStringSet(savedVisibleManagerIds, _visibleManagerIds)) {
      await _settingsStore.saveVisibleManagerIds(_visibleManagerIds);
    }
    if (savedManuallyHiddenManagerIds == null ||
        !_sameStringSet(
          savedManuallyHiddenManagerIds,
          _manuallyHiddenManagerIds,
        )) {
      await _settingsStore.saveManuallyHiddenManagerIds(
        _manuallyHiddenManagerIds,
      );
    }
    _invalidateVisiblePackagesCache();
  }

  Future<Map<String, bool>> _detectManagerAvailability() async {
    final entries = await Future.wait(
      _adapters.map((adapter) async {
        final executable = adapter.definition.executable;
        final isAvailable = await _shell.isExecutableAvailable(executable);
        return MapEntry(adapter.definition.id, isAvailable);
      }),
    );
    return Map<String, bool>.fromEntries(entries);
  }

  Set<String> _resolveVisibleManagerIds({
    required Set<String>? baseVisibleManagerIds,
    required Map<String, bool> availability,
    required Set<String> manuallyHiddenManagerIds,
  }) {
    final visibleManagerIds = <String>{...?baseVisibleManagerIds};
    for (final entry in availability.entries) {
      if (entry.value && !manuallyHiddenManagerIds.contains(entry.key)) {
        visibleManagerIds.add(entry.key);
      }
    }
    visibleManagerIds.removeWhere(manuallyHiddenManagerIds.contains);
    return visibleManagerIds;
  }

  Set<String> _inferLegacyManuallyHiddenManagerIds({
    required Set<String>? savedVisibleManagerIds,
    required List<String> savedManagerOrderIds,
  }) {
    if (savedVisibleManagerIds == null || savedManagerOrderIds.isEmpty) {
      return const <String>{};
    }
    return savedManagerOrderIds.toSet().difference(savedVisibleManagerIds);
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
      _invalidateVisiblePackagesCache();
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

  T? _capabilityOf<T>(PackageManagerAdapter? adapter) {
    final current = adapter;
    if (current is T) {
      return current as T;
    }
    return null;
  }

  bool _supportsInstalledPackages(PackageManagerAdapter adapter) {
    return adapter is InstalledPackageCapability;
  }

  bool _supportsInstalledPackagesById(String managerId) {
    final adapter = _adapterFor(managerId);
    return adapter != null && _supportsInstalledPackages(adapter);
  }

  void _realignSelection() {
    if (_selectedManagerId != null) {
      final selectedGroup = _selectedHomeFilterGroup;
      if (selectedGroup != null) {
        if (!selectedGroup.isVisible) {
          _selectedManagerId = null;
        }
      } else if (!isManagerVisible(_selectedManagerId!) ||
          !_supportsInstalledPackagesById(_selectedManagerId!)) {
        _selectedManagerId = null;
      }
    }
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

  String _packageDetailsBusyKey(ManagedPackage package) {
    return 'package-details::${package.key}';
  }

  String _installBusyKeyPrefix(SearchPackageInstallOption package) {
    final identifier = package.identifier?.trim() ?? '';
    return 'install-package::${package.managerId}::${package.packageName}::$identifier';
  }

  String _installBusyKey(
    SearchPackageInstallOption package, {
    String? version,
  }) {
    final prefix = _installBusyKeyPrefix(package);
    final normalizedVersion = version?.trim();
    if (normalizedVersion == null || normalizedVersion.isEmpty) {
      return prefix;
    }
    return '$prefix::$normalizedVersion';
  }

  String _batchLatestBusyKey(String managerId) {
    return 'batch-latest::$managerId';
  }

  Future<void> _checkLatestVersionsInBatch(
    List<ManagedPackage> packages,
    BatchLatestVersionLookupCapability capability,
  ) async {
    final checkedAt = DateTime.now();
    final latestVersions = await capability.lookupLatestVersions(
      _shell,
      packages,
    );
    for (final package in packages) {
      final latestVersion = latestVersions[package.key]?.trim();
      _applyLatestVersionResult(
        package,
        latestVersion == null || latestVersion.isEmpty
            ? package.version
            : latestVersion,
        checkedAt,
      );
    }
    await _persistLatestVersionInfo();
  }

  void _applyLatestVersionResult(
    ManagedPackage package,
    String latestVersion,
    DateTime checkedAt,
  ) {
    final normalizedLatestVersion = latestVersion.trim();
    final updatedPackage = package.copyWith(
      latestVersion: normalizedLatestVersion,
      latestVersionCheckedAt: checkedAt,
      notes: package.notes,
    );
    _replacePackage(updatedPackage);
  }

  Future<void> _persistLatestVersionInfo() async {
    await _snapshotStore.save(_snapshots);
  }

  List<SearchPackage> _mergeSearchResults(List<SearchPackage> packages) {
    final merged = <String, SearchPackage>{};
    final ordered = <SearchPackage>[];

    for (final package in packages) {
      final marked = _markInstalledSearchPackage(package);
      final key = _searchMergeKey(marked);
      if (key == null) {
        ordered.add(marked);
        continue;
      }

      final existing = merged[key];
      if (existing == null) {
        merged[key] = marked;
        ordered.add(marked);
        continue;
      }

      final combinedOptions = <SearchPackageInstallOption>[
        ...existing.installOptions,
      ];
      for (final option in marked.installOptions) {
        final exists = combinedOptions.any(
          (item) => item.managerId == option.managerId,
        );
        if (!exists) {
          combinedOptions.add(option);
        }
      }

      final updated = existing.copyWith(
        version: existing.version ?? marked.version,
        description: existing.description ?? marked.description,
        source: existing.source ?? marked.source,
        installOptions: combinedOptions,
      );
      merged[key] = updated;
      final orderedIndex = ordered.indexOf(existing);
      if (orderedIndex >= 0) {
        ordered[orderedIndex] = updated;
      }
    }

    return ordered;
  }

  SearchPackage _markInstalledSearchPackage(SearchPackage package) {
    final options = package.installOptions.isEmpty
        ? <SearchPackageInstallOption>[
            SearchPackageInstallOption(
              managerId: package.managerId,
              managerName: package.managerName,
              packageName: package.name,
              identifier: package.identifier,
              version: package.version,
              source: package.source,
            ),
          ]
        : package.installOptions;

    return package.copyWith(
      installOptions: options
          .map(
            (option) =>
                option.copyWith(isInstalled: _isSearchOptionInstalled(option)),
          )
          .toList(growable: false),
    );
  }

  bool _isSearchOptionInstalled(SearchPackageInstallOption option) {
    for (final snapshot in _snapshots) {
      if (snapshot.manager.id != option.managerId) {
        continue;
      }
      for (final package in snapshot.packages) {
        if (_matchesInstalledSearchOption(package, option)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _matchesInstalledSearchOption(
    ManagedPackage installed,
    SearchPackageInstallOption option,
  ) {
    final installedIdentifier = installed.identifier?.trim().toLowerCase();
    final optionIdentifier = option.identifier?.trim().toLowerCase();
    if (installedIdentifier != null &&
        installedIdentifier.isNotEmpty &&
        optionIdentifier != null &&
        optionIdentifier.isNotEmpty) {
      return installedIdentifier == optionIdentifier;
    }
    return installed.name.trim().toLowerCase() ==
        option.packageName.trim().toLowerCase();
  }

  String? _searchMergeKey(SearchPackage package) {
    final identifier = package.identifier?.trim().toLowerCase();
    if (identifier == null || identifier.isEmpty) {
      return null;
    }
    final groupId =
        package.installOptions.any(
          (option) => _isNodeRegistryManagerId(option.managerId),
        )
        ? _nodeRegistrySearchGroupId
        : package.managerId;
    return '$groupId::$identifier';
  }

  List<PackageManagerAdapter> _searchAdaptersForScope(String? managerId) {
    if (managerId == null) {
      final adapters = <PackageManagerAdapter>[];
      final nodeAdapter = _preferredNodeRegistrySearchAdapter();
      if (nodeAdapter != null &&
          _availableNodeRegistryInstallManagerIds().isNotEmpty) {
        adapters.add(nodeAdapter);
      }
      for (final adapter in _adapters) {
        if (!_supportsSearchFilter(adapter) ||
            _isNodeRegistryManagerId(adapter.definition.id)) {
          continue;
        }
        adapters.add(adapter);
      }
      return adapters;
    }

    if (managerId == _nodeRegistrySearchGroupId) {
      final nodeAdapter = _preferredNodeRegistrySearchAdapter();
      if (nodeAdapter == null ||
          _availableNodeRegistryInstallManagerIds().isEmpty) {
        return const <PackageManagerAdapter>[];
      }
      return <PackageManagerAdapter>[nodeAdapter];
    }

    return _adapters
        .where(
          (adapter) =>
              adapter.definition.id == managerId &&
              _supportsSearchFilter(adapter),
        )
        .toList(growable: false);
  }

  bool _supportsSearchFilter(PackageManagerAdapter adapter) {
    return adapter is PackageSearchCapability &&
        isManagerAvailable(adapter.definition.id);
  }

  bool _isNodeRegistryManagerId(String managerId) {
    return _nodeRegistryInstallPriority.contains(managerId);
  }

  PackageManagerAdapter? _preferredNodeRegistrySearchAdapter() {
    for (final managerId in _nodeRegistrySearchPriority) {
      final adapter = _adapterFor(managerId);
      if (adapter == null || !_supportsSearchFilter(adapter)) {
        continue;
      }
      return adapter;
    }
    return null;
  }

  List<String> _availableNodeRegistryInstallManagerIds() {
    final available = <String>[];
    for (final managerId in _nodeRegistryInstallPriority) {
      final adapter = _adapterFor(managerId);
      if (adapter == null ||
          !isManagerAvailable(managerId) ||
          !_isManagerExposedForInstallSearch(managerId)) {
        continue;
      }
      if (_capabilityOf<PackageInstallCapability>(adapter) == null) {
        continue;
      }
      available.add(managerId);
    }
    return available;
  }

  SearchPackage _expandNodeRegistrySearchPackage(SearchPackage package) {
    final installOptions = _availableNodeRegistryInstallManagerIds()
        .map(
          (managerId) => SearchPackageInstallOption(
            managerId: managerId,
            managerName: displayNameForManagerId(managerId),
            packageName: package.name,
            identifier: package.identifier,
            version: package.version,
            source: package.source,
          ),
        )
        .toList(growable: false);
    return package.copyWith(installOptions: installOptions);
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

  ThemeMode _parseThemeModeName(String? value, {ThemeMode? fallback}) {
    return switch (value?.trim()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => fallback ?? ThemeMode.system,
    };
  }

  static String _normalizeThemePaletteId(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == customAppThemePaletteId) {
      return customAppThemePaletteId;
    }
    return appThemePaletteById(normalized ?? '')?.id ??
        defaultAppThemePaletteId;
  }

  static Color _normalizeThemeSeedColor(int? value) {
    if (value == null) {
      return defaultCustomAppThemeSeedColor;
    }
    final normalizedValue = (value & 0x00FFFFFF) | 0xFF000000;
    return Color(normalizedValue);
  }

  static Locale _normalizeLocale(Locale? value) {
    return switch (value?.languageCode.trim().toLowerCase()) {
      'en' => const Locale('en'),
      _ => const Locale('zh'),
    };
  }

  void _applyManagerOrder(List<String> orderIds) {
    final normalized = orderIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return;
    }

    final ranking = <String, int>{
      for (var i = 0; i < normalized.length; i++) normalized[i]: i,
    };

    _adapters.sort((a, b) {
      final aRank = ranking[a.definition.id] ?? 1 << 20;
      final bRank = ranking[b.definition.id] ?? 1 << 20;
      if (aRank != bRank) {
        return aRank.compareTo(bRank);
      }
      return 0;
    });
    _snapshots.sort((a, b) {
      final aRank = ranking[a.manager.id] ?? 1 << 20;
      final bRank = ranking[b.manager.id] ?? 1 << 20;
      if (aRank != bRank) {
        return aRank.compareTo(bRank);
      }
      return 0;
    });
  }

  static List<ManagerSnapshot> _normalizeSnapshots(
    List<PackageManagerAdapter> adapters,
    List<ManagerSnapshot>? initialSnapshots,
  ) {
    final initialById = <String, ManagerSnapshot>{
      for (final snapshot in initialSnapshots ?? const <ManagerSnapshot>[])
        snapshot.manager.id: snapshot,
    };

    return adapters
        .map((adapter) {
          final manager = adapter.definition;
          final snapshot = initialById[manager.id];
          if (snapshot == null) {
            return ManagerSnapshot(manager: manager);
          }
          return ManagerSnapshot(
            manager: manager,
            packages: snapshot.packages,
            loadState: snapshot.loadState,
            errorMessage: snapshot.errorMessage,
            lastRefreshedAt: snapshot.lastRefreshedAt,
          );
        })
        .toList(growable: true);
  }

  HomeFilterGroup? get _selectedHomeFilterGroup {
    final selectedId = _selectedManagerId;
    if (selectedId == null) {
      return null;
    }
    return _homeFilterGroupById(selectedId);
  }

  HomeFilterGroup? _homeFilterGroupById(String id) {
    for (final group in _homeFilterGroups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  int _indexOfHomeFilterGroup(String id) {
    for (var i = 0; i < _homeFilterGroups.length; i++) {
      if (_homeFilterGroups[i].id == id) {
        return i;
      }
    }
    return -1;
  }

  bool _homeFilterGroupMatchesPackage(
    HomeFilterGroup group,
    ManagedPackage package,
  ) {
    return switch (group.kind) {
      HomeFilterGroupKind.all => true,
      HomeFilterGroupKind.updates => package.hasUpdate,
      HomeFilterGroupKind.custom =>
        group.managerIds.contains(package.managerId) ||
            group.packageKeys.contains(package.key),
    };
  }

  Iterable<ManagerSnapshot> _snapshotsForCurrentSelection() sync* {
    final selectedGroup = _selectedHomeFilterGroup;
    if (selectedGroup != null) {
      final managerIds = _managerIdsReferencedByHomeFilterGroup(selectedGroup);
      for (final snapshot in _snapshots) {
        if (_supportsInstalledPackagesById(snapshot.manager.id) &&
            managerIds.contains(snapshot.manager.id)) {
          yield snapshot;
        }
      }
      return;
    }

    if (_selectedManagerId == null) {
      yield* _homeSnapshots;
      return;
    }

    for (final snapshot in _snapshots) {
      if (snapshot.manager.id == _selectedManagerId) {
        yield snapshot;
      }
    }
  }

  Set<String> _managerIdsReferencedByHomeFilterGroup(HomeFilterGroup group) {
    if (group.kind != HomeFilterGroupKind.custom) {
      return _adapters
          .where(
            (adapter) =>
                isManagerVisible(adapter.definition.id) &&
                _supportsInstalledPackages(adapter),
          )
          .map((adapter) => adapter.definition.id)
          .toSet();
    }

    return <String>{
      ...group.managerIds,
      ...group.packageKeys
          .map(_managerIdFromPackageKey)
          .whereType<String>()
          .where(_supportsInstalledPackagesById),
    };
  }

  String? _managerIdFromPackageKey(String packageKey) {
    final separatorIndex = packageKey.indexOf('::');
    if (separatorIndex <= 0) {
      return null;
    }
    final managerId = packageKey.substring(0, separatorIndex).trim();
    return managerId.isEmpty ? null : managerId;
  }

  Set<String> _managerIdsReferencedByVisibleCustomHomeFilterGroups() {
    return _homeFilterGroups
        .where(
          (group) =>
              group.isVisible && group.kind == HomeFilterGroupKind.custom,
        )
        .expand(_managerIdsReferencedByHomeFilterGroup)
        .toSet();
  }

  bool _shouldLoadManagerForHome(String managerId) {
    return isManagerVisible(managerId) ||
        _managerIdsReferencedByVisibleCustomHomeFilterGroups().contains(
          managerId,
        );
  }

  bool _isManagerExposedForInstallSearch(String managerId) {
    return isManagerVisible(managerId) ||
        _managerIdsReferencedByVisibleCustomHomeFilterGroups().contains(
          managerId,
        );
  }

  Future<void> _loadManagersForHomeFilterGroup(HomeFilterGroup group) async {
    if (!_hasTriggeredInitialRefresh || !group.isVisible) {
      return;
    }

    final targetAdapters = _managerIdsReferencedByHomeFilterGroup(group)
        .where((managerId) => !isManagerVisible(managerId))
        .map(_adapterFor)
        .whereType<PackageManagerAdapter>()
        .where(_supportsInstalledPackages)
        .toList(growable: false);
    if (targetAdapters.isEmpty) {
      return;
    }

    await Future.wait(targetAdapters.map(_loadAdapter));
    _realignSelection();
    notifyListeners();
  }

  static List<HomeFilterGroup> _normalizeHomeFilterGroups(
    List<HomeFilterGroup>? initialGroups,
  ) {
    final groupsById = <String, HomeFilterGroup>{
      allFilterId: const HomeFilterGroup(
        id: allFilterId,
        kind: HomeFilterGroupKind.all,
        displayName: '全部',
      ),
      updateFilterId: const HomeFilterGroup(
        id: updateFilterId,
        kind: HomeFilterGroupKind.updates,
        displayName: '更新',
      ),
    };

    final orderedIds = <String>[];
    for (final group in initialGroups ?? const <HomeFilterGroup>[]) {
      groupsById[group.id] = HomeFilterGroup(
        id: group.id,
        kind: group.kind,
        displayName: group.displayName.trim(),
        isVisible: group.isVisible,
        iconPath: _normalizeOptionalText(group.iconPath),
        managerIds: _normalizeStringList(group.managerIds),
        packageKeys: _normalizeStringList(group.packageKeys),
      );
      if (!orderedIds.contains(group.id)) {
        orderedIds.add(group.id);
      }
    }

    for (final builtinId in <String>[allFilterId, updateFilterId]) {
      if (!orderedIds.contains(builtinId)) {
        orderedIds.insert(
          builtinId == allFilterId
              ? 0
              : orderedIds.contains(allFilterId)
              ? 1
              : 0,
          builtinId,
        );
      }
    }

    return orderedIds.map((id) => groupsById[id]!).toList(growable: true);
  }

  static String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _normalizeStringList(List<String> values) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }
}

bool _sameStringSet(Set<String> left, Set<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final value in left) {
    if (!right.contains(value)) {
      return false;
    }
  }
  return true;
}

class _QueuedPackageCommand {
  const _QueuedPackageCommand({required this.command, required this.completer});

  final PackageCommand command;
  final Completer<ShellResult> completer;
}
