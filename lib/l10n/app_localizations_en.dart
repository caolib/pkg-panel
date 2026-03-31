// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pkg Panel';

  @override
  String get appTagline =>
      'A dashboard for managing multiple package managers.';

  @override
  String get tabLocal => 'Local';

  @override
  String get tabInstall => 'Install';

  @override
  String get tabSettings => 'Settings';

  @override
  String get settingsTabGeneral => 'General';

  @override
  String get settingsTabManagers => 'Managers';

  @override
  String get settingsTabAppearance => 'Appearance';

  @override
  String get settingsTabAbout => 'About';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageChinese => 'Simplified Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeModeTitle => 'Theme mode';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get autoCheckUpdatesTitle => 'Check for updates automatically';

  @override
  String get autoCheckUpdatesSubtitle =>
      'When enabled, the app checks GitHub Releases on startup.';

  @override
  String get githubMirrorTitle => 'Use GitHub mirror for downloads';

  @override
  String get githubMirrorSubtitle =>
      'When enabled, update downloads prefer the configured mirror URL.';

  @override
  String get githubMirrorBaseUrlLabel => 'Mirror URL';

  @override
  String get editGithubMirrorTitle => 'Set GitHub mirror URL';

  @override
  String get githubMirrorHint => 'For example: https://ghproxy.net/';

  @override
  String get githubMirrorUpdated => 'Mirror URL updated.';

  @override
  String get fontStackTitle => 'Font stack';

  @override
  String get fontStackDescription =>
      'The first font is primary. Remaining fonts are used as fallbacks in order.';

  @override
  String get fontPreview =>
      'Preview: The quick brown fox jumps over the lazy dog. 敏捷的棕狐跳过了懒狗。';

  @override
  String get editFontStackTitle => 'Set fonts';

  @override
  String get commaSeparatedHint => 'Separate entries with English commas.';

  @override
  String get fontStackInputHint =>
      'For example: Cascadia Code, HanYi YouYuan, Microsoft YaHei UI';

  @override
  String get buttonSetFont => 'Set fonts';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get buttonSave => 'Save';

  @override
  String get buttonRestoreDefault => 'Restore default';

  @override
  String get buttonClose => 'Close';

  @override
  String get buttonCopy => 'Copy';

  @override
  String get buttonRun => 'Run';

  @override
  String get buttonInstall => 'Install';

  @override
  String get buttonSearch => 'Search';

  @override
  String get buttonRefresh => 'Refresh';

  @override
  String get buttonRefreshStatus => 'Refresh status';

  @override
  String get buttonAddGroup => 'Add group';

  @override
  String get buttonEdit => 'Edit';

  @override
  String get buttonOpenSettings => 'Open settings';

  @override
  String get buttonCheckUpdates => 'Check updates';

  @override
  String get buttonBatchUpdate => 'Batch update';

  @override
  String get buttonGitHubRepo => 'GitHub repo';

  @override
  String get buttonOpenReleasePage => 'Open release page';

  @override
  String get buttonDownload => 'Download';

  @override
  String get buttonDownloadAndInstall => 'Download and install';

  @override
  String get buttonRemoveIcon => 'Remove icon';

  @override
  String get buttonResetDefaultIcon => 'Use default icon';

  @override
  String get buttonSelectIcon => 'Select icon';

  @override
  String get buttonChangeIcon => 'Change icon';

  @override
  String get buttonDeleteGroup => 'Delete group';

  @override
  String get buttonConfirm => 'Confirm';

  @override
  String get buttonInstallInputVersion => 'Install typed version';

  @override
  String get searchLocalHint => 'Search installed packages';

  @override
  String get searchInstallHint => 'Search installable packages';

  @override
  String get clearTooltip => 'Clear';

  @override
  String viewLoadErrorsButton(int count) {
    return 'View load errors ($count)';
  }

  @override
  String visiblePackageCount(int count) {
    return '$count packages visible';
  }

  @override
  String managerLoadFailedSuffix(String managerName) {
    return '$managerName (load failed)';
  }

  @override
  String get packageListHeader => 'Packages';

  @override
  String countLabel(int count) {
    return '$count items';
  }

  @override
  String countSelectedLabel(int count, int selectedCount) {
    return '$count items · $selectedCount selected';
  }

  @override
  String get packageNameColumn => 'Package';

  @override
  String get currentVersionColumn => 'Current';

  @override
  String get latestVersionColumn => 'Latest';

  @override
  String get extraInfoColumn => 'Extra';

  @override
  String get versionColumn => 'Version';

  @override
  String get sourceColumn => 'Source';

  @override
  String get packageManagerColumn => 'Manager';

  @override
  String get searchResultsHeader => 'Search results';

  @override
  String get viewDetailsAction => 'View details';

  @override
  String get checkUpdatesAction => 'Check updates';

  @override
  String get updateAction => 'Update';

  @override
  String get upgradeAction => 'Upgrade';

  @override
  String get removeAction => 'Remove';

  @override
  String get installSpecificVersionAction => 'Install specific version';

  @override
  String get loadingDetails => 'Loading details...';

  @override
  String get detailsUnavailable =>
      'Details failed to load or returned no content.';

  @override
  String get confirmRunCommandTitle => 'Confirm command';

  @override
  String get confirmRunCommandBody => 'The following command will be executed:';

  @override
  String get copyToClipboardSuccess => 'Copied to clipboard.';

  @override
  String get noErrorOutput => 'No error output was returned.';

  @override
  String get loadErrorsTitle => 'Load error details';

  @override
  String get commandFailedTitle => 'Command failed';

  @override
  String get noOutput => 'No output.';

  @override
  String get batchPrerequisitePrompt =>
      'A dependency install command is required before batch update checks. Install it now?';

  @override
  String get batchPrerequisiteTitle => 'Dependency required';

  @override
  String get cancelRequested => 'Cancellation requested.';

  @override
  String get commandCannotCancel => 'This command cannot be cancelled.';

  @override
  String commandCancelled(String command) {
    return 'Cancelled: $command';
  }

  @override
  String runningCommandsTitle(int count) {
    return 'Running commands ($count)';
  }

  @override
  String commandQueueTitle(int runningCount, int queuedCount) {
    return 'Command queue ($runningCount running, $queuedCount queued)';
  }

  @override
  String get commandStatusQueued => 'Queued';

  @override
  String get commandCancelTooltip => 'Cancel this command';

  @override
  String get commandCancelling => 'Cancelling...';

  @override
  String get commandNotCancelable => 'Not cancelable';

  @override
  String get emptyLoadingManagers => 'Refreshing package managers...';

  @override
  String get emptyNoMatchingPackages => 'No matching packages';

  @override
  String get emptyNoEnabledManagers => 'No package managers enabled';

  @override
  String get emptyNoEnabledManagersDescription =>
      'No package managers are enabled. Choose which ones to show in Settings first.';

  @override
  String emptyManagersLoadErrorDescription(int count) {
    return '$count package managers failed to load. Open error details for the full output.';
  }

  @override
  String get emptyClickRefresh => 'Try clicking Refresh first.';

  @override
  String emptyNoSearchResult(String query) {
    return 'No results found for “$query”.';
  }

  @override
  String get homeFilterGroupAll => 'All';

  @override
  String get homeFilterGroupUpdates => 'Updates';

  @override
  String get homeFilterSummaryAll => 'Show all installed packages';

  @override
  String get homeFilterSummaryUpdates =>
      'Show only installed packages with updates';

  @override
  String homeFilterSummaryManagers(int count) {
    return '$count managers';
  }

  @override
  String homeFilterSummaryPackages(int count) {
    return '$count individual packages';
  }

  @override
  String get homeFilterSummaryUnconfigured => 'No members configured';

  @override
  String managerOriginalName(String name) {
    return 'Original name: $name';
  }

  @override
  String get managerCustomIconSet => 'Custom icon configured';

  @override
  String managerUpdatedMessage(String name, String parts) {
    return '$name updated: $parts.';
  }

  @override
  String groupAddedMessage(String name) {
    return '$name added.';
  }

  @override
  String groupDeletedMessage(String name) {
    return '$name deleted.';
  }

  @override
  String groupUpdatedMessage(String name) {
    return '$name updated.';
  }

  @override
  String get settingsManagersDescription =>
      'You can customize home filter groups. Managers that are not installed will be disabled after refresh.';

  @override
  String get groupColumn => 'Group';

  @override
  String get descriptionColumn => 'Description';

  @override
  String get enabledColumn => 'Enabled';

  @override
  String get statusColumn => 'Status';

  @override
  String get customGroupType => 'Custom';

  @override
  String get builtinGroupType => 'Built-in';

  @override
  String get groupVisibleOnHome => 'Shown on home';

  @override
  String get groupHiddenOnHome => 'Hidden on home';

  @override
  String get managerDetected => 'Detected';

  @override
  String get managerNotDetected => 'Not detected';

  @override
  String get changedDisplayName => 'display name';

  @override
  String get changedIcon => 'icon';

  @override
  String get dialogAddGroupTitle => 'Add filter group';

  @override
  String dialogEditGroupTitle(String name) {
    return 'Edit $name';
  }

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupNameHint => 'For example: Dev Tools / CLI / Favorites';

  @override
  String get iconLabel => 'Icon';

  @override
  String get iconNotSet => 'No icon selected';

  @override
  String get defaultIconLabel => 'Using default icon';

  @override
  String get iconFormatsHint => 'Supported: svg, png, jpg, jpeg, webp, ico.';

  @override
  String get includedManagersLabel => 'Included managers';

  @override
  String get includedPackagesLabel => 'Included installed packages';

  @override
  String get noLocalPackages => 'No installed packages yet';

  @override
  String get builtinAllGroupHint =>
      'This is the built-in “All” filter group. It shows every installed package.';

  @override
  String get builtinUpdatesGroupHint =>
      'This is the built-in “Updates” filter group. It shows installed packages with updates.';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get displayNameHint => 'Enter a new display name';

  @override
  String editManagerTitle(String name) {
    return 'Edit $name';
  }

  @override
  String get saveInProgress => 'Saving...';

  @override
  String get aboutTitle => 'About';

  @override
  String get versionLoading => 'Loading...';

  @override
  String get checkingUpdates => 'Checking...';

  @override
  String openLinkFailed(String url) {
    return 'Unable to open link: $url';
  }

  @override
  String checkUpdatesFailed(String message) {
    return 'Update check failed: $message';
  }

  @override
  String alreadyLatestVersion(String version) {
    return 'You\'re already on the latest version: $version';
  }

  @override
  String packageAlreadyLatest(String name) {
    return '$name is already on the latest version.';
  }

  @override
  String packageNewVersionFound(String name, String version) {
    return '$name has a new version: $version';
  }

  @override
  String packageCheckFailed(String name, String message) {
    return 'Failed to check $name: $message';
  }

  @override
  String packageCheckFailedFallback(String name) {
    return 'Failed to check $name. Check the activity log for details.';
  }

  @override
  String get releaseAssetInstaller => 'Installer';

  @override
  String get releaseAssetPortable => 'Portable';

  @override
  String get releaseAssetOther => 'Asset';

  @override
  String get unknownSize => 'Unknown size';

  @override
  String get downloadPreparing => 'Preparing download...';

  @override
  String downloadedBytes(String received) {
    return 'Downloaded $received';
  }

  @override
  String downloadedProgress(String received, String total, String percent) {
    return 'Downloaded $received / $total · $percent%';
  }

  @override
  String get autoCheckDisabled => 'Automatic update checks disabled.';

  @override
  String disableAutoCheckFailed(String message) {
    return 'Failed to disable: $message';
  }

  @override
  String get installerStarted => 'Installer started.';

  @override
  String get installerDownloadedNotStarted =>
      'Installer downloaded, but it could not be started automatically.';

  @override
  String get downloadedAndOpenedFolder =>
      'Downloaded and opened containing folder.';

  @override
  String get downloadCompleted => 'Download completed.';

  @override
  String downloadFailed(String message) {
    return 'Download failed: $message';
  }

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String versionTransition(String current, String latest) {
    return 'Current $current  ->  Latest $latest';
  }

  @override
  String get releaseNotesTitle => 'Release notes';

  @override
  String get releaseNotesEmpty =>
      'This release does not include release notes.';

  @override
  String get releaseAssetsEmpty =>
      'No release assets were loaded. Open the release page to inspect them.';

  @override
  String get releaseAssetsTitle => 'Available assets';

  @override
  String get processing => 'Processing...';

  @override
  String get disableAutoCheckButton => 'Disable automatic update checks';

  @override
  String get installPageEmptyHint =>
      'Enter a keyword to search installable packages.';

  @override
  String get searching => 'Searching...';

  @override
  String get allLabel => 'All';

  @override
  String packageAlreadyInstalled(String manager) {
    return '$manager · installed';
  }

  @override
  String installWithManager(String manager) {
    return 'Install with $manager';
  }

  @override
  String installSpecificVersionWithManager(String manager) {
    return 'Install a specific version with $manager';
  }

  @override
  String managerInstalling(String manager) {
    return '$manager installing';
  }

  @override
  String managerInstalled(String manager) {
    return '$manager installed';
  }

  @override
  String installDialogVersionSelected(String version) {
    return 'The selected version to install is $version.';
  }

  @override
  String get installDialogLatestSelected =>
      'The command will explicitly install @latest.';

  @override
  String get installDialogDefaultSelected =>
      'The default install command will be used.';

  @override
  String get installLatestTitle => 'Install latest';

  @override
  String get installLatestSubtitle => 'Install using the @latest tag';

  @override
  String get versionSearchHint =>
      'Type a version to filter quickly, for example 1.2.3';

  @override
  String get pendingCommandLabel => 'Command to run';

  @override
  String loadVersionListFailed(String message) {
    return 'Failed to load version list: $message';
  }

  @override
  String get noAvailableVersionList =>
      'This command did not return any available versions.';

  @override
  String availableVersionListCount(int count) {
    return '$count available versions';
  }

  @override
  String availableVersionListTruncated(int count, int max) {
    return '$count versions available. Only the latest $max are shown. Type a version to narrow the list.';
  }

  @override
  String availableVersionListTruncatedFiltered(int count, int max) {
    return '$count versions match. Only the first $max are shown. Keep typing to narrow the list.';
  }

  @override
  String get noDisplayableVersions => 'No versions to display.';

  @override
  String get noMatchedVersionsUseTypedValue =>
      'No matching versions. Confirming will use the version typed in the input field.';

  @override
  String get specificVersionDialogTitle => 'Install a specific version';

  @override
  String get specificVersionDialogDescription =>
      'Select an available version, or type a version to install directly.';

  @override
  String get noMatchedVersionsCanInstallTyped =>
      'No matching versions. You can still install the typed value with the button below.';

  @override
  String currentVersionValue(String version) {
    return 'Current $version';
  }

  @override
  String latestVersionValue(String version) {
    return 'Latest $version';
  }

  @override
  String versionValue(String version) {
    return 'Version $version';
  }

  @override
  String multiManagerCount(int count) {
    return '$count managers';
  }

  @override
  String identifierValue(String identifier) {
    return 'Identifier: $identifier';
  }

  @override
  String installedManagersValue(String managers) {
    return 'Installed: $managers';
  }

  @override
  String lastCheckedAtValue(String value) {
    return 'Last checked $value';
  }
}
