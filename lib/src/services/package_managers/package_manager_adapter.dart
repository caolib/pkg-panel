import '../../models/package_models.dart';
import '../shell_executor.dart';

abstract class PackageManagerAdapter {
  const PackageManagerAdapter(this.definition);

  final PackageManagerDefinition definition;
}

// Lists already installed packages for the local packages tab.
mixin InstalledPackageCapability {
  Future<List<ManagedPackage>> listPackages(ShellExecutor shell);
}

// Enables the manager in the install/search tab.
mixin PackageSearchCapability {
  Future<List<SearchPackage>> searchPackages(ShellExecutor shell, String query);
}

// Builds install commands for search results.
mixin PackageInstallCapability {
  PackageCommand buildInstallCommand(SearchPackageInstallOption package);
}

// Looks up installable versions and builds commands for specific versions.
mixin VersionedPackageInstallCapability {
  Future<PackageVersionQueryResult> listInstallableVersions(
    ShellExecutor shell,
    SearchPackageInstallOption package,
  );

  PackageCommand buildVersionedInstallCommand(
    SearchPackageInstallOption package,
    String version,
  );
}

// Builds an explicit "latest" install command such as package@latest.
mixin LatestTagInstallCapability {
  PackageCommand buildLatestInstallCommand(SearchPackageInstallOption package);
}

// Builds per-package actions such as update or remove.
mixin PackageActionCapability {
  PackageCommand? buildCommand(PackageAction action, ManagedPackage package);
}

// Exposes a batch-update entry point when the manager supports it.
mixin PackageBatchUpdateCapability {
  PackageCommand? buildBatchUpdateCommand();
}

// Loads human-readable package details.
mixin PackageDetailsCapability {
  bool supportsPackageDetails(ManagedPackage package) => true;

  Future<String> loadPackageDetails(
    ShellExecutor shell,
    ManagedPackage package,
  );
}

// Looks up the latest available version for an installed package.
mixin LatestVersionLookupCapability {
  bool supportsLatestVersionLookup(ManagedPackage package) => true;

  bool supportsBatchLatestVersionLookup(List<ManagedPackage> packages) => true;

  String latestVersionLookupCommand(ManagedPackage package);

  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  );
}

// Looks up latest versions for multiple installed packages in one request.
mixin BatchLatestVersionLookupCapability on LatestVersionLookupCapability {
  String batchLatestVersionLookupCommand(List<ManagedPackage> packages) {
    if (packages.isEmpty) {
      return '';
    }
    return latestVersionLookupCommand(packages.first);
  }

  Future<Map<String, String>> lookupLatestVersions(
    ShellExecutor shell,
    List<ManagedPackage> packages,
  );
}

mixin BatchLatestVersionPrerequisiteCapability
    on BatchLatestVersionLookupCapability {
  Future<PackageCommand?> batchLatestVersionPrerequisiteCommand(
    ShellExecutor shell,
    List<ManagedPackage> packages,
  ) async {
    return null;
  }

  String batchLatestVersionPrerequisitePrompt(List<ManagedPackage> packages) {
    return '批量检查更新前需要先安装依赖命令，是否现在安装？';
  }
}
