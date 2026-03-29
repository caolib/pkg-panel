import 'dart:io';

import 'package_manager_adapter.dart';
import 'bun_package_manager.dart';
import 'cargo_package_manager.dart';
import 'chocolatey_package_manager.dart';
import 'npm_package_manager.dart';
import 'pip_package_manager.dart';
import 'pnpm_package_manager.dart';
import 'scoop_package_manager.dart';
import 'uv_tool_package_manager.dart';
import 'winget_package_manager.dart';

class PackageManagerRegistry {
  static List<PackageManagerAdapter> get defaultAdapters =>
      <PackageManagerAdapter>[
        if (Platform.isWindows) const WingetAdapter(),
        if (Platform.isWindows) const ChocolateyAdapter(),
        if (Platform.isWindows) const ScoopAdapter(),
        const NpmAdapter(),
        const PnpmAdapter(),
        const BunAdapter(),
        const PipAdapter(),
        const UvToolAdapter(),
        const CargoAdapter(),
      ];
}
