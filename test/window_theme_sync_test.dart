import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkg_panel/src/app.dart';
import 'package:pkg_panel/src/services/package_adapters.dart';
import 'package:pkg_panel/src/services/package_manager_settings_store.dart';
import 'package:pkg_panel/src/services/package_panel_controller.dart';
import 'package:pkg_panel/src/services/shell_executor.dart';
import 'package:pkg_panel/src/services/window_theme_sync.dart';

void main() {
  testWidgets('syncs window theme mode when the app theme changes', (
    tester,
  ) async {
    final sync = _RecordingWindowThemeSync();
    final expectedDarkBackground = Color.alphaBlend(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F766E),
        brightness: Brightness.dark,
      ).primary.withAlpha(18),
      const Color(0xFF18181B),
    );
    final controller = PackagePanelController(
      shell: const ShellExecutor(),
      adapters: PackageManagerRegistry.defaultAdapters,
      settingsStore: const _MemorySettingsStore(),
      initialThemeMode: ThemeMode.dark,
    );

    await tester.pumpWidget(
      PkgPanelApp(
        controller: controller,
        autoLoad: false,
        windowThemeSync: sync,
      ),
    );
    await tester.pump();

    expect(sync.configs.map((config) => config.themeMode), <ThemeMode>[
      ThemeMode.dark,
    ]);

    await controller.setThemeMode(ThemeMode.light);
    await tester.pump();

    await controller.setThemeMode(ThemeMode.system);
    await tester.pump();

    expect(
      sync.configs.map((config) => config.themeMode),
      <ThemeMode>[ThemeMode.dark, ThemeMode.light, ThemeMode.system],
    );
    expect(sync.configs.first.darkBackgroundColor, expectedDarkBackground);
  });
}

class _RecordingWindowThemeSync implements WindowThemeSync {
  final List<_RecordedWindowThemeConfig> configs =
      <_RecordedWindowThemeConfig>[];

  @override
  Future<void> sync({
    required ThemeMode themeMode,
    required Color lightBackgroundColor,
    required Color darkBackgroundColor,
    required Color lightForegroundColor,
    required Color darkForegroundColor,
  }) async {
    configs.add(
      _RecordedWindowThemeConfig(
        themeMode: themeMode,
        lightBackgroundColor: lightBackgroundColor,
        darkBackgroundColor: darkBackgroundColor,
        lightForegroundColor: lightForegroundColor,
        darkForegroundColor: darkForegroundColor,
      ),
    );
  }
}

class _RecordedWindowThemeConfig {
  const _RecordedWindowThemeConfig({
    required this.themeMode,
    required this.lightBackgroundColor,
    required this.darkBackgroundColor,
    required this.lightForegroundColor,
    required this.darkForegroundColor,
  });

  final ThemeMode themeMode;
  final Color lightBackgroundColor;
  final Color darkBackgroundColor;
  final Color lightForegroundColor;
  final Color darkForegroundColor;
}

class _MemorySettingsStore extends PackageManagerSettingsStore {
  const _MemorySettingsStore();

  @override
  Future<void> saveThemeModeName(String themeMode) async {}
}
