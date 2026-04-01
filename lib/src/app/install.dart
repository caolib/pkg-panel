part of '../app.dart';

class PackageInstallPage extends StatefulWidget {
  const PackageInstallPage({super.key, required this.controller});

  final PackagePanelController controller;

  @override
  State<PackageInstallPage> createState() => _PackageInstallPageState();
}

class _PackageInstallPageState extends State<PackageInstallPage> {
  late final TextEditingController _searchController;
  String? _selectedSearchFilterId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.installSearchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    await widget.controller.searchPackages(
      managerId: _selectedSearchFilterId,
      query: _searchController.text,
    );
  }

  Future<void> _runCommandWithFeedback(PackageCommand command) async {
    final result = await widget.controller.runCommand(command);
    if (!mounted) {
      return;
    }

    _showCompactSnackBar(
      context,
      result.wasCancelled
          ? context.l10n.commandCancelled(command.command)
          : command.command,
    );

    if (!result.isSuccess && !result.wasCancelled) {
      await showDialog<void>(
        context: context,
        builder: (context) => _CommandOutputDialog(
          title: context.l10n.commandFailedTitle,
          output: result.combinedOutput.isEmpty
              ? context.l10n.noOutput
              : result.combinedOutput,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final filterIds = widget.controller.installSearchFilterIds;
        final results = widget.controller.searchResults
            .where(
              (item) => widget.controller.searchResultMatchesFilter(
                item,
                _selectedSearchFilterId,
              ),
            )
            .toList(growable: false);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SearchBar(
                        controller: _searchController,
                        constraints: const BoxConstraints(
                          minHeight: 44,
                          maxHeight: 44,
                        ),
                        hintText: l10n.searchInstallHint,
                        leading: const Icon(Icons.search),
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: widget.controller.isSearchingPackages
                        ? null
                        : _runSearch,
                    icon: widget.controller.isSearchingPackages
                        ? const _BusyIndicator(size: 16)
                        : const Icon(Icons.travel_explore_outlined),
                    label: Text(l10n.buttonSearch),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilterChip(
                      selected: _selectedSearchFilterId == null,
                      showCheckmark: false,
                      label: Text(l10n.allLabel),
                      onSelected: (_) {
                        setState(() => _selectedSearchFilterId = null);
                      },
                    ),
                    ...filterIds.map((filterId) {
                      final managerIds = widget.controller
                          .installSearchFilterManagerIds(filterId);
                      final representativeManagerId = widget.controller
                          .installSearchFilterRepresentativeManagerId(filterId);
                      final showIconCluster = managerIds.length > 1;
                      const clusterLabel = 'npm';
                      return FilterChip(
                        selected: _selectedSearchFilterId == filterId,
                        showCheckmark: false,
                        avatar:
                            showIconCluster || representativeManagerId == null
                            ? null
                            : _ManagerIcon(
                                managerId: representativeManagerId,
                                customIconPath: widget.controller
                                    .customManagerIconPath(
                                      representativeManagerId,
                                    ),
                                fallbackIcon: _managerIcon(
                                  representativeManagerId,
                                ),
                                fallbackColor: _managerAccent(
                                  representativeManagerId,
                                ),
                              ),
                        label: showIconCluster
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  ...managerIds.map(
                                    (managerId) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: _ManagerIcon(
                                        managerId: managerId,
                                        customIconPath: widget.controller
                                            .customManagerIconPath(managerId),
                                        fallbackIcon: _managerIcon(managerId),
                                        fallbackColor: _managerAccent(
                                          managerId,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(clusterLabel),
                                ],
                              )
                            : Text(
                                widget.controller.installSearchFilterLabel(
                                  filterId,
                                ),
                              ),
                        onSelected: (_) {
                          setState(() {
                            _selectedSearchFilterId = filterId;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final borderRadius = BorderRadius.circular(18);
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: results.isEmpty
                          ? _InstallSearchEmpty(
                              isSearching:
                                  widget.controller.isSearchingPackages,
                            )
                          : Column(
                              children: <Widget>[
                                _SearchPackageHeaderRow(
                                  compact: compact,
                                  count: results.length,
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: results.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                    itemBuilder: (context, index) {
                                      return _SearchPackageListTile(
                                        package: results[index],
                                        controller: widget.controller,
                                        compact: compact,
                                        onInstall: _runCommandWithFeedback,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InstallSearchEmpty extends StatelessWidget {
  const _InstallSearchEmpty({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        isSearching
            ? context.l10n.searching
            : context.l10n.installPageEmptyHint,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SearchPackageHeaderRow extends StatelessWidget {
  const _SearchPackageHeaderRow({required this.compact, required this.count});

  final bool compact;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: compact
          ? Row(
              children: <Widget>[
                Text(l10n.searchResultsHeader, style: style),
                const Spacer(),
                Text(l10n.countLabel(count), style: style),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: Text(l10n.packageNameColumn, style: style),
                ),
                Expanded(
                  flex: 2,
                  child: Text(l10n.versionColumn, style: style),
                ),
                Expanded(flex: 3, child: Text(l10n.sourceColumn, style: style)),
                Expanded(
                  flex: 5,
                  child: Text(l10n.extraInfoColumn, style: style),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(l10n.packageManagerColumn, style: style),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SearchPackageListTile extends StatelessWidget {
  const _SearchPackageListTile({
    required this.package,
    required this.controller,
    required this.compact,
    required this.onInstall,
  });

  final SearchPackage package;
  final PackagePanelController controller;
  final bool compact;
  final Future<void> Function(PackageCommand command) onInstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final managerSummary = _searchPackageManagerSummary(
      context,
      package,
      controller,
    );
    final source = _searchPackageSourceLine(package);
    final extra = _searchPackageExtraLine(context, package);
    final icons = _searchManagerIcons(context);

    final rowContent = compact
        ? Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      package.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _searchPackageCompactSummaryLine(
                        context,
                        package,
                        managerSummary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (extra.isNotEmpty)
                      Text(
                        extra,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(spacing: 6, runSpacing: 6, children: icons),
            ],
          )
        : Row(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Text(
                  package.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  package.version ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  extra.isEmpty ? '-' : extra,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: icons,
                  ),
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onSecondaryTapUp: (details) =>
              _showInstallMenu(context, details.globalPosition),
          child: Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(8, 6, 8, 6)
                : const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: rowContent,
          ),
        ),
      ),
    );
  }

  List<Widget> _searchManagerIcons(BuildContext context) {
    return package.installOptions
        .map(
          (option) => Tooltip(
            message: option.isInstalled
                ? context.l10n.packageAlreadyInstalled(
                    controller.displayNameForManagerId(option.managerId),
                  )
                : controller.displayNameForManagerId(option.managerId),
            child: _ManagerIcon(
              managerId: option.managerId,
              customIconPath: controller.customManagerIconPath(
                option.managerId,
              ),
              fallbackIcon: _managerIcon(option.managerId),
              fallbackColor: _managerAccent(option.managerId),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _showInstallMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final l10n = context.l10n;
    final items = package.installOptions
        .map((option) {
          final label = controller.displayNameForManagerId(option.managerId);
          final isInstalling = controller.isInstallingSearchOption(option);
          final canInstallSpecificVersion = controller
              .canInstallSpecificVersion(option);
          final canInstall = controller.installCommandFor(option) != null;
          final canOpenInstalledAction =
              option.isInstalled && canInstallSpecificVersion;
          final enabled =
              !isInstalling &&
              ((!option.isInstalled && canInstall) || canOpenInstalledAction);
          return _ContextMenuActionItem(
            leading: _ManagerIcon(
              managerId: option.managerId,
              customIconPath: controller.customManagerIconPath(
                option.managerId,
              ),
              fallbackIcon: _managerIcon(option.managerId),
              fallbackColor: _managerAccent(option.managerId),
            ),
            label: option.isInstalled
                ? canInstallSpecificVersion
                      ? l10n.installSpecificVersionWithManager(label)
                      : l10n.managerInstalled(label)
                : isInstalling
                ? l10n.managerInstalling(label)
                : l10n.installWithManager(label),
            enabled: enabled,
            onPressed: !enabled
                ? null
                : () => _showInstallOptionsDialog(
                    context: context,
                    controller: controller,
                    option: option,
                    startWithVersionSearch: canOpenInstalledAction,
                    onInstall: onInstall,
                  ),
          );
        })
        .toList(growable: false);

    _DesktopContextMenu.show(
      context: context,
      globalPosition: globalPosition,
      items: items,
    );
  }
}

SearchPackageInstallOption _installOptionFromManagedPackage(
  ManagedPackage package,
) {
  return SearchPackageInstallOption(
    managerId: package.managerId,
    managerName: package.managerName,
    packageName: package.name,
    identifier: package.identifier,
    version: package.version,
    source: package.source,
    isInstalled: true,
  );
}

String _compactSummaryLine(BuildContext context, ManagedPackage package) {
  final parts = <String>[
    context.l10n.currentVersionValue(package.version),
    if (package.latestVersion != null)
      context.l10n.latestVersionValue(package.latestVersion!),
  ];
  return parts.join(' · ');
}

String _searchPackageCompactSummaryLine(
  BuildContext context,
  SearchPackage package,
  String managerSummary,
) {
  final parts = <String>[
    managerSummary,
    if ((package.version ?? '').isNotEmpty)
      context.l10n.versionValue(package.version!),
    if (_searchPackageSourceLine(package).isNotEmpty)
      _searchPackageSourceLine(package),
  ];
  return parts.join(' · ');
}

String _searchPackageSourceLine(SearchPackage package) {
  final source = package.source?.trim();
  if (source == null || source.isEmpty) {
    return '';
  }
  return source;
}

String _searchPackageManagerSummary(
  BuildContext context,
  SearchPackage package,
  PackagePanelController controller,
) {
  if (package.installOptions.isEmpty) {
    return controller.displayNameForManagerId(package.managerId);
  }
  if (package.installOptions.length == 1) {
    return controller.displayNameForManagerId(
      package.installOptions.first.managerId,
    );
  }
  return context.l10n.multiManagerCount(package.installOptions.length);
}

String _searchPackageExtraLine(BuildContext context, SearchPackage package) {
  final installedManagers = package.installOptions
      .where((option) => option.isInstalled)
      .map((option) => option.managerName)
      .toList(growable: false);
  final parts = <String>[
    if (package.description != null && package.description!.trim().isNotEmpty)
      package.description!,
    if (package.identifier != null &&
        package.identifier!.trim().isNotEmpty &&
        package.identifier != package.name)
      context.l10n.identifierValue(package.identifier!),
    if (installedManagers.isNotEmpty)
      context.l10n.installedManagersValue(installedManagers.join(', ')),
  ];
  return parts.join(' · ');
}

String _extraLine(BuildContext context, ManagedPackage package) {
  final parts = <String>[
    if (package.notes != null && package.notes!.trim().isNotEmpty)
      package.notes!,
    if (package.latestVersionCheckedAt != null)
      context.l10n.lastCheckedAtValue(
        _formatCheckedAt(package.latestVersionCheckedAt!),
      ),
  ];
  return parts.join(' · ');
}

String _formatCheckedAt(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

bool _isRangeSelectionPressed() {
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  return keys.contains(LogicalKeyboardKey.shiftLeft) ||
      keys.contains(LogicalKeyboardKey.shiftRight);
}

bool _isAdditiveSelectionPressed() {
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  return keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight) ||
      keys.contains(LogicalKeyboardKey.metaLeft) ||
      keys.contains(LogicalKeyboardKey.metaRight);
}

Color _managerAccent(String managerId) {
  return switch (managerId) {
    'winget' => const Color(0xFF2563EB),
    'choco' => const Color(0xFF7A3E1D),
    'scoop' => const Color(0xFF16A34A),
    'npm' => const Color(0xFFE4572E),
    'pnpm' => const Color(0xFFF59E0B),
    'yarn' => const Color(0xFF2C8EBB),
    'bun' => const Color(0xFFEAB308),
    'pip' => const Color(0xFF4B7BEC),
    'uv' => const Color(0xFF14B8A6),
    'cargo' => const Color(0xFFB45309),
    _ => const Color(0xFF64748B),
  };
}

IconData _managerIcon(String managerId) {
  return switch (managerId) {
    'winget' => Icons.window_outlined,
    'choco' => Icons.local_cafe_outlined,
    'scoop' => Icons.inventory_2_outlined,
    'npm' => Icons.hub_outlined,
    'pnpm' => Icons.account_tree_outlined,
    'yarn' => Icons.change_history_outlined,
    'bun' => Icons.bubble_chart_outlined,
    'pip' => Icons.science_outlined,
    'uv' => Icons.flash_on_outlined,
    'cargo' => Icons.precision_manufacturing_outlined,
    _ => Icons.widgets_outlined,
  };
}

String? _managerSvgAsset(String managerId) {
  return _managerIconAssets[managerId];
}

const Map<String, String> _managerIconAssets = <String, String>{
  'bun': 'assets/package_icons/bun.png',
  'cargo': 'assets/package_icons/cargo.png',
  'choco': 'assets/package_icons/chocolatey.png',
  'npm': 'assets/package_icons/npm.png',
  'pip': 'assets/package_icons/python.png',
  'pnpm': 'assets/package_icons/pnpm.png',
  'uv': 'assets/package_icons/uv.png',
  'winget': 'assets/package_icons/winget.ico',
  'yarn': 'assets/package_icons/yarn.png',
};
