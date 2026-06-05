import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:pkg_panel/src/widgets/linkified_selectable_text.dart';
import 'package:pkg_panel/l10n/app_localizations.dart';

void main() {
  testWidgets('renders seeded package data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final checkedAt = DateTime.now();
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
          packages: <ManagedPackage>[
            ManagedPackage(
              name: 'eslint',
              managerId: 'npm',
              managerName: 'npm',
              version: '9.0.0',
              latestVersion: '9.1.0',
              latestVersionCheckedAt: checkedAt,
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
    expect(find.text('刷新'), findsNothing);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('检查时间'), findsOneWidget);
    expect(find.text('刚刚'), findsOneWidget);
    expect(find.text('附加信息'), findsNothing);
    expect(find.textContaining('上次检查'), findsNothing);
    expect(find.text('批量更新'), findsNothing);
    expect(find.text('操作'), findsNothing);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('升级'), findsNothing);
    expect(find.text('删除'), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('eslint').last),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('检查更新'), findsNWidgets(2));
    expect(find.text('升级'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('pip manager hides global update check controls', (tester) async {
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

    expect(find.text('检查更新'), findsNothing);
  });

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
    final checkedAt = DateTime(2026, 6, 5, 12);
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
      settingsStore: _MemorySettingsStore(),
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
          packages: <ManagedPackage>[
            ManagedPackage(
              name: 'eslint',
              managerId: 'npm',
              managerName: 'npm',
              version: '9.0.0',
              latestVersion: '9.2.0',
              latestVersionCheckedAt: checkedAt,
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
    final package = controller.selectedManagerSnapshot!.packages.single;
    expect(package.version, '9.1.0');
    expect(package.latestVersion, '9.2.0');
    expect(package.latestVersionCheckedAt, checkedAt);
  });

  test('controller batch latest check uses npm outdated once', () async {
    const adapter = NpmAdapter();
    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      'npm outdated -g --json': const ShellResult(
        exitCode: 1,
        stdout:
            '{"eslint":{"current":"9.0.0","wanted":"9.1.0","latest":"9.1.0"},'
            '"typescript":{"current":"5.6.0","wanted":"5.7.0","latest":"5.7.0"}}',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: <PackageManagerAdapter>[adapter],
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'npm'},
      initialManagerAvailability: const <String, bool>{'npm': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: adapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: 'eslint',
              managerId: 'npm',
              managerName: 'npm',
              version: '9.0.0',
            ),
            ManagedPackage(
              name: 'typescript',
              managerId: 'npm',
              managerName: 'npm',
              version: '5.6.0',
            ),
          ],
        ),
      ],
    );

    controller.selectManager('npm');
    await controller.batchCheckLatestVersionsForSelectedManager();

    expect(
      shell.commands.where((command) => command == 'npm outdated -g --json'),
      hasLength(1),
    );
    final packages = controller.selectedManagerSnapshot!.packages;
    expect(
      packages.firstWhere((package) => package.name == 'eslint').latestVersion,
      '9.1.0',
    );
    expect(
      packages
          .firstWhere((package) => package.name == 'typescript')
          .latestVersion,
      '5.7.0',
    );
  });

  test('controller persists local update filter selection', () async {
    const adapter = NpmAdapter();
    final settingsStore = _MemorySettingsStore(
      showOnlyPackagesWithUpdates: true,
    );
    final controller = PackagePanelController(
      shell: const ShellExecutor(),
      adapters: const <PackageManagerAdapter>[adapter],
      settingsStore: settingsStore,
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'npm'},
      initialManagerAvailability: const <String, bool>{'npm': true},
      initialShowOnlyPackagesWithUpdates: await settingsStore
          .loadShowOnlyPackagesWithUpdates(),
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: adapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: '@github/copilot',
              managerId: 'npm',
              managerName: 'npm',
              version: '1.0.0',
              latestVersion: '1.1.0',
            ),
            ManagedPackage(
              name: 'eslint',
              managerId: 'npm',
              managerName: 'npm',
              version: '9.0.0',
              latestVersion: '9.0.0',
            ),
          ],
        ),
      ],
    );

    expect(controller.showOnlyPackagesWithUpdates, isTrue);
    expect(controller.visiblePackages.map((package) => package.name), <String>[
      '@github/copilot',
    ]);

    controller.setShowOnlyPackagesWithUpdates(false);

    expect(settingsStore.showOnlyPackagesWithUpdates, isFalse);
    expect(controller.visiblePackages, hasLength(2));
  });

  test(
    'selected package commands group packages by manager when supported',
    () {
      const npmAdapter = NpmAdapter();
      const pnpmAdapter = PnpmAdapter();
      const cargoAdapter = CargoAdapter();
      final controller = PackagePanelController(
        shell: const ShellExecutor(),
        adapters: const <PackageManagerAdapter>[
          npmAdapter,
          pnpmAdapter,
          cargoAdapter,
        ],
        settingsStore: _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm', 'pnpm', 'cargo'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pnpm': true,
          'cargo': true,
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
              ManagedPackage(
                name: 'typescript',
                managerId: 'npm',
                managerName: 'npm',
                version: '5.6.0',
              ),
            ],
          ),
          ManagerSnapshot(
            manager: pnpmAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: '@vue/cli',
                managerId: 'pnpm',
                managerName: 'pnpm',
                version: '5.0.0',
              ),
              ManagedPackage(
                name: 'serve',
                managerId: 'pnpm',
                managerName: 'pnpm',
                version: '14.0.0',
              ),
            ],
          ),
          ManagerSnapshot(
            manager: cargoAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'cargo-update',
                managerId: 'cargo',
                managerName: 'cargo',
                version: '19.0.1',
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

      controller.setPackageMultiSelectMode(true);
      controller.setAllVisiblePackagesSelected(true);

      final updateCommands = controller.commandsForSelectedPackages(
        PackageAction.update,
      );
      expect(updateCommands, hasLength(4));
      expect(
        updateCommands.map((command) => command.command),
        containsAll(<String>[
          "npm update -g 'eslint' 'typescript'",
          "pnpm update -g --latest '@vue/cli' 'serve'",
          "cargo install 'cargo-sweep' --force",
          "cargo install 'cargo-update' --force",
        ]),
      );

      final removeCommands = controller.commandsForSelectedPackages(
        PackageAction.remove,
      );
      expect(
        removeCommands.map((command) => command.command),
        containsAll(<String>[
          "npm uninstall -g 'eslint' 'typescript'",
          "pnpm remove -g '@vue/cli' 'serve'",
        ]),
      );
    },
  );

  test('controller batch latest check uses pnpm outdated once', () async {
    const adapter = PnpmAdapter();
    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      'pnpm outdated -g --format json': const ShellResult(
        exitCode: 1,
        stdout:
            '{"typescript":{"current":"6.0.2","latest":"6.0.3",'
            '"wanted":"6.0.2","isDeprecated":false,"dependencyType":"dependencies"}}',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: <PackageManagerAdapter>[adapter],
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'pnpm'},
      initialManagerAvailability: const <String, bool>{'pnpm': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: adapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: 'typescript',
              managerId: 'pnpm',
              managerName: 'pnpm',
              version: '6.0.2',
            ),
          ],
        ),
      ],
    );

    controller.selectManager('pnpm');
    await controller.batchCheckLatestVersionsForSelectedManager();

    expect(
      shell.commands.where(
        (command) => command == 'pnpm outdated -g --format json',
      ),
      hasLength(1),
    );
    final packages = controller.selectedManagerSnapshot!.packages;
    expect(
      packages
          .firstWhere((package) => package.name == 'typescript')
          .latestVersion,
      '6.0.3',
    );
  });

  test('controller skips pip and uv global update checks', () async {
    const pipAdapter = PipAdapter();
    const uvAdapter = UvToolAdapter();
    const pipPackage = ManagedPackage(
      name: 'ruff',
      managerId: 'pip',
      managerName: 'pip',
      version: '0.8.6',
    );
    const uvPackage = ManagedPackage(
      name: 'uipro-cli',
      managerId: 'uv',
      managerName: 'uv',
      version: '2.2.3',
    );
    final shell = _RecordingShellExecutor(const <Pattern, ShellResult>{});
    final controller = PackagePanelController(
      shell: shell,
      adapters: const <PackageManagerAdapter>[pipAdapter, uvAdapter],
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'pip', 'uv'},
      initialManagerAvailability: const <String, bool>{'pip': true, 'uv': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: pipAdapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[pipPackage],
        ),
        ManagerSnapshot(
          manager: uvAdapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[uvPackage],
        ),
      ],
    );

    controller.selectManager('pip');
    expect(controller.canCheckLatestVersion(pipPackage), isFalse);
    expect(controller.canBatchCheckLatestForSelectedManager, isFalse);
    await controller.batchCheckLatestVersionsForSelectedManager();
    expect(await controller.checkLatestVersion(pipPackage), isNull);

    controller.selectManager('uv');
    expect(controller.canCheckLatestVersion(uvPackage), isFalse);
    expect(controller.canBatchCheckLatestForSelectedManager, isFalse);
    await controller.batchCheckLatestVersionsForSelectedManager();
    expect(await controller.checkLatestVersion(uvPackage), isNull);

    expect(shell.commands, isEmpty);
  });

  test(
    'startup latest check updates supported managers and skips pip uv',
    () async {
      const npmAdapter = NpmAdapter();
      const pipAdapter = PipAdapter();
      const uvAdapter = UvToolAdapter();
      const npmPackage = ManagedPackage(
        name: 'eslint',
        managerId: 'npm',
        managerName: 'npm',
        version: '9.0.0',
      );
      const pipPackage = ManagedPackage(
        name: 'ruff',
        managerId: 'pip',
        managerName: 'pip',
        version: '0.8.6',
      );
      const uvPackage = ManagedPackage(
        name: 'uipro-cli',
        managerId: 'uv',
        managerName: 'uv',
        version: '2.2.3',
      );
      final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
        'npm outdated -g --json': const ShellResult(
          exitCode: 1,
          stdout:
              '{"eslint":{"current":"9.0.0","wanted":"9.1.0","latest":"9.1.0"}}',
          stderr: '',
        ),
      });
      final controller = PackagePanelController(
        shell: shell,
        adapters: const <PackageManagerAdapter>[
          npmAdapter,
          pipAdapter,
          uvAdapter,
        ],
        settingsStore: _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm', 'pip', 'uv'},
        initialManagerAvailability: const <String, bool>{
          'npm': true,
          'pip': true,
          'uv': true,
        },
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: npmAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[npmPackage],
          ),
          ManagerSnapshot(
            manager: pipAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[pipPackage],
          ),
          ManagerSnapshot(
            manager: uvAdapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[uvPackage],
          ),
        ],
      );

      await controller.checkStartupLatestVersions();

      expect(shell.commands, <String>['npm outdated -g --json']);
      expect(
        controller.startupUpdateCheckStatus.phase,
        StartupUpdateCheckPhase.complete,
      );
      expect(controller.startupUpdateCheckStatus.totalManagers, 1);
      expect(controller.startupUpdateCheckStatus.processedManagers, 1);
      expect(controller.startupUpdateCheckStatus.updatedPackages, 1);

      final packages = controller.visiblePackages;
      expect(
        packages
            .firstWhere((package) => package.name == 'eslint')
            .latestVersion,
        '9.1.0',
      );
      expect(
        packages.firstWhere((package) => package.name == 'ruff').latestVersion,
        isNull,
      );
      expect(
        packages
            .firstWhere((package) => package.name == 'uipro-cli')
            .latestVersion,
        isNull,
      );
    },
  );

  test(
    'startup latest check does not show running command toast entries',
    () async {
      const adapter = NpmAdapter();
      final shell = _DelayedShellExecutor(
        const <Pattern, ShellResult>{},
        delayedCommand: 'npm outdated -g --json',
        delayedResult: const ShellResult(
          exitCode: 1,
          stdout:
              '{"eslint":{"current":"9.0.0","wanted":"9.1.0","latest":"9.1.0"}}',
          stderr: '',
        ),
      );
      final controller = PackagePanelController(
        shell: shell,
        adapters: const <PackageManagerAdapter>[adapter],
        settingsStore: _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm'},
        initialManagerAvailability: const <String, bool>{'npm': true},
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: adapter.definition,
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

      final checkFuture = controller.checkStartupLatestVersions();
      await shell.waitForDelayedCommand();

      expect(controller.startupUpdateCheckStatus.isRunning, isTrue);
      expect(controller.runningCommands, isEmpty);

      shell.completeDelayed();
      await checkFuture;

      expect(controller.runningCommands, isEmpty);
    },
  );

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
      settingsStore: _MemorySettingsStore(),
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
    'cargo batch latest check uses cargo install-update -l output',
    () async {
      const adapter = CargoAdapter();
      final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
        'cargo install-update -l': const ShellResult(
          exitCode: 0,
          stdout: '''
    Polling registry 'https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/'....

Package       Installed  Latest   Needs update
cargo-update  v19.0.1    v20.0.0  Yes
tauri-cli     v2.10.1    v2.11.2  Yes
cargo-sweep   v0.8.0     v0.8.0   No
zoxide        v0.9.9     v0.9.9   No
''',
          stderr: '',
        ),
      });
      final controller = PackagePanelController(
        shell: shell,
        adapters: <PackageManagerAdapter>[adapter],
        settingsStore: _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'cargo'},
        initialManagerAvailability: const <String, bool>{'cargo': true},
        initialSnapshots: <ManagerSnapshot>[
          ManagerSnapshot(
            manager: adapter.definition,
            loadState: ManagerLoadState.ready,
            packages: const <ManagedPackage>[
              ManagedPackage(
                name: 'cargo-update',
                managerId: 'cargo',
                managerName: 'cargo',
                version: '19.0.1',
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
        shell.commands.where((command) => command == 'cargo install-update -l'),
        hasLength(1),
      );
      final packages = controller.selectedManagerSnapshot!.packages;
      expect(
        packages
            .firstWhere((package) => package.name == 'cargo-update')
            .latestVersion,
        '20.0.0',
      );
      expect(
        packages
            .firstWhere((package) => package.name == 'cargo-sweep')
            .latestVersion,
        '0.8.0',
      );
    },
  );

  test('cargo install-update -l lookup reads latest column', () async {
    final versions = await const CargoAdapter().lookupLatestVersions(
      _MappedShellExecutor(<Pattern, ShellResult>{
        'cargo install-update -l': const ShellResult(
          exitCode: 0,
          stdout: '''
    Polling registry 'https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/'....

Package       Installed  Latest   Needs update
cargo-update  v19.0.1    v20.0.0  Yes
tauri-cli     v2.10.1    v2.11.2  Yes
cargo-sweep   v0.8.0     v0.8.0   No
zoxide        v0.9.9     v0.9.9   No
''',
          stderr: '',
        ),
      }),
      const <ManagedPackage>[
        ManagedPackage(
          name: 'cargo-update',
          managerId: 'cargo',
          managerName: 'cargo',
          version: '19.0.1',
        ),
        ManagedPackage(
          name: 'tauri-cli',
          managerId: 'cargo',
          managerName: 'cargo',
          version: '2.10.1',
        ),
        ManagedPackage(
          name: 'cargo-sweep',
          managerId: 'cargo',
          managerName: 'cargo',
          version: '0.8.0',
        ),
        ManagedPackage(
          name: 'zoxide',
          managerId: 'cargo',
          managerName: 'cargo',
          version: '0.9.9',
        ),
      ],
    );

    expect(versions['cargo::cargo-update::'], '20.0.0');
    expect(versions['cargo::tauri-cli::'], '2.11.2');
    expect(versions['cargo::cargo-sweep::'], '0.8.0');
    expect(versions['cargo::zoxide::'], '0.9.9');
  });

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
        settingsStore: _MemorySettingsStore(),
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
        settingsStore: _MemorySettingsStore(),
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
      settingsStore: _MemorySettingsStore(),
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
      settingsStore: _MemorySettingsStore(),
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
      settingsStore: _MemorySettingsStore(),
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

  testWidgets('startup update check status hides after completion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      'npm outdated -g --json': const ShellResult(
        exitCode: 1,
        stdout:
            '{"eslint":{"current":"9.0.0","wanted":"9.1.0","latest":"9.1.0"}}',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: <PackageManagerAdapter>[const NpmAdapter()],
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'npm'},
      initialManagerAvailability: const <String, bool>{'npm': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: const NpmAdapter().definition,
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

    await tester.runAsync(controller.checkStartupLatestVersions);

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pump();

    expect(
      controller.startupUpdateCheckStatus.phase,
      StartupUpdateCheckPhase.complete,
    );
    expect(controller.startupUpdateCheckStatus.isVisible, isFalse);
    expect(find.textContaining('启动检查'), findsNothing);
  });

  testWidgets('latest-version lookup toast shows current command', (
    tester,
  ) async {
    final shell = _DelayedShellExecutor(
      const <Pattern, ShellResult>{},
      delayedCommand: 'npm outdated -g --json',
      delayedResult: const ShellResult(
        exitCode: 1,
        stdout:
            '{"eslint":{"current":"9.0.0","wanted":"9.1.0","latest":"9.1.0"}}',
        stderr: '',
      ),
    );
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      settingsStore: _MemorySettingsStore(),
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

    expect(find.text('npm outdated -g --json'), findsOneWidget);
    expect(find.text('不可取消'), findsNothing);

    shell.completeDelayed();
    await lookupFuture;
    await tester.pump();

    expect(find.text('npm outdated -g --json'), findsNothing);
  });

  testWidgets('winget and uv rows show load check time', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      'winget list --disable-interactivity': const ShellResult(
        exitCode: 0,
        stdout: '''
Name                           Id                               Version     Available Source
---------------------------------------------------------------------------------------------
Microsoft Visual Studio Code   Microsoft.VisualStudioCode       1.99.0      1.100.0   winget
''',
        stderr: '',
      ),
      'uv tool list': const ShellResult(
        exitCode: 0,
        stdout: '''
ruff v0.8.6
- ruff
''',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: const <PackageManagerAdapter>[WingetAdapter(), UvToolAdapter()],
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'winget', 'uv'},
      initialManagerAvailability: const <String, bool>{
        'winget': true,
        'uv': true,
      },
      wingetIconResolver: const _FakeWingetIconResolver(r'C:\icons\vscode.ico'),
    );

    await controller.ensureLoaded();
    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.visiblePackages, hasLength(2));
    expect(
      controller.visiblePackages.every(
        (package) => package.latestVersionCheckedAt != null,
      ),
      isTrue,
    );
    expect(find.text('检查时间'), findsOneWidget);
    expect(find.text('刚刚'), findsNWidgets(2));
    expect(shell.commands, isNot(contains('uv tool upgrade --all')));
  });

  testWidgets('install search table hides extra info column', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const adapter = _FakeSearchAdapter();
    final controller = PackagePanelController(
      shell: const ShellExecutor(),
      adapters: const <PackageManagerAdapter>[adapter],
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'fake'},
      initialManagerAvailability: const <String, bool>{'fake': true},
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PackageInstallPage(controller: controller)),
      ),
    );
    await tester.pump();

    await controller.searchPackages(query: 'demo');
    await tester.pumpAndSettle();

    expect(controller.searchResults, hasLength(1));
    expect(find.text('附加信息'), findsNothing);
    expect(find.text('说明文本'), findsNothing);
    expect(find.text('demo-package'), findsOneWidget);
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
      settingsStore: _MemorySettingsStore(),
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

    expect(find.text('正在执行命令 (1)'), findsOneWidget);
    expect(find.text(commandText), findsOneWidget);

    shell.completeDelayed();
    await commandFuture;
    await tester.pump();

    expect(find.text(commandText), findsNothing);
  });

  testWidgets('running command toast truncates commands and can collapse', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const commandText =
        "winget upgrade --id 'Anthropic.Claude' --exact "
        '--accept-package-agreements --accept-source-agreements '
        '--disable-interactivity';
    final shell = _DelayedShellExecutor(
      const <Pattern, ShellResult>{},
      delayedCommand: commandText,
      delayedResult: const ShellResult(exitCode: 0, stdout: '', stderr: ''),
    );
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'winget'},
      initialManagerAvailability: const <String, bool>{'winget': true},
    );

    await tester.pumpWidget(
      PkgPanelApp(controller: controller, autoLoad: false),
    );
    await tester.pumpAndSettle();

    final commandFuture = controller.runCommand(
      PackageCommand(
        managerId: 'winget',
        busyKey: 'test-winget-toast',
        label: '升级 Claude',
        request: ShellRequest.process(
          executable: 'winget',
          arguments: const <String>[
            'upgrade',
            '--id',
            'Anthropic.Claude',
            '--exact',
            '--accept-package-agreements',
            '--accept-source-agreements',
            '--disable-interactivity',
          ],
          displayCommand: commandText,
        ),
      ),
    );
    await tester.pump();

    final commandTextWidget = tester.widget<Text>(find.text(commandText));
    expect(commandTextWidget.maxLines, 1);

    await tester.tap(find.byIcon(Icons.unfold_less));
    await tester.pumpAndSettle();

    expect(find.text(commandText), findsNothing);
    expect(find.text('正在执行命令 (1)'), findsOneWidget);
    expect(find.byIcon(Icons.unfold_more), findsOneWidget);

    shell.completeDelayed();
    await commandFuture;
    await tester.pump();
  });

  testWidgets(
    'cancel failure stays silent instead of showing cannot-cancel snackbar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const commandText = 'npm install -g eslint';
      final shell = _NonCancellableDelayedShellExecutor(
        const <Pattern, ShellResult>{},
        delayedCommand: commandText,
        delayedResult: const ShellResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final controller = PackagePanelController(
        shell: shell,
        adapters: PackageManagerRegistry.defaultAdapters,
        settingsStore: _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm'},
        initialManagerAvailability: const <String, bool>{'npm': true},
      );

      await tester.pumpWidget(
        PkgPanelApp(controller: controller, autoLoad: false),
      );
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

      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.stop_circle_outlined));
      await tester.pump();

      expect(find.text('当前命令无法取消。'), findsNothing);
      expect(find.text(commandText), findsOneWidget);

      shell.completeDelayed();
      await commandFuture;
      await tester.pump();
    },
  );

  test(
    'cancelling a running command forcefully clears queued commands',
    () async {
      const firstCommandText = 'npm install -g eslint';
      const secondCommandText = 'npm uninstall -g eslint';
      final shell = _CancellableDelayedShellExecutor(
        const <Pattern, ShellResult>{},
        delayedCommand: firstCommandText,
        delayedResult: const ShellResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final controller = PackagePanelController(
        shell: shell,
        adapters: PackageManagerRegistry.defaultAdapters,
        settingsStore: _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm'},
        initialManagerAvailability: const <String, bool>{'npm': true},
      );

      final firstFuture = controller.runCommand(
        PackageCommand(
          managerId: 'npm',
          busyKey: 'first',
          label: '安装 eslint',
          request: ShellRequest.process(
            executable: 'npm',
            arguments: const <String>['install', '-g', 'eslint'],
            displayCommand: firstCommandText,
          ),
        ),
      );
      final secondFuture = controller.runCommand(
        PackageCommand(
          managerId: 'npm',
          busyKey: 'second',
          label: '卸载 eslint',
          request: ShellRequest.process(
            executable: 'npm',
            arguments: const <String>['uninstall', '-g', 'eslint'],
            displayCommand: secondCommandText,
          ),
        ),
      );

      expect(controller.runningCommands.length, 2);

      final cancelled = await controller.cancelRunningCommand('first');
      expect(cancelled, isTrue);

      final firstResult = await firstFuture;
      final secondResult = await secondFuture;

      expect(firstResult.wasCancelled, isTrue);
      expect(secondResult.wasCancelled, isTrue);
      expect(shell.cancelForceFlags, <bool>[true]);
      expect(controller.runningCommands, isEmpty);
    },
  );

  test('queued command can be cancelled before it starts', () async {
    const firstCommandText = 'npm install -g eslint';
    const secondCommandText = 'npm uninstall -g eslint';
    final shell = _DelayedShellExecutor(
      const <Pattern, ShellResult>{},
      delayedCommand: firstCommandText,
      delayedResult: const ShellResult(exitCode: 0, stdout: '', stderr: ''),
    );
    final controller = PackagePanelController(
      shell: shell,
      adapters: PackageManagerRegistry.defaultAdapters,
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'npm'},
      initialManagerAvailability: const <String, bool>{'npm': true},
    );

    final firstFuture = controller.runCommand(
      PackageCommand(
        managerId: 'npm',
        busyKey: 'first',
        label: '安装 eslint',
        request: ShellRequest.process(
          executable: 'npm',
          arguments: const <String>['install', '-g', 'eslint'],
          displayCommand: firstCommandText,
        ),
      ),
    );
    final secondFuture = controller.runCommand(
      PackageCommand(
        managerId: 'npm',
        busyKey: 'second',
        label: '卸载 eslint',
        request: ShellRequest.process(
          executable: 'npm',
          arguments: const <String>['uninstall', '-g', 'eslint'],
          displayCommand: secondCommandText,
        ),
      ),
    );

    final cancelled = await controller.cancelRunningCommand('second');
    final secondResult = await secondFuture;

    expect(cancelled, isTrue);
    expect(secondResult.wasCancelled, isTrue);
    expect(controller.runningCommands.map((command) => command.busyKey), [
      'first',
    ]);

    shell.completeDelayed();
    await firstFuture;
  });

  test(
    'runCommand routes administrator requests through elevated shell',
    () async {
      const commandText = 'npm install -g eslint';
      final shell = _ElevatedRecordingShellExecutor(
        const ShellResult(exitCode: 7, stdout: '', stderr: 'failed'),
      );
      final controller = PackagePanelController(
        shell: shell,
        adapters: PackageManagerRegistry.defaultAdapters,
        settingsStore: _MemorySettingsStore(),
        snapshotStore: const _MemorySnapshotStore(),
        initialVisibleManagerIds: const <String>{'npm'},
        initialManagerAvailability: const <String, bool>{'npm': true},
      );

      final result = await controller.runCommand(
        PackageCommand(
          managerId: 'npm',
          busyKey: 'admin-install',
          label: '安装 eslint',
          request: ShellRequest.process(
            executable: 'npm',
            arguments: const <String>['install', '-g', 'eslint'],
            displayCommand: commandText,
          ),
        ),
        runAsAdministrator: true,
      );

      expect(result.exitCode, 7);
      expect(shell.commands, isEmpty);
      expect(shell.elevatedCommands, <String>[commandText]);
      expect(controller.runningCommands, isEmpty);
    },
  );

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
        settingsStore: _MemorySettingsStore(),
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
      settingsStore: _MemorySettingsStore(),
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

  test('controller batch latest check uses bun outdated once', () async {
    const adapter = BunAdapter();
    final shell = _RecordingShellExecutor(<Pattern, ShellResult>{
      'bun outdated --global': const ShellResult(
        exitCode: 1,
        stdout:
            'bun outdated v1.2.17 (282dda62)\n'
            '\u250C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u252C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u252C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u252C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n'
            '\u2502 Package    \u2502 Current \u2502 Update \u2502 Latest \u2502\n'
            '\u251C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2524\n'
            '\u2502 cc-connect \u2502 1.3.1   \u2502 1.3.1  \u2502 1.3.2  \u2502\n'
            '\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n',
        stderr: '',
      ),
    });
    final controller = PackagePanelController(
      shell: shell,
      adapters: <PackageManagerAdapter>[adapter],
      settingsStore: _MemorySettingsStore(),
      snapshotStore: const _MemorySnapshotStore(),
      initialVisibleManagerIds: const <String>{'bun'},
      initialManagerAvailability: const <String, bool>{'bun': true},
      initialSnapshots: <ManagerSnapshot>[
        ManagerSnapshot(
          manager: adapter.definition,
          loadState: ManagerLoadState.ready,
          packages: const <ManagedPackage>[
            ManagedPackage(
              name: 'cc-connect',
              managerId: 'bun',
              managerName: 'bun',
              version: '1.3.1',
            ),
          ],
        ),
      ],
    );

    controller.selectManager('bun');
    await controller.batchCheckLatestVersionsForSelectedManager();

    expect(
      shell.commands.where((command) => command == 'bun outdated --global'),
      hasLength(1),
    );
    final packages = controller.selectedManagerSnapshot!.packages;
    expect(
      packages
          .firstWhere((package) => package.name == 'cc-connect')
          .latestVersion,
      '1.3.2',
    );
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
      settingsStore: _MemorySettingsStore(),
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

class _ElevatedRecordingShellExecutor extends ShellExecutor {
  _ElevatedRecordingShellExecutor(this.result);

  final ShellResult result;
  final List<String> commands = <String>[];
  final List<String> elevatedCommands = <String>[];

  @override
  Future<ShellResult> runRequest(
    ShellRequest request, {
    Duration timeout = const Duration(seconds: 30),
    String? executionKey,
  }) async {
    commands.add(request.displayCommand);
    return result;
  }

  @override
  Future<ShellResult> runRequestAsAdministrator(
    ShellRequest request, {
    Duration timeout = const Duration(seconds: 30),
    String? executionKey,
  }) async {
    elevatedCommands.add(request.displayCommand);
    return result;
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
  _MemorySettingsStore({this.showOnlyPackagesWithUpdates = false});

  bool showOnlyPackagesWithUpdates;

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
  Future<LocalPackageTableColumnWidths>
  loadLocalPackageTableColumnWidths() async {
    return LocalPackageTableColumnWidths.defaults;
  }

  @override
  Future<void> saveLocalPackageTableColumnWidths(
    LocalPackageTableColumnWidths widths,
  ) async {}

  @override
  Future<InstallSearchTableColumnWidths>
  loadInstallSearchTableColumnWidths() async {
    return InstallSearchTableColumnWidths.defaults;
  }

  @override
  Future<void> saveInstallSearchTableColumnWidths(
    InstallSearchTableColumnWidths widths,
  ) async {}

  @override
  Future<bool> loadShowOnlyPackagesWithUpdates() async {
    return showOnlyPackagesWithUpdates;
  }

  @override
  Future<void> saveShowOnlyPackagesWithUpdates(bool value) async {
    showOnlyPackagesWithUpdates = value;
  }

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
  Future<bool> loadRememberWindowPlacement() async => true;

  @override
  Future<void> saveRememberWindowPlacement(bool value) async {}

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
  Future<LocalPackageTableColumnWidths>
  loadLocalPackageTableColumnWidths() async {
    return LocalPackageTableColumnWidths.defaults;
  }

  @override
  Future<void> saveLocalPackageTableColumnWidths(
    LocalPackageTableColumnWidths widths,
  ) async {}

  @override
  Future<InstallSearchTableColumnWidths>
  loadInstallSearchTableColumnWidths() async {
    return InstallSearchTableColumnWidths.defaults;
  }

  @override
  Future<void> saveInstallSearchTableColumnWidths(
    InstallSearchTableColumnWidths widths,
  ) async {}

  @override
  Future<bool> loadShowOnlyPackagesWithUpdates() async => false;

  @override
  Future<void> saveShowOnlyPackagesWithUpdates(bool value) async {}

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
  Future<bool> loadRememberWindowPlacement() async => true;

  @override
  Future<void> saveRememberWindowPlacement(bool value) async {}

  @override
  Future<bool> loadUseGithubMirrorForDownloads() async => true;

  @override
  Future<void> saveUseGithubMirrorForDownloads(bool value) async {}

  @override
  Future<String> loadGithubMirrorBaseUrl() async => 'https://ghproxy.net/';

  @override
  Future<void> saveGithubMirrorBaseUrl(String value) async {}
}

class _FakeSearchAdapter extends PackageManagerAdapter
    with PackageSearchCapability {
  const _FakeSearchAdapter()
    : super(
        const PackageManagerDefinition(
          id: 'fake',
          displayName: 'Fake',
          executable: 'fake',
          description: 'Fake search manager',
          color: Colors.blue,
          icon: Icons.extension_outlined,
        ),
      );

  @override
  Future<List<SearchPackage>> searchPackages(
    ShellExecutor shell,
    String query,
  ) async {
    return const <SearchPackage>[
      SearchPackage(
        name: 'demo-package',
        managerId: 'fake',
        managerName: 'Fake',
        version: '1.2.3',
        description: '说明文本',
        identifier: 'demo.package',
        source: 'fake-source',
      ),
    ];
  }
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
  final Completer<void> _delayedCommandCompleter = Completer<void>();

  Future<void> waitForDelayedCommand() => _delayedCommandCompleter.future;

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
      if (!_delayedCommandCompleter.isCompleted) {
        _delayedCommandCompleter.complete();
      }
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

class _NonCancellableDelayedShellExecutor extends _DelayedShellExecutor {
  _NonCancellableDelayedShellExecutor(
    super.results, {
    required super.delayedCommand,
    required super.delayedResult,
  });

  @override
  Future<bool> cancelExecution(
    String executionKey, {
    bool force = false,
  }) async => false;
}

class _CancellableDelayedShellExecutor extends ShellExecutor {
  _CancellableDelayedShellExecutor(
    this.results, {
    required this.delayedCommand,
    required this.delayedResult,
  });

  final Map<Pattern, ShellResult> results;
  final String delayedCommand;
  final ShellResult delayedResult;
  final Completer<void> _completer = Completer<void>();
  final List<bool> cancelForceFlags = <bool>[];
  final Set<String> _cancelledExecutionKeys = <String>{};

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
      if (executionKey != null &&
          _cancelledExecutionKeys.contains(executionKey)) {
        return const ShellResult(
          exitCode: 130,
          stdout: '',
          stderr: '命令已取消。',
          wasCancelled: true,
        );
      }
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

  @override
  Future<bool> cancelExecution(
    String executionKey, {
    bool force = false,
  }) async {
    cancelForceFlags.add(force);
    _cancelledExecutionKeys.add(executionKey);
    completeDelayed();
    return true;
  }
}
