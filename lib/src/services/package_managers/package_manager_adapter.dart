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

  Future<String> lookupLatestVersion(
    ShellExecutor shell,
    ManagedPackage package,
  );
}
