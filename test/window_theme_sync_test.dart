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

    expect(sync.themeModes, <ThemeMode>[ThemeMode.dark]);

    await controller.setThemeMode(ThemeMode.light);
    await tester.pump();

    await controller.setThemeMode(ThemeMode.system);
    await tester.pump();

    expect(
      sync.themeModes,
      <ThemeMode>[ThemeMode.dark, ThemeMode.light, ThemeMode.system],
    );
  });
}

class _RecordingWindowThemeSync implements WindowThemeSync {
  final List<ThemeMode> themeModes = <ThemeMode>[];

  @override
  Future<void> sync(ThemeMode themeMode) async {
    themeModes.add(themeMode);
  }
}

class _MemorySettingsStore extends PackageManagerSettingsStore {
  const _MemorySettingsStore();

  @override
  Future<void> saveThemeModeName(String themeMode) async {}
}
