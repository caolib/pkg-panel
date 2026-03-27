import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkg_panel/src/app.dart';
import 'package:pkg_panel/src/models/package_models.dart';
import 'package:pkg_panel/src/services/package_adapters.dart';
import 'package:pkg_panel/src/services/package_manager_settings_store.dart';
import 'package:pkg_panel/src/services/package_panel_controller.dart';
import 'package:pkg_panel/src/services/package_snapshot_store.dart';
import 'package:pkg_panel/src/services/shell_executor.dart';
import 'package:pkg_panel/src/services/winget_package_icon_resolver.dart';

void main() {
  testWidgets('renders seeded package data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = PackagePanelController(
      shell: const ShellExecutor(),
      adapters: PackageManagerRegistry.defaultAdapters,
      initialVisibleManagerIds: const <String>{'npm'},
      initialManagerAvailability: const <String, bool>{'npm': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: PackageManagerRegistry.defaultAdapters
              .firstWhere((adapter) => adapter.definition.id == 'npm')
              .definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: 'eslint',
              managerId: 'npm',
              managerName: 'npm',
              version: '9.0.0',
              latestVersion: '9.1.0',
              source: 'global',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('eslint'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('批量更新'), findsNothing);
    expect(find.text('操作'), findsNothing);
    expect(find.text('检查更新'), findsNothing);
    expect(find.text('升级'), findsNothing);
    expect(find.text('删除'), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('eslint')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('升级'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('opens dedicated settings page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = PackagePanelController(
      shell: const ShellExecutor(),
      adapters: PackageManagerRegistry.defaultAdapters,
      initialVisibleManagerIds: const <String>{'npm', 'choco'},
      initialManagerAvailability: const <String, bool>{
        'npm': true,
        'choco': false,
      },
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: PackageManagerRegistry.defaultAdapters
              .firstWhere((adapter) => adapter.definition.id == 'npm')
              .definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[],
        ),
      ],
    );

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('包管理器'), findsWidgets);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('npm'), findsWidgets);
    expect(find.text('choco'), findsWidgets);
  });

  test('winget parser skips localized header rows', () async {
    final shell = _FakeShellExecutor(
      const ShellResult(
        exitCode: 0,
        stdout: '''
已连接到 Windows 程序包管理器源
--------------------------------
名称                     ID                                  版本            可用       源
----------------------------------------------------------------------------
MuMu模拟器               ARP\\Machine\\X64\\MuMuPlayer       5.22.0.3094     可用       winget
''',
        stderr: '',
      ),
    );

    final packages = await const WingetAdapter().listPackages(shell);

    expect(packages, hasLength(1));
    expect(packages.single.name, 'MuMu模拟器');
    expect(packages.single.version, '5.22.0.3094');
    expect(packages.single.latestVersion, '可用');
  });

  test('choco parser reads local packages from limit-output', () async {
    final shell = _FakeShellExecutor(
      const ShellResult(
        exitCode: 0,
        stdout: '''
Chocolatey v2.3.0
git|2.48.1
nodejs|22.14.0
2 packages installed.
''',
        stderr: '',
      ),
    );

    final packages = await const ChocolateyAdapter().listPackages(shell);

    expect(packages, hasLength(2));
    expect(packages[0].name, 'git');
    expect(packages[0].version, '2.48.1');
    expect(packages[1].name, 'nodejs');
    expect(packages[1].version, '22.14.0');
  });

  test('choco latest version lookup parses exact search result', () async {
    final shell = _FakeShellExecutor(
      const ShellResult(
        exitCode: 0,
        stdout: '''
Chocolatey v2.3.0
git|2.49.0
1 packages found.
''',
        stderr: '',
      ),
    );

    final version = await const ChocolateyAdapter().lookupLatestVersion(
      shell,
      const ManagedPackage(
        name: 'git',
        managerId: 'choco',
        managerName: 'choco',
        version: '2.48.1',
      ),
    );

    expect(version, '2.49.0');
  });

  test('first initialization only enables detected managers', () async {
    final controller = PackagePanelController(
      shell: _MappedShellExecutor(<Pattern, ShellResult>{
        RegExp(r"Get-Command 'npm'", caseSensitive: false): const ShellResult(
          exitCode: 0,
          stdout: '1',
          stderr: '',
        ),
        RegExp(r"Get-Command 'pip'", caseSensitive: false): const ShellResult(
          exitCode: 0,
          stdout: '1',
          stderr: '',
        ),
        RegExp(r"Get-Command '", caseSensitive: false): const ShellResult(
          exitCode: 0,
          stdout: '0',
          stderr: '',
        ),
        'npm ls -g --depth=0 --json': const ShellResult(
          exitCode: 0,
          stdout: '{"dependencies":{"eslint":{"version":"9.0.0"}}}',
          stderr: '',
        ),
        'pip list --format=json': const ShellResult(
          exitCode: 0,
          stdout: '[{"name":"ruff","version":"0.5.0"}]',
          stderr: '',
        ),
      }),
      adapters: PackageManagerRegistry.defaultAdapters,
      settingsStore: const _MemorySettingsStore(),
    );

    await controller.ensureLoaded();

    expect(
      controller.managerVisibilityStates
          .firstWhere((s) => s.manager.id == 'npm')
          .isVisible,
      isTrue,
    );
    expect(
      controller.managerVisibilityStates
          .firstWhere((s) => s.manager.id == 'pip')
          .isVisible,
      isTrue,
    );
    expect(
      controller.managerVisibilityStates
          .firstWhere((s) => s.manager.id == 'winget')
          .isVisible,
      isFalse,
    );
    expect(
      controller.visibleSnapshots.map((snapshot) => snapshot.manager.id),
      containsAll(<String>['npm', 'pip']),
    );
    expect(
      controller.visibleSnapshots.map((snapshot) => snapshot.manager.id),
      isNot(contains('winget')),
    );
  });

  test('winget packages can use resolved app icon path', () async {
    final controller = PackagePanelController(
      shell: _MappedShellExecutor(<Pattern, ShellResult>{
        RegExp(r"Get-Command 'winget'", caseSensitive: false):
            const ShellResult(exitCode: 0, stdout: '1', stderr: ''),
        RegExp(r"Get-Command '", caseSensitive: false): const ShellResult(
          exitCode: 0,
          stdout: '0',
          stderr: '',
        ),
        'winget list --disable-interactivity': const ShellResult(
          exitCode: 0,
          stdout: '''
Name                           Id                               Version     Available Source
--------------------------------------------------------------------------------------------
Microsoft Visual Studio Code   Microsoft.VisualStudioCode       1.99.0      1.100.0   winget
''',
          stderr: '',
        ),
      }),
      adapters: PackageManagerRegistry.defaultAdapters,
      settingsStore: const _MemorySettingsStore(),
      wingetIconResolver: const _FakeWingetIconResolver(r'C:\icons\vscode.ico'),
    );

    await controller.ensureLoaded();

    final package = controller.visiblePackages.single;
    expect(package.name, 'Microsoft Visual Studio Code');
    expect(controller.packageIconPath(package), r'C:\icons\vscode.ico');
  });

  test('cached snapshots stay visible while background refresh runs', () async {
    final shell = _DelayedShellExecutor(
      <Pattern, ShellResult>{
        RegExp(r"Get-Command 'npm'", caseSensitive: false): const ShellResult(
          exitCode: 0,
          stdout: '1',
          stderr: '',
        ),
        RegExp(r"Get-Command '", caseSensitive: false): const ShellResult(
          exitCode: 0,
          stdout: '0',
          stderr: '',
        ),
      },
      delayedCommand: 'npm ls -g --depth=0 --json',
      delayedResult: const ShellResult(
        exitCode: 0,
        stdout: '{"dependencies":{"prettier":{"version":"3.5.0"}}}',
        stderr: '',
      ),
    );
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      settingsStore: const _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'npm'},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: PackageManagerRegistry.defaultAdapters
              .firstWhere((adapter) => adapter.definition.id == 'npm')
              .definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: 'eslint',
              managerId: 'npm',
              managerName: 'npm',
              version: '9.0.0',
            ),
          ],
        ),
      ],
    );

    await controller.ensureLoaded();
    expect(controller.visiblePackages.single.name, 'eslint');

    shell.completeDelayed();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.visiblePackages.single.name, 'prettier');
  });

  test('manager reorder changes visible order', () async {
    final controller = PackagePanelController(
      shell: const ShellExecutor(),
      adapters: PackageManagerRegistry.defaultAdapters,
      settingsStore: const _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'npm', 'pip'},
      initialManagerOrderIds: const <String>['npm', 'pip'],
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: PackageManagerRegistry.defaultAdapters
              .firstWhere((adapter) => adapter.definition.id == 'npm')
              .definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[],
        ),
        ManagerSnapshot(
          manager: PackageManagerRegistry.defaultAdapters
              .firstWhere((adapter) => adapter.definition.id == 'pip')
              .definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[],
        ),
      ],
    );

    expect(
      controller.visibleSnapshots.map((e) => e.manager.id).toList(),
      <String>['npm', 'pip'],
    );

    await controller.reorderManager(0, 1);

    expect(
      controller.visibleSnapshots.map((e) => e.manager.id).toList(),
      <String>['pip', 'npm'],
    );
    expect(
      controller.managerVisibilityStates
          .take(2)
          .map((e) => e.manager.id)
          .toList(),
      <String>['pip', 'npm'],
    );
  });
}

