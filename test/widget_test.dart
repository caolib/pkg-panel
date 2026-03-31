import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkg_panel/src/app.dart';
import 'package:pkg_panel/src/models/package_models.dart';
import 'package:pkg_panel/src/services/package_adapters.dart';
import 'package:pkg_panel/src/services/package_latest_info_store.dart';
import 'package:pkg_panel/src/services/package_manager_settings_store.dart';
import 'package:pkg_panel/src/services/package_panel_controller.dart';
import 'package:pkg_panel/src/services/package_snapshot_store.dart';
import 'package:pkg_panel/src/services/shell_executor.dart';
import 'package:pkg_panel/src/services/winget_package_icon_resolver.dart';
import 'package:pkg_panel/src/widgets/linkified_selectable_text.dart';

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
      tester.getCenter(find.text('eslint').last),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('升级'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets(
    'pip manager hides batch check button but keeps single-package lookup',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: PackageManagerRegistry.defaultAdapters,
        initialVisibleManagerIds: const <String>{'pip'},
        initialManagerAvailability: const <String, bool>{'pip': true},
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: PackageManagerRegistry.defaultAdapters
                .firstWhere((adapter) => adapter.definition.id == 'pip')
                .definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'ruff',
                managerId: 'pip',
                managerName: 'pip',
                version: '0.8.6',
              ),
            ],
          ),
        ],
      );
      controller.selectManager('pip');

      await tester.pumpWidget(
        PkgPanelApp(controller: controller, autoLoad: false),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, '检查更新'), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('ruff').last),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('检查更新'), findsOneWidget);
    },
  );

  testWidgets('linkified selectable text opens detected links', (tester) async {
    String? openedUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkifiedSelectableText(
            text: 'https://github.com/caolib/pkg-panel',
            onOpenLink: (url) async {
              openedUrl = url;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SelectableText));
    await tester.pump();

    expect(openedUrl, 'https://github.com/caolib/pkg-panel');
  });

  test('refresh current selection only reloads selected manager', () async {
    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      'npm ls -g --depth=0 --json': const ShellResult(
        exitCode: 0,
        stdout: '{"dependencies":{"eslint":{"version":"9.1.0"}}}',
        stderr: '',
      ),
      'pip list --format=json': const ShellResult(
        exitCode: 0,
        stdout: '[{"name":"ruff","version":"0.8.6"}]',
        stderr: '',
      ),
    });
    final npmAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
      (adapter) => adapter.definition.id == 'npm',
    );
    final pipAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
      (adapter) => adapter.definition.id == 'pip',
    );
    final controller = PackagePanelController(
      shell: shell,
      adapters: <PackageManagerAdapter>[npmAdapter, pipAdapter],
      latestInfoStore: const _MemoryLatestInfoStore(),
      settingsStore: const _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'npm', 'pip'},
      initialManagerAvailability: const <String, bool>{
        'npm': true,
        'pip': true,
      },
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: npmAdapter.definition,
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
        ManagerSnapshot(
          manager: pipAdapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: 'ruff',
              managerId: 'pip',
              managerName: 'pip',
              version: '0.8.5',
            ),
          ],
        ),
      ],
    );

    controller.selectManager('npm');
    await controller.refreshCurrentSelection();

    expect(
      shell.commands.where(
        (command) => command == 'npm ls -g --depth=0 --json',
      ),
      hasLength(1),
    );
    expect(
      shell.commands.where((command) => command == 'pip list --format=json'),
      isEmpty,
    );
  });

  test(
    'update filter shows only packages with updates and survives realignment',
    () async {
      final npmAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'npm',
      );
      final pipAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'pip',
      );
      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: <PackageManagerAdapter>[npmAdapter, pipAdapter],
        latestInfoStore: const _MemoryLatestInfoStore(),
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm', 'pip'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pip': true,
        },
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: npmAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'eslint',
                managerId: 'npm',
                managerName: 'npm',
                version: '9.0.0',
                latestVersion: '9.1.0',
              ),
            ],
          ),
          ManagerSnapshot(
            manager: pipAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'ruff',
                managerId: 'pip',
                managerName: 'pip',
                version: '0.8.6',
              ),
            ],
          ),
        ],
      );

      controller.selectManager(updateFilterId);

      expect(controller.selectedManagerId, updateFilterId);
      expect(
        controller.visiblePackages.map((package) => package.name).toList(),
        <String>['eslint'],
      );

      await controller.setManagerVisibility('pip', false);

      expect(controller.selectedManagerId, updateFilterId);
      expect(
        controller.visiblePackages.map((package) => package.name).toList(),
        <String>['eslint'],
      );
    },
  );

  test(
    'custom home filter group combines manager and package membership',
    () async {
      final npmAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'npm',
      );
      final pipAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'pip',
      );
      final pipPackage = ManagedPackage(
        name: 'ruff',
        managerId: 'pip',
        managerName: 'pip',
        version: '0.8.6',
      );
      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: <PackageManagerAdapter>[npmAdapter, pipAdapter],
        latestInfoStore: const _MemoryLatestInfoStore(),
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm', 'pip'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pip': true,
        },
        initialHomeFilterGroups: <HomeFilterGroup>[
          HomeFilterGroup(
            id: 'dev_tools',
            kind: HomeFilterGroupKind.custom,
            displayName: '开发工具',
            managerIds: <String>['npm'],
            packageKeys: <String>[pipPackage.key],
          ),
        ],
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: npmAdapter.definition,
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
          ManagerSnapshot(
            manager: pipAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: <ManagedPackage>[pipPackage],
          ),
        ],
      );

      controller.selectManager('dev_tools');

      expect(
        controller.visiblePackages.map((package) => package.name).toList(),
        <String>['eslint', 'ruff'],
      );
    },
  );

  test(
    'custom home filter group loads packages from hidden managers',
    () async {
      final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
        'npm ls -g --depth=0 --json': const ShellResult(
          exitCode: 0,
          stdout: '{"dependencies":{"eslint":{"version":"9.1.0"}}}',
          stderr: '',
        ),
        'pip list --format=json': const ShellResult(
          exitCode: 0,
          stdout: '[{"name":"ruff","version":"0.8.6"}]',
          stderr: '',
        ),
      });
      final npmAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'npm',
      );
      final pipAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'pip',
      );
      final controller = PackagePanelController(
        shell: shell,
        adapters: <PackageManagerAdapter>[npmAdapter, pipAdapter],
        latestInfoStore: const _MemoryLatestInfoStore(),
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pip': true,
        },
        initialHomeFilterGroups: const <HomeFilterGroup>[
          HomeFilterGroup(
            id: 'dev_tools',
            kind: HomeFilterGroupKind.custom,
            displayName: '开发工具',
            managerIds: <String>['npm', 'pip'],
          ),
        ],
      );

      await controller.ensureLoaded();
      controller.selectManager('dev_tools');

      expect(
        controller.visiblePackages.map((package) => package.name).toList(),
        <String>['eslint', 'ruff'],
      );
    },
  );

  test(
    'refresh current selection reloads all managers for update filter',
    () async {
      final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
        'npm ls -g --depth=0 --json': const ShellResult(
          exitCode: 0,
          stdout: '{"dependencies":{"eslint":{"version":"9.1.0"}}}',
          stderr: '',
        ),
        'pip list --format=json': const ShellResult(
          exitCode: 0,
          stdout: '[{"name":"ruff","version":"0.8.6"}]',
          stderr: '',
        ),
      });
      final npmAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'npm',
      );
      final pipAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'pip',
      );
      final controller = PackagePanelController(
        shell: shell,
        adapters: <PackageManagerAdapter>[npmAdapter, pipAdapter],
        latestInfoStore: const _MemoryLatestInfoStore(),
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm', 'pip'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pip': true,
        },
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: npmAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'eslint',
                managerId: 'npm',
                managerName: 'npm',
                version: '9.0.0',
                latestVersion: '9.1.0',
              ),
            ],
          ),
          ManagerSnapshot(
            manager: pipAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'ruff',
                managerId: 'pip',
                managerName: 'pip',
                version: '0.8.5',
              ),
            ],
          ),
        ],
      );

      controller.selectManager(updateFilterId);
      await controller.refreshCurrentSelection();

      expect(
        shell.commands.where(
          (command) => command == 'npm ls -g --depth=0 --json',
        ),
        hasLength(1),
      );
      expect(
        shell.commands.where((command) => command == 'pip list --format=json'),
        hasLength(1),
      );
    },
  );

  test(
    'shell executor refreshes Windows PATH for command resolution and child processes',
    () async {
      if (!Platform.isWindows) {
        return;
      }

      final toolDir = await Directory.systemTemp.createTemp('pkg_panel_tool_');
      final runtimeDir = await Directory.systemTemp.createTemp(
        'pkg_panel_runtime_',
      );
      addTearDown(() async {
        if (await toolDir.exists()) {
          await toolDir.delete(recursive: true);
        }
        if (await runtimeDir.exists()) {
          await runtimeDir.delete(recursive: true);
        }
      });

      final pnpmScript = File(
        '${toolDir.path}${Platform.pathSeparator}pnpm.cmd',
      );
      await pnpmScript.writeAsString(
        '@echo off\r\n'
        'node >nul 2>nul\r\n'
        'if errorlevel 1 (\r\n'
        '  echo node missing\r\n'
        '  exit /b 1\r\n'
        ')\r\n'
        'echo ok\r\n',
      );

      final nodeScript = File(
        '${runtimeDir.path}${Platform.pathSeparator}node.cmd',
      );
      await nodeScript.writeAsString('@echo off\r\nexit /b 0\r\n');

      final shell = ShellExecutor(
        processEnvironment: <String, String>{
          'PATH': toolDir.path,
          'PATHEXT': '.CMD;.EXE',
          'SystemRoot': Platform.environment['SystemRoot'] ?? r'C:\Windows',
        },
        windowsEnvironmentProvider: () async => <String, String>{
          'PATH': '${toolDir.path};${runtimeDir.path}',
          'PATHEXT': '.CMD;.EXE',
        },
      );

      final result = await shell.runExecutable('pnpm', const <String>[]);

      expect(result.isSuccess, isTrue);
      expect(result.stdout.trim(), 'ok');
    },
  );

  test(
    'missing cached manager snapshots are synthesized for registered adapters',
    () async {
      final npmAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'npm',
      );
      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: PackageManagerRegistry.defaultAdapters,
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm', 'yarn'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'yarn': true,
        },
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: npmAdapter.definition,
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

      expect(
        controller.snapshots.map((snapshot) => snapshot.manager.id),
        contains('yarn'),
      );

      await controller.setManagerVisibility('yarn', false);

      expect(controller.isManagerVisible('yarn'), isFalse);
    },
  );

  test(
    'refreshing manager availability disables missing visible managers',
    () async {
      final npmAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'npm',
      );
      final pipAdapter = PackageManagerRegistry.defaultAdapters.firstWhere(
        (adapter) => adapter.definition.id == 'pip',
      );
      final settingsStore = _PersistingVisibilitySettingsStore(
        visibleManagerIds: const <String>{'npm', 'pip'},
      );
      final controller = PackagePanelController(
        shell: const _ExecutableAvailabilityShellExecutor(<String, bool>{
          'npm': true,
          'python': false,
        }),
        adapters: <PackageManagerAdapter>[npmAdapter, pipAdapter],
        settingsStore: settingsStore,
        latestInfoStore: const _MemoryLatestInfoStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm', 'pip'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pip': true,
        },
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: npmAdapter.definition,
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
          ManagerSnapshot(
            manager: pipAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'ruff',
                managerId: 'pip',
                managerName: 'pip',
                version: '0.8.6',
              ),
            ],
          ),
        ],
      );

      await controller.refreshManagerAvailability();

      expect(controller.isManagerAvailable('npm'), isTrue);
      expect(controller.isManagerAvailable('pip'), isFalse);
      expect(controller.isManagerVisible('npm'), isTrue);
      expect(controller.isManagerVisible('pip'), isFalse);
      expect(settingsStore.visibleManagerIds, <String>{'npm'});

      final pipSnapshot = controller.snapshots.firstWhere(
        (snapshot) => snapshot.manager.id == 'pip',
      );
      expect(pipSnapshot.loadState, ManagerLoadState.idle);
      expect(pipSnapshot.packages, isEmpty);
    },
  );

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
    expect(find.widgetWithText(FilledButton, '添加组'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '刷新状态'), findsOneWidget);
    expect(find.text('重命名'), findsNothing);
    expect(find.text('自定义图标'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '编辑'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, '编辑').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('编辑 '), findsOneWidget);
    expect(find.text('选择图标'), findsOneWidget);
  });

  testWidgets(
    'manager filter bar includes updates chip and filters package list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: PackageManagerRegistry.defaultAdapters,
        initialVisibleManagerIds: const <String>{'npm', 'pip'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pip': true,
        },
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
              ),
            ],
          ),
          ManagerSnapshot(
            manager: PackageManagerRegistry.defaultAdapters
                .firstWhere((adapter) => adapter.definition.id == 'pip')
                .definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'ruff',
                managerId: 'pip',
                managerName: 'pip',
                version: '0.8.6',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        PkgPanelApp(controller: controller, autoLoad: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('更新'), findsOneWidget);
      expect(find.text('eslint'), findsOneWidget);
      expect(find.text('ruff'), findsOneWidget);

      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();

      expect(controller.selectedManagerId, updateFilterId);
      expect(find.text('eslint'), findsOneWidget);
      expect(find.text('ruff'), findsNothing);
    },
  );

  testWidgets('install page uses a single menu item and defaults npm to latest', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      "npm search 'eslint' --json --searchlimit=20": const ShellResult(
        exitCode: 0,
        stdout:
            '[{"name":"eslint","version":"9.0.0","description":"Lint tool","publisher":{"username":"npm"}}]',
        stderr: '',
      ),
      "npm install -g 'eslint@latest'": const ShellResult(
        exitCode: 0,
        stdout: 'installed latest',
        stderr: '',
      ),
      'npm ls -g --depth=0 --json': const ShellResult(
        exitCode: 0,
        stdout: '{"dependencies":{"eslint":{"version":"9.1.1"}}}',
        stderr: '',
      ),
      RegExp(r"Get-Command '", caseSensitive: false): const ShellResult(
        exitCode: 0,
        stdout: '0',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      initialManagerAvailability: const <String, bool>{'npm': true},
    );

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('安装'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'eslint');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('eslint').last),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('使用 npm 安装'), findsOneWidget);
    expect(find.text('使用 npm 安装特定版本'), findsNothing);

    await tester.tap(find.text('使用 npm 安装'));
    await tester.pumpAndSettle();

    expect(find.text('使用 npm 安装'), findsOneWidget);
    expect(find.text('安装最新'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(find.text('将要执行的命令'), findsOneWidget);
    expect(
      find.textContaining("npm install -g 'eslint@latest'"),
      findsOneWidget,
    );

    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('确认执行命令'), findsNothing);
    expect(shell.commands, contains("npm install -g 'eslint@latest'"));
  });

  testWidgets('install page shows winget when it is searchable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = PackagePanelController(
      shell: const ShellExecutor(),
      adapters: PackageManagerRegistry.defaultAdapters,
      initialManagerAvailability: const <String, bool>{'winget': true},
    );

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('安装'));
    await tester.pumpAndSettle();

    expect(find.text('winget'), findsOneWidget);
  });

  testWidgets('install options dialog loads versions in the same panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      "npm search 'eslint' --json --searchlimit=20": const ShellResult(
        exitCode: 0,
        stdout:
            '[{"name":"eslint","version":"9.0.0","description":"Lint tool","publisher":{"username":"npm"}}]',
        stderr: '',
      ),
      "npm view 'eslint' versions --json": const ShellResult(
        exitCode: 0,
        stdout: '["9.0.0","9.1.0","9.1.1"]',
        stderr: '',
      ),
      RegExp(r"Get-Command '", caseSensitive: false): const ShellResult(
        exitCode: 0,
        stdout: '0',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      initialManagerAvailability: const <String, bool>{'npm': true},
    );

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('安装'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'eslint');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('eslint').last),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('使用 npm 安装'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('安装特定版本'));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(AlertDialog);
    expect(shell.commands, contains("npm view 'eslint' versions --json"));
    expect(
      find.descendant(of: dialogFinder, matching: find.text('9.1.1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogFinder, matching: find.text('9.1.0')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialogFinder,
        matching: find.widgetWithText(ListTile, '9.0.0'),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets('installed search result keeps version-install menu enabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      "pnpm search 'eslint' --json --searchlimit=20": const ShellResult(
        exitCode: 0,
        stdout:
            '[{"name":"eslint","version":"9.0.0","description":"Lint tool","publisher":{"username":"npm"}}]',
        stderr: '',
      ),
      "pnpm view 'eslint' versions --json": const ShellResult(
        exitCode: 0,
        stdout: '["9.0.0","9.1.0","9.1.1"]',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      initialManagerAvailability: const <String, bool>{'pnpm': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: PackageManagerRegistry.defaultAdapters
              .firstWhere((adapter) => adapter.definition.id == 'pnpm')
              .definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: 'eslint',
              managerId: 'pnpm',
              managerName: 'pnpm',
              version: '9.1.1',
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

    await tester.tap(find.text('安装'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilterChip).at(1));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'eslint');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('eslint').last),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('pnpm 已安装'), findsNothing);
    expect(find.text('使用 pnpm 安装特定版本'), findsOneWidget);

    await tester.tap(find.text('使用 pnpm 安装特定版本'));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(AlertDialog);
    expect(
      shell.commands,
      contains("pnpm search 'eslint' --json --searchlimit=20"),
    );
    expect(shell.commands, contains("pnpm view 'eslint' versions --json"));
    expect(
      find.descendant(of: dialogFinder, matching: find.byType(TextField)),
      findsOneWidget,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets(
    'node install filter shows npm label with multiple manager icons',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: PackageManagerRegistry.defaultAdapters,
        initialVisibleManagerIds: const <String>{'npm', 'pnpm', 'bun'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pnpm': true,
          'yarn': true,
          'bun': true,
        },
      );

      await tester.pumpWidget(
        PkgPanelApp(controller: controller, autoLoad: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('安装'));
      await tester.pumpAndSettle();

      expect(find.text('npm'), findsOneWidget);
      expect(find.text('npm/pnpm/bun'), findsNothing);
      expect(find.text('npm/pnpm/yarn/bun'), findsNothing);
    },
  );

  testWidgets(
    'node install filter shows name when only one manager is enabled',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: PackageManagerRegistry.defaultAdapters,
        initialVisibleManagerIds: const <String>{'npm'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pnpm': true,
          'yarn': true,
          'bun': true,
        },
      );

      await tester.pumpWidget(
        PkgPanelApp(controller: controller, autoLoad: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('安装'));
      await tester.pumpAndSettle();

      expect(find.text('npm'), findsOneWidget);
      expect(find.text('npm/pnpm'), findsNothing);
    },
  );

  test(
    'node ecosystem search uses one provider and expands install options',
    () async {
      final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
        "npm search 'eslint' --json --searchlimit=20": const ShellResult(
          exitCode: 0,
          stdout:
              '[{"name":"eslint","version":"9.0.0","description":"Lint tool","publisher":{"username":"npm"}}]',
          stderr: '',
        ),
      });
      final controller = PackagePanelController(
        shell: shell,
        adapters: PackageManagerRegistry.defaultAdapters,
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pnpm': true,
          'yarn': true,
          'bun': true,
        },
      );

      await controller.searchPackages(query: 'eslint');
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
        if (!controller.isSearchingPackages) {
          break;
        }
      }

      expect(
        shell.commands.where(
          (command) => command == "npm search 'eslint' --json --searchlimit=20",
        ),
        hasLength(1),
      );
      expect(
        shell.commands.where(
          (command) => command.startsWith("pnpm search 'eslint'"),
        ),
        isEmpty,
      );
      expect(
        shell.commands.where(
          (command) => command.startsWith("bun search 'eslint'"),
        ),
        isEmpty,
      );

      final result = controller.searchResults.single;
      expect(result.name, 'eslint');
      expect(
        result.installOptions.map((option) => option.managerId).toList(),
        <String>['npm', 'pnpm', 'yarn', 'bun'],
      );
    },
  );

  test(
    'yarn list packages reads dependencies from global dir manifest',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('pkg-panel-yarn-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final globalDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}global',
      );
      final scopedPackageDir = Directory(
        '${globalDir.path}${Platform.pathSeparator}node_modules'
        '${Platform.pathSeparator}@scope${Platform.pathSeparator}demo',
      );
      await scopedPackageDir.create(recursive: true);
      await File(
        '${globalDir.path}${Platform.pathSeparator}package.json',
      ).writeAsString(
        jsonEncode(<String, Object>{
          'dependencies': <String, String>{'@scope/demo': '^1.2.3'},
        }),
      );
      await File(
        '${scopedPackageDir.path}${Platform.pathSeparator}package.json',
      ).writeAsString(
        jsonEncode(<String, Object>{
          'name': '@scope/demo',
          'version': '1.2.3',
          'bin': <String, String>{'demo': 'bin/demo.js'},
        }),
      );

      final packages = await const YarnAdapter().listPackages(
        _MappedShellExecutor(<Pattern, ShellResult>{
          'yarn global dir': ShellResult(
            exitCode: 0,
            stdout: globalDir.path,
            stderr: '',
          ),
        }),
      );

      expect(packages, hasLength(1));
      expect(packages.single.name, '@scope/demo');
      expect(packages.single.version, '1.2.3');
      expect(packages.single.executables, <String>['demo']);
      expect(packages.single.managerId, 'yarn');
    },
  );

  testWidgets('local package menu installs a selected npm version', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = PackagePanelController(
      shell: _MappedShellExecutor(<Pattern, ShellResult>{
        "npm view 'eslint' versions --json": const ShellResult(
          exitCode: 0,
          stdout: '["9.0.0","9.1.0","9.1.1"]',
          stderr: '',
        ),
      }),
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
              version: '9.1.1',
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

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('eslint')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('安装特定版本'), findsOneWidget);

    await tester.tap(find.text('安装特定版本'));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialogFinder, matching: find.text('9.1.1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogFinder, matching: find.text('9.1.0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogFinder, matching: find.text('9.0.0')),
      findsOneWidget,
    );

    await tester.enterText(
      find.descendant(of: dialogFinder, matching: find.byType(TextField)),
      '9.0',
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: dialogFinder, matching: find.text('9.0.0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogFinder, matching: find.text('9.1.1')),
      findsNothing,
    );

    await tester.tap(
      find.descendant(of: dialogFinder, matching: find.text('9.0.0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('确认执行命令'), findsOneWidget);
    expect(
      find.textContaining("npm install -g 'eslint@9.0.0'"),
      findsOneWidget,
    );
  });

  testWidgets(
    'specific-version dialog limits huge version lists until filtered',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final versionsJson = [
        for (var i = 1; i <= 250; i++) '"1.0.$i"',
      ].join(',');
      final controller = PackagePanelController(
        shell: _MappedShellExecutor(<Pattern, ShellResult>{
          "npm view 'opencode-ai' versions --json": ShellResult(
            exitCode: 0,
            stdout: '[$versionsJson]',
            stderr: '',
          ),
        }),
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
                name: 'opencode-ai',
                managerId: 'npm',
                managerName: 'npm',
                version: '1.0.250',
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

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('opencode-ai')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.text('安装特定版本'));
      await tester.pumpAndSettle();

      final dialogFinder = find.byType(AlertDialog);
      expect(find.textContaining('仅显示最新 200 个'), findsOneWidget);
      expect(
        find.descendant(
          of: dialogFinder,
          matching: find.widgetWithText(ListTile, '1.0.250'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialogFinder,
          matching: find.widgetWithText(ListTile, '1.0.50'),
        ),
        findsNothing,
      );

      await tester.enterText(
        find.descendant(of: dialogFinder, matching: find.byType(TextField)),
        '1.0.50',
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: dialogFinder,
          matching: find.widgetWithText(ListTile, '1.0.50'),
        ),
        findsOneWidget,
      );
    },
  );

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

  test(
    'controller only enables specific-version install on supported managers',
    () {
      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: PackageManagerRegistry.defaultAdapters,
      );

      expect(
        controller.canInstallSpecificVersion(
          const SearchPackageInstallOption(
            managerId: 'npm',
            managerName: 'npm',
            packageName: 'eslint',
          ),
        ),
        isTrue,
      );
      expect(
        controller.canInstallSpecificVersion(
          const SearchPackageInstallOption(
            managerId: 'cargo',
            managerName: 'cargo',
            packageName: 'cargo-edit',
          ),
        ),
        isFalse,
      );
      expect(
        controller.canInstallSpecificVersion(
          const SearchPackageInstallOption(
            managerId: 'scoop',
            managerName: 'scoop',
            packageName: 'git',
          ),
        ),
        isFalse,
      );
      expect(
        controller.canInstallLatestTag(
          const SearchPackageInstallOption(
            managerId: 'npm',
            managerName: 'npm',
            packageName: 'eslint',
          ),
        ),
        isTrue,
      );
      expect(
        controller.canInstallLatestTag(
          const SearchPackageInstallOption(
            managerId: 'winget',
            managerName: 'winget',
            packageName: 'Microsoft PowerToys',
          ),
        ),
        isFalse,
      );
    },
  );

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

  test('choco latest version lookup parses outdated output', () async {
    final shell = _FakeShellExecutor(
      const ShellResult(
        exitCode: 2,
        stdout: '''
Chocolatey v2.5.1
Outdated Packages
 Output is Id | Version | Available Version | Pinned

chocolatey|2.5.1|2.7.0|false
git|2.48.1|2.49.0|false

Chocolatey has determined 2 package(s) are outdated.
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

  test('controller batch latest check uses choco outdated once', () async {
    const adapter = ChocolateyAdapter();
    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      'choco outdated': const ShellResult(
        exitCode: 2,
        stdout: '''
Chocolatey v2.5.1
Outdated Packages
 Output is Id | Version | Available Version | Pinned

chocolatey|2.5.1|2.7.0|false
dart-sdk|3.9.4|3.11.4|false

Chocolatey has determined 2 package(s) are outdated.
''',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: <PackageManagerAdapter>[adapter],
      latestInfoStore: const _MemoryLatestInfoStore(),
      settingsStore: const _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'choco'},
      initialManagerAvailability: const <String, bool>{'choco': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: adapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: 'dart-sdk',
              managerId: 'choco',
              managerName: 'choco',
              version: '3.9.4',
            ),
            ManagedPackage(
              name: 'git',
              managerId: 'choco',
              managerName: 'choco',
              version: '2.48.1',
            ),
          ],
        ),
      ],
    );

    controller.selectManager('choco');
    await controller.batchCheckLatestVersionsForSelectedManager();

    expect(
      shell.commands.where((command) => command == 'choco outdated'),
      hasLength(1),
    );
    final packages = controller.selectedManagerSnapshot!.packages;
    expect(
      packages
          .firstWhere((package) => package.name == 'dart-sdk')
          .latestVersion,
      '3.11.4',
    );
    expect(
      packages.firstWhere((package) => package.name == 'git').latestVersion,
      '2.48.1',
    );
  });

  test('choco specific-version lookup parses all returned versions', () async {
    final result = await const ChocolateyAdapter().listInstallableVersions(
      _MappedShellExecutor(<Pattern, ShellResult>{
        "choco search 'git' --exact --all-versions --limit-output":
            const ShellResult(
              exitCode: 0,
              stdout: '''
Chocolatey v2.5.1
git|2.49.0
git|2.48.1
2 packages found.
''',
              stderr: '',
            ),
      }),
      const SearchPackageInstallOption(
        managerId: 'choco',
        managerName: 'choco',
        packageName: 'git',
      ),
    );

    expect(result.versions, <String>['2.49.0', '2.48.1']);
  });

  test(
    'cargo batch latest check uses cargo install-update list output',
    () async {
      const adapter = CargoAdapter();
      final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
        'cargo install-update --list': const ShellResult(
          exitCode: 0,
          stdout: '''
    Polling registry 'https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/'.....

Package         Installed  Latest   Needs update
cargo-binstall  v1.17.7    v1.17.8  Yes
tauri-cli       v2.6.2     v2.10.1  Yes
zoxide          v0.9.8     v0.9.9   Yes
cargo-sweep     v0.8.0     v0.8.0   No
cargo-update    v18.2.0    v18.2.0  No

cargo-binstall contains removed executables (cargo-binstall), which will be re-installed on update
''',
          stderr: '',
        ),
      });
      final controller = PackagePanelController(
        shell: shell,
        adapters: <PackageManagerAdapter>[adapter],
        latestInfoStore: const _MemoryLatestInfoStore(),
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'cargo'},
        initialManagerAvailability: const <String, bool>{'cargo': true},
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: adapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'cargo-binstall',
                managerId: 'cargo',
                managerName: 'cargo',
                version: '1.17.7',
              ),
              ManagedPackage(
                name: 'cargo-sweep',
                managerId: 'cargo',
                managerName: 'cargo',
                version: '0.8.0',
              ),
            ],
          ),
        ],
      );

      controller.selectManager('cargo');
      await controller.batchCheckLatestVersionsForSelectedManager();

      expect(
        shell.commands.where(
          (command) => command == 'cargo install-update --list',
        ),
        hasLength(1),
      );
      final packages = controller.selectedManagerSnapshot!.packages;
      expect(
        packages
            .firstWhere((package) => package.name == 'cargo-binstall')
            .latestVersion,
        '1.17.8',
      );
      expect(
        packages
            .firstWhere((package) => package.name == 'cargo-sweep')
            .latestVersion,
        '0.8.0',
      );
    },
  );

  test(
    'cargo batch latest prerequisite command installs cargo-update when missing',
    () async {
      const adapter = CargoAdapter();
      final shell = _MappedShellExecutor(<Pattern, ShellResult>{
        'cargo install-update --version': const ShellResult(
          exitCode: 1,
          stdout: '',
          stderr: 'error: no such command: `install-update`',
        ),
      });
      final controller = PackagePanelController(
        shell: shell,
        adapters: <PackageManagerAdapter>[adapter],
        latestInfoStore: const _MemoryLatestInfoStore(),
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'cargo'},
        initialManagerAvailability: const <String, bool>{'cargo': true},
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: adapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'tauri-cli',
                managerId: 'cargo',
                managerName: 'cargo',
                version: '2.6.2',
              ),
            ],
          ),
        ],
      );

      controller.selectManager('cargo');
      final command = await controller
          .batchLatestVersionPrerequisiteCommandForSelectedManager();

      expect(command, isNotNull);
      expect(command!.command, 'cargo install cargo-update');
    },
  );

  testWidgets(
    'cargo batch check prompts to install cargo-update when missing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = PackagePanelController(
        shell: _MappedShellExecutor(<Pattern, ShellResult>{
          'cargo install-update --version': const ShellResult(
            exitCode: 1,
            stdout: '',
            stderr: 'error: no such command: `install-update`',
          ),
        }),
        adapters: <PackageManagerAdapter>[const CargoAdapter()],
        latestInfoStore: const _MemoryLatestInfoStore(),
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'cargo'},
        initialManagerAvailability: const <String, bool>{'cargo': true},
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: const CargoAdapter().definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'tauri-cli',
                managerId: 'cargo',
                managerName: 'cargo',
                version: '2.6.2',
              ),
            ],
          ),
        ],
      );
      controller.selectManager('cargo');

      await tester.pumpWidget(
        PkgPanelApp(controller: controller, autoLoad: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '检查更新'));
      await tester.pumpAndSettle();

      expect(find.text('需要先安装依赖'), findsOneWidget);
      expect(find.textContaining('cargo-update'), findsWidgets);
      expect(find.text('cargo install cargo-update'), findsOneWidget);
    },
  );

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

  test(
    'detected yarn auto-enables by default and stays hidden after manual disable',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pkg-panel-yarn-visibility-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final yarnGlobalDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}global',
      );
      await yarnGlobalDir.create(recursive: true);
      await File(
        '${yarnGlobalDir.path}${Platform.pathSeparator}package.json',
      ).writeAsString(
        jsonEncode(<String, Object>{'dependencies': <String, String>{}}),
      );

      final settingsStore = _PersistingVisibilitySettingsStore(
        visibleManagerIds: <String>{'npm'},
      );
      final shell = _MappedShellExecutor(<Pattern, ShellResult>{
        RegExp(r"Get-Command 'npm'", caseSensitive: false): const ShellResult(
          exitCode: 0,
          stdout: '1',
          stderr: '',
        ),
        RegExp(r"Get-Command 'yarn'", caseSensitive: false): const ShellResult(
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
        'yarn global dir': ShellResult(
          exitCode: 0,
          stdout: yarnGlobalDir.path,
          stderr: '',
        ),
      });

      final controller = PackagePanelController(
        shell: shell,
        adapters: PackageManagerRegistry.defaultAdapters,
        settingsStore: settingsStore,
        latestInfoStore: const _MemoryLatestInfoStore(),
        snapshotStore: const _MemorySnapshotStore(),
      );

      await controller.ensureLoaded();

      expect(controller.isManagerVisible('yarn'), isTrue);
      expect(
        controller.visibleSnapshots.map((snapshot) => snapshot.manager.id),
        contains('yarn'),
      );
      expect(settingsStore.visibleManagerIds, contains('yarn'));

      await controller.setManagerVisibility('yarn', false);

      expect(controller.isManagerVisible('yarn'), isFalse);
      expect(settingsStore.manuallyHiddenManagerIds, contains('yarn'));

      final reloadedController = PackagePanelController(
        shell: shell,
        adapters: PackageManagerRegistry.defaultAdapters,
        settingsStore: settingsStore,
        latestInfoStore: const _MemoryLatestInfoStore(),
        snapshotStore: const _MemorySnapshotStore(),
      );

      await reloadedController.ensureLoaded();

      expect(reloadedController.isManagerVisible('yarn'), isFalse);
      expect(
        reloadedController.visibleSnapshots.map(
          (snapshot) => snapshot.manager.id,
        ),
        isNot(contains('yarn')),
      );
    },
  );

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

  testWidgets('latest-version lookup toast shows current command', (
    tester,
  ) async {
    final shell = _DelayedShellExecutor(
      const <Pattern, ShellResult>{},
      delayedCommand: "npm view 'eslint' version --json",
      delayedResult: const ShellResult(
        exitCode: 0,
        stdout: '"9.1.0"',
        stderr: '',
      ),
    );
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      latestInfoStore: const _MemoryLatestInfoStore(),
      settingsStore: const _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
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
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pump();

    final lookupFuture = controller.checkLatestVersion(
      controller.visiblePackages.single,
    );
    await tester.pump();

    expect(find.text('正在执行命令'), findsOneWidget);
    expect(find.text("npm view 'eslint' version --json"), findsOneWidget);

    shell.completeDelayed();
    await lookupFuture;
    await tester.pump();

    expect(find.text("npm view 'eslint' version --json"), findsNothing);
  });

  testWidgets('install page shows a single running command toast', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const commandText = 'npm install -g eslint';
    final shell = _DelayedShellExecutor(
      const <Pattern, ShellResult>{},
      delayedCommand: commandText,
      delayedResult: const ShellResult(exitCode: 0, stdout: '', stderr: ''),
    );
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      latestInfoStore: const _MemoryLatestInfoStore(),
      settingsStore: const _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'npm'},
      initialManagerAvailability: const <String, bool>{'npm': true},
    );

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('安装'));
    await tester.pumpAndSettle();

    final commandFuture = controller.runCommand(
      PackageCommand(
        managerId: 'npm',
        busyKey: 'test-install-toast',
        label: '安装 eslint',
        request: ShellRequest.process(
          executable: 'npm',
          arguments: const <String>['install', '-g', 'eslint'],
          displayCommand: commandText,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('正在执行命令'), findsOneWidget);
    expect(find.text(commandText), findsOneWidget);

    shell.completeDelayed();
    await commandFuture;
    await tester.pump();

    expect(find.text(commandText), findsNothing);
  });

  test(
    'controller tracks scoop batch latest command while lookup runs',
    () async {
      const adapter = ScoopAdapter();
      final shell = _DelayedShellExecutor(
        const <Pattern, ShellResult>{},
        delayedCommand: 'scoop status',
        delayedResult: const ShellResult(
          exitCode: 0,
          stdout: '''
Scoop is up to date.

Name  Installed Version Latest Version Missing Dependencies Info
----  ----------------- -------------- -------------------- ----
7zip  25.01             26.00
''',
          stderr: '',
        ),
      );
      final controller = PackagePanelController(
        shell: shell,
        adapters: <PackageManagerAdapter>[adapter],
        latestInfoStore: const _MemoryLatestInfoStore(),
        settingsStore: const _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'scoop'},
        initialManagerAvailability: const <String, bool>{'scoop': true},
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: adapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: '7zip',
                managerId: 'scoop',
                managerName: 'scoop',
                version: '25.01',
              ),
            ],
          ),
        ],
      );

      controller.selectManager('scoop');
      final lookupFuture = controller
          .batchCheckLatestVersionsForSelectedManager();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.runningCommands.map((command) => command.command),
        contains('scoop status'),
      );

      shell.completeDelayed();
      await lookupFuture;

      expect(controller.runningCommands, isEmpty);
    },
  );

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

  test('pnpm package details use info command output', () async {
    final details = await const PnpmAdapter().loadPackageDetails(
      _MappedShellExecutor(<Pattern, ShellResult>{
        "pnpm info 'uipro-cli'": const ShellResult(
          exitCode: 0,
          stdout: 'uipro-cli@2.2.3 | MIT | deps: 4 | versions: 23',
          stderr: '',
        ),
      }),
      const ManagedPackage(
        name: 'uipro-cli',
        managerId: 'pnpm',
        managerName: 'pnpm',
        version: '2.2.3',
      ),
    );

    expect(details, contains('uipro-cli@2.2.3'));
  });

  test('bun version lookup uses npm registry metadata directly', () async {
    final result = await const BunAdapter().listInstallableVersions(
      _MappedShellExecutor(<Pattern, ShellResult>{
        "npm view 'opencode-ai' versions --json": const ShellResult(
          exitCode: 0,
          stdout: '["0.1.0","0.2.0"]',
          stderr: '',
        ),
      }),
      const SearchPackageInstallOption(
        managerId: 'bun',
        managerName: 'bun',
        packageName: 'opencode-ai',
      ),
    );

    expect(result.versions, <String>['0.2.0', '0.1.0']);
  });

  test('uv package details use filtered tool list output', () async {
    final details = await const UvToolAdapter().loadPackageDetails(
      _MappedShellExecutor(<Pattern, ShellResult>{
        'uv tool list': const ShellResult(
          exitCode: 0,
          stdout: 'ruff v0.6.0\n- ruff\nuipro-cli v2.2.3\n- uipro\n',
          stderr: '',
        ),
      }),
      const ManagedPackage(
        name: 'uipro-cli',
        managerId: 'uv',
        managerName: 'uv',
        version: '2.2.3',
      ),
    );

    expect(details, contains('uipro-cli v2.2.3'));
    expect(details, isNot(contains('ruff v0.6.0')));
  });

  test('cargo package details use cargo info output', () async {
    final details = await const CargoAdapter().loadPackageDetails(
      _MappedShellExecutor(<Pattern, ShellResult>{
        "cargo info 'cargo-edit' --registry crates-io": const ShellResult(
          exitCode: 0,
          stdout:
              'cargo-edit #cli\nAdd Cargo subcommands for modifying a Cargo.toml file\nversion: 0.13.0\nrepository: https://github.com/killercup/cargo-edit\n',
          stderr: '',
        ),
      }),
      const ManagedPackage(
        name: 'cargo-edit',
        managerId: 'cargo',
        managerName: 'cargo',
        version: '0.13.0',
      ),
    );

    expect(details, contains('cargo-edit #cli'));
    expect(details, contains('version: 0.13.0'));
  });

  test('pip specific-version lookup parses available versions', () async {
    final result = await const PipAdapter().listInstallableVersions(
      _MappedShellExecutor(<Pattern, ShellResult>{
        "pip index versions 'ruff' --disable-pip-version-check --no-color":
            const ShellResult(
              exitCode: 0,
              stdout: '''
ruff (0.9.0)
Available versions: 0.9.0, 0.8.6, 0.8.5
  INSTALLED: 0.8.6
  LATEST:    0.9.0
''',
              stderr: '',
            ),
      }),
      const SearchPackageInstallOption(
        managerId: 'pip',
        managerName: 'pip',
        packageName: 'ruff',
      ),
    );

    expect(result.versions, <String>['0.9.0', '0.8.6', '0.8.5']);
  });

  test('scoop search parses tabular output', () async {
    final results = await const ScoopAdapter().searchPackages(
      _MappedShellExecutor(<Pattern, ShellResult>{
        "scoop search 'chafa'": const ShellResult(
          exitCode: 0,
          stdout:
              'Results from local buckets...\n\nName  Version Source Binaries\n----  ------- ------ --------\nchafa 1.16.1  main\n',
          stderr: '',
        ),
      }),
      'chafa',
    );

    expect(results, hasLength(1));
    expect(results.single.name, 'chafa');
    expect(results.single.version, '1.16.1');
    expect(results.single.source, 'main');
  });

  test(
    'scoop batch latest lookup refreshes buckets before reading status',
    () async {
      final shell = _SequenceShellExecutor(<String, List<ShellResult>>{
        'scoop status': <ShellResult>[
          const ShellResult(
            exitCode: 0,
            stdout:
                "WARN  Scoop bucket(s) out of date. Run 'scoop update' to get the latest changes.\n",
            stderr: '',
          ),
          const ShellResult(
            exitCode: 0,
            stdout: '''
Scoop is up to date.

Name  Installed Version Latest Version Missing Dependencies Info
----  ----------------- -------------- -------------------- ----
7zip  25.01             26.00
llvm  20.1.8            22.1.1         zlib
''',
            stderr: '',
          ),
        ],
        'scoop update': <ShellResult>[
          const ShellResult(exitCode: 0, stdout: 'updated', stderr: ''),
        ],
      });
      final packages = const <ManagedPackage>[
        ManagedPackage(
          name: '7zip',
          managerId: 'scoop',
          managerName: 'scoop',
          version: '25.01',
        ),
        ManagedPackage(
          name: 'llvm',
          managerId: 'scoop',
          managerName: 'scoop',
          version: '20.1.8',
        ),
        ManagedPackage(
          name: 'git',
          managerId: 'scoop',
          managerName: 'scoop',
          version: '2.48.1',
        ),
      ];

      final versions = await const ScoopAdapter().lookupLatestVersions(
        shell,
        packages,
      );

      expect(versions[packages[0].key], '26.00');
      expect(versions[packages[1].key], '22.1.1');
      expect(versions[packages[2].key], '2.48.1');
      expect(
        shell.commands.where((command) => command == 'scoop status'),
        hasLength(2),
      );
      expect(
        shell.commands.where((command) => command == 'scoop update'),
        hasLength(1),
      );
    },
  );

  test('controller batch latest check uses scoop status once', () async {
    const adapter = ScoopAdapter();
    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      'scoop status': const ShellResult(
        exitCode: 0,
        stdout: '''
Scoop is up to date.

Name  Installed Version Latest Version Missing Dependencies Info
----  ----------------- -------------- -------------------- ----
7zip  25.01             26.00
chafa 1.16.2            1.18.1
''',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: <PackageManagerAdapter>[adapter],
      latestInfoStore: const _MemoryLatestInfoStore(),
      settingsStore: const _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'scoop'},
      initialManagerAvailability: const <String, bool>{'scoop': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: adapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: '7zip',
              managerId: 'scoop',
              managerName: 'scoop',
              version: '25.01',
            ),
            ManagedPackage(
              name: 'chafa',
              managerId: 'scoop',
              managerName: 'scoop',
              version: '1.16.2',
            ),
            ManagedPackage(
              name: 'git',
              managerId: 'scoop',
              managerName: 'scoop',
              version: '2.48.1',
            ),
          ],
        ),
      ],
    );

    controller.selectManager('scoop');
    await controller.batchCheckLatestVersionsForSelectedManager();

    expect(
      shell.commands.where((command) => command == 'scoop status'),
      hasLength(1),
    );
    final packages = controller.selectedManagerSnapshot!.packages;
    expect(
      packages.firstWhere((package) => package.name == '7zip').latestVersion,
      '26.00',
    );
    expect(
      packages.firstWhere((package) => package.name == 'chafa').latestVersion,
      '1.18.1',
    );
    expect(
      packages.firstWhere((package) => package.name == 'git').latestVersion,
      '2.48.1',
    );
  });

  test('winget specific-version lookup parses show output', () async {
    final result = await const WingetAdapter().listInstallableVersions(
      _MappedShellExecutor(<Pattern, ShellResult>{
        "winget show --id 'Microsoft.PowerToys' --exact --versions --accept-source-agreements --disable-interactivity":
            const ShellResult(
              exitCode: 0,
              stdout: '''
Found Microsoft PowerToys [Microsoft.PowerToys]
Version
-------
0.90.0
0.89.0
''',
              stderr: '',
            ),
      }),
      const SearchPackageInstallOption(
        managerId: 'winget',
        managerName: 'winget',
        packageName: 'Microsoft PowerToys',
        identifier: 'Microsoft.PowerToys',
      ),
    );

    expect(result.versions, <String>['0.90.0', '0.89.0']);
  });

  test('winget search keeps full version with localized header', () async {
    final results = await const WingetAdapter().searchPackages(
      _MappedShellExecutor(<Pattern, ShellResult>{
        "winget search 'claude code' --disable-interactivity":
            const ShellResult(
              exitCode: 0,
              stdout: '''
名称                                ID                                         版本   源
---------------------------------------------------------------------------------------------
Claude Code                         Anthropic.ClaudeCode                       2.1.86 winget
Claude Code Usage Monitor           CodeZeno.ClaudeCodeUsageMonitor            1.2.9  winget
Claude Code Switcher                Fanis.ClaudeCodeSwitcher                   0.3.0  winget
Claude Code 配置管理器 - 命令行版本 ronghuaxueleng.ClaudeCodeConfigManager.CLI 1.7.0  winget
''',
              stderr: '',
            ),
      }),
      'claude code',
    );

    expect(results, hasLength(4));
    expect(results[0].name, 'Claude Code');
    expect(results[0].identifier, 'Anthropic.ClaudeCode');
    expect(results[0].version, '2.1.86');
    expect(results[0].source, 'winget');

    expect(results[1].version, '1.2.9');
    expect(results[1].source, 'winget');

    expect(results[3].name, 'Claude Code 配置管理器 - 命令行版本');
    expect(results[3].identifier, 'ronghuaxueleng.ClaudeCodeConfigManager.CLI');
    expect(results[3].version, '1.7.0');
    expect(results[3].source, 'winget');
  });
}

class _FakeShellExecutor extends ShellExecutor {
  const _FakeShellExecutor(this.result);

  final ShellResult result;

  @override
  Future<ShellResult> runRequest(
    ShellRequest request, {
    Duration timeout = const Duration(seconds: 30),
    String? executionKey,
  }) async {
    return result;
  }
}

class _ExecutableAvailabilityShellExecutor extends ShellExecutor {
  const _ExecutableAvailabilityShellExecutor(this.availabilityByExecutable);

  final Map<String, bool> availabilityByExecutable;

  @override
  Future<bool> isExecutableAvailable(String executable) async {
    return availabilityByExecutable[executable] ?? false;
  }
}

class _MappedShellExecutor extends ShellExecutor {
  const _MappedShellExecutor(this.results);

  final Map<Pattern, ShellResult> results;

  @override
  Future<ShellResult> runRequest(
    ShellRequest request, {
    Duration timeout = const Duration(seconds: 30),
    String? executionKey,
  }) async {
    final command = request.displayCommand;
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

class _RecordingShellExecutor extends ShellExecutor {
  _RecordingShellExecutor(this.results);

  final Map<Pattern, ShellResult> results;
  final List<String> commands = <String>[];

  @override
  Future<ShellResult> runRequest(
    ShellRequest request, {
    Duration timeout = const Duration(seconds: 30),
    String? executionKey,
  }) async {
    final command = request.displayCommand;
    commands.add(command);
    for (final entry in results.entries) {
      final pattern = entry.key;
      if (pattern is String && command == pattern) {
        return entry.value;
      }
      if (pattern is RegExp && pattern.hasMatch(command)) {
        return entry.value;
      }
    }

    return const ShellResult(exitCode: 0, stdout: '', stderr: '');
  }
}

class _SequenceShellExecutor extends ShellExecutor {
  _SequenceShellExecutor(this.results);

  final Map<String, List<ShellResult>> results;
  final List<String> commands = <String>[];
  final Map<String, int> _indices = <String, int>{};

  @override
  Future<ShellResult> runRequest(
    ShellRequest request, {
    Duration timeout = const Duration(seconds: 30),
    String? executionKey,
  }) async {
    final command = request.displayCommand;
    commands.add(command);
    final queue = results[command];
    if (queue == null || queue.isEmpty) {
      return ShellResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Unexpected command: $command',
      );
    }

    final index = _indices[command] ?? 0;
    if (index >= queue.length) {
      return ShellResult(
        exitCode: 1,
        stdout: '',
        stderr: 'No queued result left for command: $command',
      );
    }

    _indices[command] = index + 1;
    return queue[index];
  }
}

class _MemorySettingsStore extends PackageManagerSettingsStore {
  const _MemorySettingsStore();

  @override
  Future<Set<String>?> loadVisibleManagerIds() async => null;

  @override
  Future<void> saveVisibleManagerIds(Set<String> managerIds) async {}

  @override
  Future<Set<String>?> loadManuallyHiddenManagerIds() async => null;

  @override
  Future<void> saveManuallyHiddenManagerIds(Set<String> managerIds) async {}

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

  @override
  Future<bool> loadAutoCheckAppUpdates() async => true;

  @override
  Future<void> saveAutoCheckAppUpdates(bool value) async {}

  @override
  Future<bool> loadUseGithubMirrorForDownloads() async => true;

  @override
  Future<void> saveUseGithubMirrorForDownloads(bool value) async {}

  @override
  Future<String> loadGithubMirrorBaseUrl() async => 'https://ghproxy.net/';

  @override
  Future<void> saveGithubMirrorBaseUrl(String value) async {}
}

class _PersistingVisibilitySettingsStore extends PackageManagerSettingsStore {
  _PersistingVisibilitySettingsStore({
    Set<String>? visibleManagerIds,
    Set<String>? manuallyHiddenManagerIds,
  }) : visibleManagerIds = visibleManagerIds == null
           ? null
           : Set<String>.from(visibleManagerIds),
       manuallyHiddenManagerIds = manuallyHiddenManagerIds == null
           ? null
           : Set<String>.from(manuallyHiddenManagerIds);

  Set<String>? visibleManagerIds;
  Set<String>? manuallyHiddenManagerIds;

  @override
  Future<Set<String>?> loadVisibleManagerIds() async {
    final ids = visibleManagerIds;
    return ids == null ? null : Set<String>.from(ids);
  }

  @override
  Future<void> saveVisibleManagerIds(Set<String> managerIds) async {
    visibleManagerIds = Set<String>.from(managerIds);
  }

  @override
  Future<Set<String>?> loadManuallyHiddenManagerIds() async {
    final ids = manuallyHiddenManagerIds;
    return ids == null ? null : Set<String>.from(ids);
  }

  @override
  Future<void> saveManuallyHiddenManagerIds(Set<String> managerIds) async {
    manuallyHiddenManagerIds = Set<String>.from(managerIds);
  }

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

  @override
  Future<bool> loadAutoCheckAppUpdates() async => true;

  @override
  Future<void> saveAutoCheckAppUpdates(bool value) async {}

  @override
  Future<bool> loadUseGithubMirrorForDownloads() async => true;

  @override
  Future<void> saveUseGithubMirrorForDownloads(bool value) async {}

  @override
  Future<String> loadGithubMirrorBaseUrl() async => 'https://ghproxy.net/';

  @override
  Future<void> saveGithubMirrorBaseUrl(String value) async {}
}

class _MemoryLatestInfoStore extends PackageLatestInfoStore {
  const _MemoryLatestInfoStore();

  @override
  Future<Map<String, PersistedPackageLatestInfo>> load() async {
    return const <String, PersistedPackageLatestInfo>{};
  }

  @override
  Future<void> save(Map<String, PersistedPackageLatestInfo> entries) async {}
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
  Future<ShellResult> runRequest(
    ShellRequest request, {
    Duration timeout = const Duration(seconds: 30),
    String? executionKey,
  }) async {
    final command = request.displayCommand;
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
