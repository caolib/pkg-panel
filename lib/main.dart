import 'package:flutter/widgets.dart';
import 'package:pkg_panel/src/app.dart';
import 'package:pkg_panel/src/services/package_adapters.dart';
import 'package:pkg_panel/src/services/package_latest_info_store.dart';
import 'package:pkg_panel/src/services/package_panel_controller.dart';
import 'package:pkg_panel/src/services/shell_executor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const latestInfoStore = PackageLatestInfoStore();
  final initialLatestInfo = await latestInfoStore.load();
  final controller = PackagePanelController(
    shell: const ShellExecutor(),
    adapters: PackageManagerRegistry.defaultAdapters,
    latestInfoStore: latestInfoStore,
    initialLatestInfo: initialLatestInfo,
  );

  runPkgPanel(controller);
}