class _FakeShellExecutor extends ShellExecutor {
  const _FakeShellExecutor(this.result);

  final ShellResult result;

  @override
  Future<ShellResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return result;
  }
}

class _MappedShellExecutor extends ShellExecutor {
  const _MappedShellExecutor(this.results);

  final Map<Pattern, ShellResult> results;

  @override
  Future<ShellResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    for (final entry in results.entries) {
      final pattern = entry.key;
      if (pattern is String && command == pattern) {
        return entry.value;
      }
      if (pattern is RegExp && pattern.hasMatch(command)) {
        return entry.value;
      }
    }

    return ShellResult(
      exitCode: 1,
      stdout: '',
      stderr: 'Unexpected command: $command',
    );
  }
}

class _MemorySettingsStore extends PackageManagerSettingsStore {
  const _MemorySettingsStore();

  @override
  Future<Set<String>?> loadVisibleManagerIds() async => null;

  @override
  Future<void> saveVisibleManagerIds(Set<String> managerIds) async {}

  @override
  Future<List<String>> loadManagerOrderIds() async => const <String>[];

  @override
  Future<void> saveManagerOrderIds(List<String> managerIds) async {}

  @override
  Future<Map<String, String>> loadCustomManagerIconPaths() async {
    return const <String, String>{};
  }

