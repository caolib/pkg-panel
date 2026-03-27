import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkg_panel/src/app.dart';
import 'package:pkg_panel/src/models/package_models.dart';
import 'package:pkg_panel/src/services/package_adapters.dart';
import 'package:pkg_panel/src/services/package_panel_controller.dart';
import 'package:pkg_panel/src/services/shell_executor.dart';

void main() {
  testWidgets('renders seeded package data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = PackagePanelController(
      shell: const ShellExecutor(),
      adapters: PackageManagerRegistry.defaultAdapters,
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
    expect(find.text('批量更新'), findsOneWidget);
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
