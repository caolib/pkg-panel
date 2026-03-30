import 'package:flutter/material.dart';
import 'package:pkg_panel/src/app.dart';
import 'package:pkg_panel/src/services/package_adapters.dart';
import 'package:pkg_panel/src/services/package_manager_settings_store.dart';
import 'package:pkg_panel/src/services/package_latest_info_store.dart';
import 'package:pkg_panel/src/services/package_panel_controller.dart';
import 'package:pkg_panel/src/services/package_snapshot_store.dart';
import 'package:pkg_panel/src/services/shell_executor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const latestInfoStore = PackageLatestInfoStore();
  const managerSettingsStore = PackageManagerSettingsStore();
  const snapshotStore = PackageSnapshotStore();
  final initialLatestInfo = await latestInfoStore.load();
  final initialVisibleManagerIds = await managerSettingsStore
      .loadVisibleManagerIds();
  final initialHomeFilterGroups = await managerSettingsStore
      .loadHomeFilterGroups();
  final initialManagerOrderIds = await managerSettingsStore
      .loadManagerOrderIds();
  final initialCustomManagerIconPaths = await managerSettingsStore
      .loadCustomManagerIconPaths();
  final initialCustomManagerDisplayNames = await managerSettingsStore
      .loadCustomManagerDisplayNames();
  final initialThemeModeName = await managerSettingsStore.loadThemeModeName();
  final initialAutoCheckAppUpdates = await managerSettingsStore
      .loadAutoCheckAppUpdates();
  final initialUseGithubMirrorForDownloads = await managerSettingsStore
      .loadUseGithubMirrorForDownloads();
  final initialGithubMirrorBaseUrl = await managerSettingsStore
      .loadGithubMirrorBaseUrl();
  final initialCustomFontFamily = await managerSettingsStore
      .loadCustomFontFamily();
  final initialCustomFallbackFontFamilies = await managerSettingsStore
      .loadCustomFallbackFontFamilies();
  final initialSnapshots = await snapshotStore.load(
    PackageManagerRegistry.defaultAdapters
        .map((adapter) => adapter.definition)
        .toList(growable: false),
  );
  final controller = PackagePanelController(
    shell: const ShellExecutor(),
    adapters: PackageManagerRegistry.defaultAdapters,
    latestInfoStore: latestInfoStore,
    settingsStore: managerSettingsStore,
    snapshotStore: snapshotStore,
    initialLatestInfo: initialLatestInfo,
    initialSnapshots: initialSnapshots,
    initialVisibleManagerIds: initialVisibleManagerIds,
    initialHomeFilterGroups: initialHomeFilterGroups,
    initialManagerOrderIds: initialManagerOrderIds,
    initialCustomManagerIconPaths: initialCustomManagerIconPaths,
    initialCustomManagerDisplayNames: initialCustomManagerDisplayNames,
    initialThemeMode: switch (initialThemeModeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    initialAutoCheckAppUpdates: initialAutoCheckAppUpdates,
    initialUseGithubMirrorForDownloads: initialUseGithubMirrorForDownloads,
    initialGithubMirrorBaseUrl: initialGithubMirrorBaseUrl,
    initialCustomFontFamily: initialCustomFontFamily,
    initialCustomFallbackFontFamilies: initialCustomFallbackFontFamilies,
  );

  runPkgPanel(controller);
}