  @override
  Future<void> saveCustomManagerIconPaths(
    Map<String, String> iconPaths,
  ) async {}

  @override
  Future<Map<String, String>> loadCustomManagerDisplayNames() async {
    return const <String, String>{};
  }

  @override
  Future<void> saveCustomManagerDisplayNames(
    Map<String, String> displayNames,
  ) async {}
}

class _MemorySnapshotStore extends PackageSnapshotStore {
  const _MemorySnapshotStore();

  @override
  Future<List<ManagerSnapshot>> load(
    List<PackageManagerDefinition> managers,
  ) async {
    return const <ManagerSnapshot>[];
  }

  @override
  Future<void> save(List<ManagerSnapshot> snapshots) async {}
}

class _FakeWingetIconResolver extends WingetPackageIconResolver {
  const _FakeWingetIconResolver(this.iconPath);

  final String iconPath;

  @override
  Future<Map<String, String>> resolveIconPaths(
    ShellExecutor shell,
    List<ManagedPackage> packages,
  ) async {
    if (packages.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{packages.first.key: iconPath};
  }
}

class _DelayedShellExecutor extends ShellExecutor {
  _DelayedShellExecutor(
    this.results, {
    required this.delayedCommand,
    required this.delayedResult,
  });

  final Map<Pattern, ShellResult> results;
  final String delayedCommand;
  final ShellResult delayedResult;
  final Completer<void> _completer = Completer<void>();

  void completeDelayed() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<ShellResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (command == delayedCommand) {
      await _completer.future;
      return delayedResult;
    }

    for (final entry in results.entries) {
      final pattern = entry.key;
      if (pattern is String && command == pattern) {
        return entry.value;
      }
      if (pattern is RegExp && pattern.hasMatch(command)) {
        return entry.value;
      }
    }

    return ShellResult(
      exitCode: 1,
      stdout: '',
      stderr: 'Unexpected command: $command',
    );
  }
}
