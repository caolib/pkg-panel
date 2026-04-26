part of '../app.dart';

class PackagePanelHome extends StatefulWidget {
  const PackagePanelHome({
    super.key,
    required this.controller,
    required this.autoLoad,
  });

  final PackagePanelController controller;
  final bool autoLoad;

  @override
  State<PackagePanelHome> createState() => _PackagePanelHomeState();
}

class _PackagePanelHomeState extends State<PackagePanelHome>
    with TickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TabController _tabController;
  late final TabController _settingsTabController;
  int _currentTabIndex = 0;
  int _currentSettingsTabIndex = 0;
  bool _hasQueuedStartupUpdateCheck = false;
  bool _isRunningCommandToastCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _settingsTabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelectionChanged);
    _settingsTabController.addListener(_handleSettingsTabSelectionChanged);
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );

    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.ensureLoaded();
        _queueStartupUpdateCheck();
      });
    }
  }

  void _queueStartupUpdateCheck() {
    if (_hasQueuedStartupUpdateCheck ||
        !widget.controller.autoCheckAppUpdates) {
      return;
    }
    _hasQueuedStartupUpdateCheck = true;
    unawaited(
      _checkForAppUpdateWithUi(
        context,
        widget.controller,
        showAlreadyLatestMessage: false,
        showErrorMessage: false,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelectionChanged);
    _settingsTabController.removeListener(_handleSettingsTabSelectionChanged);
    _tabController.dispose();
    _settingsTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabSelectionChanged() {
    if (_currentTabIndex == _tabController.index || !mounted) {
      return;
    }
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  void _handleSettingsTabSelectionChanged() {
    if (_currentSettingsTabIndex == _settingsTabController.index || !mounted) {
      return;
    }
    setState(() {
      _currentSettingsTabIndex = _settingsTabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildNavigationRow(context),
                  const SizedBox(height: 16),
                  Expanded(child: _buildCurrentTabBody()),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final runningCommands = widget.controller.runningCommands;
                if (runningCommands.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  right: 24,
                  bottom: 24,
                  child: _RunningCommandToast(
                    commands: runningCommands,
                    collapsed: _isRunningCommandToastCollapsed,
                    onToggleCollapsed: () {
                      setState(() {
                        _isRunningCommandToastCollapsed =
                            !_isRunningCommandToastCollapsed;
                      });
                    },
                    onCancelCommand: (command) =>
                        unawaited(_cancelRunningCommand(command)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabBody() {
    return switch (_currentTabIndex) {
      1 => PackageInstallPage(controller: widget.controller),
      2 => PackageSettingsPage(
        controller: widget.controller,
        settingsTabController: _settingsTabController,
      ),
      _ => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ActionBar(
                controller: widget.controller,
                searchController: _searchController,
                onRefreshAll: widget.controller.refreshCurrentSelection,
                onBatchCheckLatest: _handleBatchCheckLatestForSelectedManager,
                onShowLoadErrors: _showLoadErrorsDialog,
                onBatchUpdate: () async {
                  final command = widget.controller
                      .batchUpdateCommandForSelectedManager();
                  if (command == null) {
                    return;
                  }
                  await _confirmAndRunCommand(command);
                },
              ),
              const SizedBox(height: 14),
              _ManagerFilterBar(controller: widget.controller),
              const SizedBox(height: 16),
              Expanded(
                child: _PackageListView(
                  controller: widget.controller,
                  onOpenSettings: _openSettings,
                  onShowLoadErrors: _showLoadErrorsDialog,
                  onRunAction: _confirmAndRunCommand,
                ),
              ),
            ],
          );
        },
      ),
    };
  }

  Widget _buildNavigationRow(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _tabController,
        _settingsTabController,
      ]),
      builder: (context, _) {
        final showSettingsSubTabs = _currentTabIndex == 2;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                tabs: <Widget>[
                  Tab(text: l10n.tabLocal),
                  Tab(text: l10n.tabInstall),
                  Tab(text: l10n.tabSettings),
                ],
              ),
              if (showSettingsSubTabs) ...<Widget>[
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: theme.colorScheme.outlineVariant,
                ),
                TabBar(
                  controller: _settingsTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                  tabs: <Widget>[
                    Tab(text: l10n.settingsTabGeneral),
                    Tab(text: l10n.settingsTabManagers),
                    Tab(text: l10n.settingsTabAppearance),
                    Tab(text: l10n.settingsTabAbout),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancelRunningCommand(RunningCommandInfo command) async {
    final cancelled = await widget.controller.cancelRunningCommand(
      command.busyKey,
    );
    if (!mounted || !cancelled) {
      return;
    }

    _showCompactSnackBar(context, context.l10n.cancelRequested);
  }

  Future<void> _confirmAndRunCommand(PackageCommand command) async {
    final shouldRun =
        await showDialog<bool>(
          context: context,
          builder: (context) => _CommandDialog(command: command),
        ) ??
        false;
    if (!shouldRun || !mounted) {
      return;
    }

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

  Future<void> _handleBatchCheckLatestForSelectedManager() async {
    final selectedGroup = widget.controller.selectedHomeFilterGroup;
    if (selectedGroup == null) {
      final prerequisiteCommand = await widget.controller
          .batchLatestVersionPrerequisiteCommandForSelectedManager();
      if (!mounted) {
        return;
      }

      if (prerequisiteCommand != null) {
        final prompt =
            widget.controller
                .batchLatestVersionPrerequisitePromptForSelectedManager() ??
            context.l10n.batchPrerequisitePrompt;
        final shouldInstall =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.l10n.batchPrerequisiteTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(prompt),
                    const SizedBox(height: 12),
                    _CommandPreview(command: prerequisiteCommand.command),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.l10n.buttonCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.l10n.buttonInstall),
                  ),
                ],
              ),
            ) ??
            false;
        if (!shouldInstall || !mounted) {
          return;
        }

        final result = await widget.controller.runCommand(prerequisiteCommand);
        if (!mounted) {
          return;
        }
        _showCompactSnackBar(
          context,
          result.wasCancelled
              ? context.l10n.commandCancelled(prerequisiteCommand.command)
              : prerequisiteCommand.command,
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
          return;
        }
      }
    }

    await widget.controller.batchCheckLatestVersionsForCurrentSelection();
  }

  Future<void> _openSettings() async {
    if (_tabController.index == 2) {
      return;
    }
    _tabController.animateTo(2, duration: Duration.zero);
  }

  Future<void> _showLoadErrorsDialog() async {
    final output = _buildLoadErrorOutput(context, widget.controller);
    if (output == null || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => _CommandOutputDialog(
        title: context.l10n.loadErrorsTitle,
        output: output,
      ),
    );
  }
}

class _RunningCommandToast extends StatelessWidget {
  const _RunningCommandToast({
    required this.commands,
    required this.collapsed,
    this.onToggleCollapsed,
    this.onCancelCommand,
  });

  final List<RunningCommandInfo> commands;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;
  final void Function(RunningCommandInfo command)? onCancelCommand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final queuedCount = commands
        .where((command) => _isQueuedStatus(command.statusLabel))
        .length;
    final runningCount = commands.length - queuedCount;
    final title = queuedCount == 0
        ? l10n.runningCommandsTitle(runningCount)
        : l10n.commandQueueTitle(runningCount, queuedCount);
    final titleStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final toggleButton = IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onToggleCollapsed,
      icon: Icon(collapsed ? Icons.unfold_more : Icons.unfold_less),
    );
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: collapsed
              ? const BoxConstraints(maxWidth: 320)
              : const BoxConstraints(maxWidth: 520, maxHeight: 360),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 14 : 16,
            vertical: collapsed ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(24),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.terminal,
                      size: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  toggleButton,
                ],
              ),
              if (!collapsed) ...<Widget>[
                const SizedBox(height: 6),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final command in commands)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Tooltip(
                                      message: command.command,
                                      waitDuration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: Text(
                                        command.command,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Cascadia Code',
                                          fontFamilyFallback: theme
                                              .textTheme
                                              .bodyMedium
                                              ?.fontFamilyFallback,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (command.canCancel)
                                    command.isCancelling
                                        ? const _BusyIndicator(size: 18)
                                        : IconButton(
                                            tooltip: l10n.commandCancelTooltip,
                                            onPressed: () =>
                                                onCancelCommand?.call(command),
                                            icon: const Icon(
                                              Icons.stop_circle_outlined,
                                            ),
                                          )
                                  else
                                    Text(
                                      _localizedCommandStatus(context, command),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.controller,
    required this.searchController,
    required this.onRefreshAll,
    required this.onBatchCheckLatest,
    required this.onShowLoadErrors,
    required this.onBatchUpdate,
  });

  final PackagePanelController controller;
  final TextEditingController searchController;
  final Future<void> Function() onRefreshAll;
  final Future<void> Function() onBatchCheckLatest;
  final Future<void> Function() onShowLoadErrors;
  final Future<void> Function() onBatchUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final batchCommand = controller.batchUpdateCommandForSelectedManager();
    final canBatchCheckLatest =
        controller.canBatchCheckLatestForCurrentSelection;
    final isBatchCheckingLatest =
        controller.isBatchCheckingLatestForCurrentSelection;
    final hasLoadErrors = controller.errorManagers > 0;
    final visibleCount = controller.visiblePackages.length;
    final showBatchUpdate =
        controller.selectedPackageCount > 1 && batchCommand != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 320,
              child: SearchBar(
                controller: searchController,
                constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
                hintText: l10n.searchLocalHint,
                leading: const Icon(Icons.search),
                onChanged: controller.setSearchQuery,
                trailing: <Widget>[
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: l10n.clearTooltip,
                      onPressed: () {
                        searchController.clear();
                        controller.setSearchQuery('');
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: controller.isRefreshingCurrentSelection
                  ? null
                  : onRefreshAll,
              icon: controller.isRefreshingCurrentSelection
                  ? const _BusyIndicator(size: 16)
                  : const Icon(Icons.sync),
              label: Text(l10n.buttonRefresh),
            ),
            if (hasLoadErrors)
              FilledButton.tonalIcon(
                onPressed: onShowLoadErrors,
                icon: const Icon(Icons.error_outline),
                label: Text(
                  l10n.viewLoadErrorsButton(controller.errorManagers),
                ),
              ),
            if (canBatchCheckLatest)
              FilledButton.tonalIcon(
                onPressed: isBatchCheckingLatest ? null : onBatchCheckLatest,
                icon: isBatchCheckingLatest
                    ? const _BusyIndicator(size: 16)
                    : const Icon(Icons.find_replace_outlined),
                label: Text(l10n.buttonCheckUpdates),
              ),
            if (showBatchUpdate)
              FilledButton.tonalIcon(
                onPressed: controller.isBusy(batchCommand.busyKey)
                    ? null
                    : onBatchUpdate,
                icon: const Icon(Icons.system_update_alt),
                label: Text(l10n.buttonBatchUpdate),
              ),
            Chip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text(l10n.visiblePackageCount(visibleCount)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerFilterBar extends StatelessWidget {
  const _ManagerFilterBar({required this.controller});

  final PackagePanelController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        ...controller.visibleHomeFilterGroups.map((group) {
          final iconPath = controller.iconPathForHomeFilterGroup(group.id);
          final avatar = iconPath == null
              ? null
              : _ManagerIcon(
                  managerId: group.id,
                  customIconPath: iconPath,
                  fallbackIcon: Icons.filter_alt_outlined,
                  fallbackColor: Theme.of(context).colorScheme.primary,
                  showFallbackWhenNoAsset: false,
                );
          return FilterChip(
            selected: group.id == allFilterId
                ? controller.selectedManagerId == null
                : controller.selectedManagerId == group.id,
            showCheckmark: false,
            label: Text(_homeFilterGroupDisplayName(context, group)),
            avatar: avatar,
            onSelected: (_) => controller.selectManager(group.id),
          );
        }),
        ...controller.visibleSnapshots.map((snapshot) {
          final label = switch (snapshot.loadState) {
            ManagerLoadState.error => l10n.managerLoadFailedSuffix(
              controller.displayNameForManagerId(snapshot.manager.id),
            ),
            ManagerLoadState.loading => controller.displayNameForManagerId(
              snapshot.manager.id,
            ),
            _ => controller.displayNameForManagerId(snapshot.manager.id),
          };
          return FilterChip(
            selected: controller.selectedManagerId == snapshot.manager.id,
            showCheckmark: false,
            label: Text(label),
            avatar: _ManagerIcon(
              managerId: snapshot.manager.id,
              customIconPath: controller.customManagerIconPath(
                snapshot.manager.id,
              ),
              fallbackIcon: snapshot.manager.icon,
              fallbackColor: snapshot.manager.color,
            ),
            onSelected: (_) => controller.selectManager(snapshot.manager.id),
          );
        }),
      ],
    );
  }
}

class _PackageListView extends StatelessWidget {
  const _PackageListView({
    required this.controller,
    required this.onRunAction,
    required this.onOpenSettings,
    required this.onShowLoadErrors,
  });

  final PackagePanelController controller;
  final Future<void> Function(PackageCommand command) onRunAction;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onShowLoadErrors;

  @override
  Widget build(BuildContext context) {
    final packages = controller.visiblePackages;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final theme = Theme.of(context);
        final borderRadius = BorderRadius.circular(18);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: borderRadius,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: packages.isEmpty
              ? _EmptyPackages(
                  hasManagersLoading: controller.isRefreshingCurrentSelection,
                  hasVisibleManagers: controller.hasVisibleLocalManagers,
                  errorManagerCount: controller.errorManagers,
                  onOpenSettings: onOpenSettings,
                  onShowLoadErrors: onShowLoadErrors,
                  searchQuery: controller.searchQuery,
                )
              : Column(
                  children: <Widget>[
                    _PackageHeaderRow(
                      compact: compact,
                      count: packages.length,
                      selectedCount: controller.selectedPackageCount,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: packages.length,
                        itemBuilder: (context, index) {
                          final package = packages[index];
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              border: index == packages.length - 1
                                  ? null
                                  : Border(
                                      bottom: BorderSide(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                    ),
                            ),
                            child: _PackageListTile(
                              package: package,
                              controller: controller,
                              onRunAction: onRunAction,
                              compact: compact,
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

class _PackageHeaderRow extends StatelessWidget {
  const _PackageHeaderRow({
    required this.compact,
    required this.count,
    required this.selectedCount,
  });

  final bool compact;
  final int count;
  final int selectedCount;

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
                Text(l10n.packageListHeader, style: style),
                const Spacer(),
                Text(
                  selectedCount > 1
                      ? l10n.countSelectedLabel(count, selectedCount)
                      : l10n.countLabel(count),
                  style: style,
                ),
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
                  child: Text(l10n.currentVersionColumn, style: style),
                ),
                Expanded(
                  flex: 2,
                  child: Text(l10n.latestVersionColumn, style: style),
                ),
                Expanded(
                  flex: 8,
                  child: Text(l10n.extraInfoColumn, style: style),
                ),
              ],
            ),
    );
  }
}

class _PackageListTile extends StatelessWidget {
  const _PackageListTile({
    required this.package,
    required this.controller,
    required this.onRunAction,
    required this.compact,
  });

  final ManagedPackage package;
  final PackagePanelController controller;
  final Future<void> Function(PackageCommand command) onRunAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tileState = _PackageTileState.fromController(
      controller: controller,
      package: package,
    );
    final theme = Theme.of(context);
    final extra = _extraLine(context, package);
    final rowContent = compact
        ? Row(
            children: <Widget>[
              _ManagerIcon(
                managerId: package.managerId,
                customIconPath: tileState.iconPath,
                fallbackIcon: _managerIcon(package.managerId),
                fallbackColor: tileState.accent,
              ),
              const SizedBox(width: 10),
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
                      _compactSummaryLine(context, package),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (extra.isNotEmpty)
                      Text(
                        extra,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          )
        : Row(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Row(
                  children: <Widget>[
                    _ManagerIcon(
                      managerId: package.managerId,
                      customIconPath: tileState.iconPath,
                      fallbackIcon: _managerIcon(package.managerId),
                      fallbackColor: tileState.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        package.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  package.version,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  package.latestVersion ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: package.hasUpdate ? theme.colorScheme.primary : null,
                    fontWeight: package.hasUpdate
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              Expanded(
                flex: 8,
                child: Text(
                  extra.isEmpty ? '-' : extra,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
    final innerPadding = compact
        ? const EdgeInsets.fromLTRB(16, 10, 16, 10)
        : const EdgeInsets.fromLTRB(16, 8, 16, 8);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        controller.selectPackage(
          package,
          additive: _isAdditiveSelectionPressed(),
          range: _isRangeSelectionPressed(),
        );
      },
      onDoubleTap: tileState.canViewDetails && !tileState.isLoadingDetails
          ? () => _openPackageDetails(context)
          : null,
      onSecondaryTapUp: (details) => _showContextMenu(
        context,
        details.globalPosition,
        canViewDetails: tileState.canViewDetails,
        canCheckLatest: tileState.canCheckLatest,
        isLoadingDetails: tileState.isLoadingDetails,
        isCheckingLatest: tileState.isCheckingLatest,
        isUpdating: tileState.isUpdating,
        isRemoving: tileState.isRemoving,
        canInstallSpecificVersion: tileState.canInstallSpecificVersion,
        isInstallingSpecificVersion: tileState.isInstallingSpecificVersion,
        versionInstallOption: tileState.versionInstallOption,
        updateCommand: tileState.updateCommand,
        removeCommand: tileState.removeCommand,
      ),
      child: ColoredBox(
        color: tileState.isSelected
            ? theme.colorScheme.primary.withAlpha(36)
            : Colors.transparent,
        child: Padding(padding: innerPadding, child: rowContent),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition, {
    required bool canCheckLatest,
    required bool canViewDetails,
    required bool isCheckingLatest,
    required bool isLoadingDetails,
    required bool isUpdating,
    required bool isRemoving,
    required bool canInstallSpecificVersion,
    required bool isInstallingSpecificVersion,
    required SearchPackageInstallOption versionInstallOption,
    required PackageCommand? updateCommand,
    required PackageCommand? removeCommand,
  }) async {
    final l10n = context.l10n;
    controller.selectPackageForContextMenu(package);

    final items = <_ContextMenuActionItem>[
      if (canViewDetails)
        _ContextMenuActionItem(
          icon: Icons.info_outline,
          label: l10n.viewDetailsAction,
          enabled: !isLoadingDetails,
          onPressed: () => _openPackageDetails(context),
        ),
      if (canCheckLatest)
        _ContextMenuActionItem(
          icon: Icons.find_replace_outlined,
          label: l10n.checkUpdatesAction,
          enabled: !isCheckingLatest,
          onPressed: () async {
            final latestVersion = await controller.checkLatestVersion(package);
            if (!context.mounted) {
              return;
            }
            if (latestVersion != null) {
              final isLatest = latestVersion.trim() == package.version.trim();
              _showCompactSnackBar(
                context,
                isLatest
                    ? context.l10n.packageAlreadyLatest(package.name)
                    : context.l10n.packageNewVersionFound(
                        package.name,
                        latestVersion,
                      ),
              );
            } else {
              final recentError = controller.activity
                  .where((entry) => entry.isError)
                  .cast<ActivityEntry?>()
                  .firstWhere(
                    (entry) =>
                        entry != null &&
                        entry.title.contains(package.name) &&
                        entry.title.contains('失败'),
                    orElse: () => null,
                  );
              _showCompactSnackBar(
                context,
                recentError != null
                    ? context.l10n.packageCheckFailed(
                        package.name,
                        recentError.message,
                      )
                    : context.l10n.packageCheckFailedFallback(package.name),
              );
            }
          },
        ),
      if (updateCommand != null)
        _ContextMenuActionItem(
          icon: Icons.system_update_alt,
          label: package.hasUpdate ? l10n.upgradeAction : l10n.updateAction,
          enabled: !isUpdating,
          onPressed: () => onRunAction(updateCommand),
        ),
      if (canInstallSpecificVersion)
        _ContextMenuActionItem(
          icon: Icons.pin_outlined,
          label: l10n.installSpecificVersionAction,
          enabled: !isInstallingSpecificVersion,
          onPressed: () => _showSpecificVersionInstallDialog(
            context: context,
            controller: controller,
            option: versionInstallOption,
            onInstall: onRunAction,
          ),
        ),
      if (removeCommand != null)
        _ContextMenuActionItem(
          icon: Icons.delete_outline,
          label: l10n.removeAction,
          enabled: !isRemoving,
          onPressed: () => onRunAction(removeCommand),
        ),
    ];

    _DesktopContextMenu.show(
      context: context,
      globalPosition: globalPosition,
      items: items,
    );
  }

  Future<void> _openPackageDetails(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PackageDetailsDialog(
        packageName: package.name,
        managerName: controller.displayNameForPackage(package),
        detailsLoader: () => controller.loadPackageDetails(package),
      ),
    );
  }
}

class _ContextMenuItemLabel extends StatelessWidget {
  const _ContextMenuItemLabel({
    this.icon,
    this.leading,
    required this.label,
    this.foregroundColor,
  }) : assert(icon != null || leading != null);

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        leading ?? Icon(icon, size: 18, color: foregroundColor),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _ContextMenuActionItem {
  const _ContextMenuActionItem({
    required this.label,
    this.icon,
    this.leading,
    this.enabled = true,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final Widget? leading;
  final bool enabled;
  final Future<void> Function()? onPressed;
}

class _DesktopContextMenu {
  _DesktopContextMenu._();

  static OverlayEntry? _entry;
  static Rect? _menuRect;
  static bool _pointerRouteRegistered = false;

  static void show({
    required BuildContext context,
    required Offset globalPosition,
    required List<_ContextMenuActionItem> items,
  }) {
    hide();
    if (items.isEmpty) {
      return;
    }

    if (!_pointerRouteRegistered) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
      _pointerRouteRegistered = true;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox = overlay.context.findRenderObject() as RenderBox;
    final width = _estimateWidth(items);
    final estimatedHeight = items.length * 40.0 + 16.0;
    final left = globalPosition.dx.clamp(
      8.0,
      renderBox.size.width - width - 8.0,
    );
    final top = globalPosition.dy.clamp(
      8.0,
      renderBox.size.height - estimatedHeight - 8.0,
    );
    _menuRect = Rect.fromLTWH(left, top, width, estimatedHeight);

    _entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return Positioned(
          left: left,
          top: top,
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: width,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items
                      .map(
                        (item) => _DesktopContextMenuItem(
                          item: item,
                          onPressed: () async {
                            hide();
                            await item.onPressed?.call();
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  static double _estimateWidth(List<_ContextMenuActionItem> items) {
    final maxLabelLength = items.fold<int>(
      0,
      (maxValue, item) =>
          item.label.length > maxValue ? item.label.length : maxValue,
    );
    return (maxLabelLength * 14.0 + 76.0).clamp(148.0, 260.0);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
    _menuRect = null;
  }

  static void _handlePointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent) {
      return;
    }
    final rect = _menuRect;
    if (_entry == null || rect == null) {
      return;
    }
    if (rect.contains(event.position)) {
      return;
    }
    hide();
  }
}

class _DesktopContextMenuItem extends StatelessWidget {
  const _DesktopContextMenuItem({required this.item, required this.onPressed});

  final _ContextMenuActionItem item;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = item.enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withAlpha(115);
    return InkWell(
      onTap: item.enabled ? () => onPressed() : null,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: DefaultTextStyle(
            style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
              color: foregroundColor,
            ),
            child: _ContextMenuItemLabel(
              icon: item.icon,
              leading: item.leading,
              label: item.label,
              foregroundColor: foregroundColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageDetailsDialog extends StatefulWidget {
  const _PackageDetailsDialog({
    required this.packageName,
    required this.managerName,
    required this.detailsLoader,
  });

  final String packageName;
  final String managerName;
  final Future<String?> Function() detailsLoader;

  @override
  State<_PackageDetailsDialog> createState() => _PackageDetailsDialogState();
}

class _PackageDetailsDialogState extends State<_PackageDetailsDialog> {
  late final Future<String?> _detailsFuture;
  final Completer<String?> _detailsCompleter = Completer<String?>();

  @override
  void initState() {
    super.initState();
    _detailsFuture = _detailsCompleter.future;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final details = await widget.detailsLoader();
        if (!_detailsCompleter.isCompleted) {
          _detailsCompleter.complete(details);
        }
      } catch (error, stackTrace) {
        if (!_detailsCompleter.isCompleted) {
          _detailsCompleter.completeError(error, stackTrace);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.packageName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.managerName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<String?>(
                  future: _detailsFuture,
                  builder: (context, snapshot) {
                    final details = snapshot.data;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: switch (snapshot.connectionState) {
                        ConnectionState.waiting ||
                        ConnectionState.active => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const _BusyIndicator(size: 28),
                              const SizedBox(height: 16),
                              Text(l10n.loadingDetails),
                            ],
                          ),
                        ),
                        _ when details != null && details.trim().isNotEmpty =>
                          SingleChildScrollView(
                            child: LinkifiedSelectableText(
                              text: details,
                              style: _monospaceTextStyle(context, height: 1.5),
                              onOpenLink: (url) =>
                                  _openExternalLink(context, url),
                            ),
                          ),
                        _ => Center(
                          child: Text(
                            l10n.detailsUnavailable,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.buttonClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageTileState {
  const _PackageTileState({
    required this.versionInstallOption,
    required this.updateCommand,
    required this.removeCommand,
    required this.canViewDetails,
    required this.canCheckLatest,
    required this.canInstallSpecificVersion,
    required this.isLoadingDetails,
    required this.isCheckingLatest,
    required this.isInstallingSpecificVersion,
    required this.isUpdating,
    required this.isRemoving,
    required this.isSelected,
    required this.iconPath,
    required this.accent,
  });

  factory _PackageTileState.fromController({
    required PackagePanelController controller,
    required ManagedPackage package,
  }) {
    final versionInstallOption = _installOptionFromManagedPackage(package);
    final updateCommand = controller.commandFor(PackageAction.update, package);
    final removeCommand = controller.commandFor(PackageAction.remove, package);
    return _PackageTileState(
      versionInstallOption: versionInstallOption,
      updateCommand: updateCommand,
      removeCommand: removeCommand,
      canViewDetails: controller.canViewPackageDetails(package),
      canCheckLatest: controller.canCheckLatestVersion(package),
      canInstallSpecificVersion: controller.canInstallSpecificVersion(
        versionInstallOption,
      ),
      isLoadingDetails: controller.isLoadingPackageDetails(package),
      isCheckingLatest: controller.isCheckingLatestVersion(package),
      isInstallingSpecificVersion: controller.isInstallingSearchOption(
        versionInstallOption,
      ),
      isUpdating:
          updateCommand != null && controller.isBusy(updateCommand.busyKey),
      isRemoving:
          removeCommand != null && controller.isBusy(removeCommand.busyKey),
      isSelected: controller.isPackageSelected(package),
      iconPath:
          controller.packageIconPath(package) ??
          controller.customManagerIconPath(package.managerId),
      accent: _managerAccent(package.managerId),
    );
  }

  final SearchPackageInstallOption versionInstallOption;
  final PackageCommand? updateCommand;
  final PackageCommand? removeCommand;
  final bool canViewDetails;
  final bool canCheckLatest;
  final bool canInstallSpecificVersion;
  final bool isLoadingDetails;
  final bool isCheckingLatest;
  final bool isInstallingSpecificVersion;
  final bool isUpdating;
  final bool isRemoving;
  final bool isSelected;
  final String? iconPath;
  final Color accent;
}

class _ManagerIcon extends StatelessWidget {
  const _ManagerIcon({
    required this.managerId,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.customIconPath,
    this.size = 18,
    this.showFallbackWhenNoAsset = true,
  });

  final String managerId;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final String? customIconPath;
  final double size;
  final bool showFallbackWhenNoAsset;

  @override
  Widget build(BuildContext context) {
    final customPath = customIconPath?.trim();
    final fallback = _buildFallbackIcon();
    if (customPath != null && customPath.isNotEmpty) {
      return LocalIconImage(
        filePath: customPath,
        size: size,
        fallback: fallback,
      );
    }

    final assetPath = _managerSvgAsset(managerId);
    if (assetPath == null) {
      return fallback;
    }

    return _AssetManagerIcon(
      assetPath: assetPath,
      size: size,
      fallback: fallback,
    );
  }

  Widget _buildFallbackIcon() {
    if (!showFallbackWhenNoAsset) {
      return const SizedBox.shrink();
    }
    return Icon(fallbackIcon, size: size, color: fallbackColor);
  }
}

class _AssetManagerIcon extends StatelessWidget {
  const _AssetManagerIcon({
    required this.assetPath,
    required this.size,
    required this.fallback,
  });

  final String assetPath;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _CommandDialog extends StatelessWidget {
  const _CommandDialog({required this.command});

  final PackageCommand command;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.confirmRunCommandTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.confirmRunCommandBody),
          const SizedBox(height: 12),
          _CommandPreview(command: command.command),
        ],
      ),
      actions: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _copyTextToClipboard(context, command.command),
          icon: const Icon(Icons.copy_all_outlined),
          label: Text(l10n.buttonCopy),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.buttonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.buttonRun),
        ),
      ],
    );
  }
}

class _CommandOutputDialog extends StatelessWidget {
  const _CommandOutputDialog({required this.title, required this.output});

  final String title;
  final String output;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(title),
      content: SizedBox(width: 720, child: _CommandPreview(command: output)),
      actions: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _copyTextToClipboard(context, output),
          icon: const Icon(Icons.copy_all_outlined),
          label: Text(l10n.buttonCopy),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.buttonClose),
        ),
      ],
    );
  }
}

Future<void> _copyTextToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  _showCompactSnackBar(context, context.l10n.copyToClipboardSuccess);
}

String? _buildLoadErrorOutput(
  BuildContext context,
  PackagePanelController controller,
) {
  final failedSnapshots = controller.visibleSnapshots
      .where((snapshot) => snapshot.loadState == ManagerLoadState.error)
      .toList(growable: false);
  if (failedSnapshots.isEmpty) {
    return null;
  }

  return failedSnapshots
      .map((snapshot) {
        final managerName = controller.displayNameForManagerId(
          snapshot.manager.id,
        );
        final errorOutput = snapshot.errorMessage?.trim();
        return [
          '[$managerName]',
          errorOutput == null || errorOutput.isEmpty
              ? context.l10n.noErrorOutput
              : errorOutput,
        ].join('\n');
      })
      .join(
        '\n\n------------------------------------------------------------\n\n',
      );
}

const int _maxVisibleInstallVersions = 200;

Future<void> _showInstallOptionsDialog({
  required BuildContext context,
  required PackagePanelController controller,
  required SearchPackageInstallOption option,
  bool startWithVersionSearch = false,
  required Future<void> Function(PackageCommand command) onInstall,
}) async {
  final command = await showDialog<PackageCommand>(
    context: context,
    builder: (context) => _InstallOptionsDialog(
      controller: controller,
      option: option,
      startWithVersionSearch: startWithVersionSearch,
    ),
  );
  if (command == null || !context.mounted) {
    return;
  }
  await onInstall(command);
}

Future<void> _showSpecificVersionInstallDialog({
  required BuildContext context,
  required PackagePanelController controller,
  required SearchPackageInstallOption option,
  required Future<void> Function(PackageCommand command) onInstall,
}) async {
  final version = await showDialog<String>(
    context: context,
    builder: (context) =>
        _InstallSpecificVersionDialog(controller: controller, option: option),
  );
  if (version == null || !context.mounted) {
    return;
  }

  final command = controller.installCommandForVersion(option, version);
  if (command == null) {
    return;
  }
  await onInstall(command);
}

class _InstallOptionsDialog extends StatefulWidget {
  const _InstallOptionsDialog({
    required this.controller,
    required this.option,
    this.startWithVersionSearch = false,
  });

  final PackagePanelController controller;
  final SearchPackageInstallOption option;
  final bool startWithVersionSearch;

  @override
  State<_InstallOptionsDialog> createState() => _InstallOptionsDialogState();
}

class _InstallOptionsDialogState extends State<_InstallOptionsDialog> {
  late final TextEditingController _versionController;
  late bool _installLatest;
  Future<PackageVersionQueryResult>? _versionsFuture;
  bool _showVersionSearch = false;

  @override
  void initState() {
    super.initState();
    _versionController = TextEditingController();
    final canInstallLatest = widget.controller.canInstallLatestTag(
      widget.option,
    );
    _showVersionSearch =
        widget.startWithVersionSearch &&
        widget.controller.canInstallSpecificVersion(widget.option);
    _installLatest = canInstallLatest && !_showVersionSearch;
    if (_showVersionSearch) {
      _versionsFuture = widget.controller.loadInstallableVersions(
        widget.option,
      );
    }
  }

  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  void _startVersionSearch() {
    if (_showVersionSearch) {
      return;
    }
    setState(() {
      _showVersionSearch = true;
      _installLatest = false;
      _versionsFuture ??= widget.controller.loadInstallableVersions(
        widget.option,
      );
    });
  }

  void _selectVersion(String version) {
    _versionController
      ..text = version
      ..selection = TextSelection.collapsed(offset: version.length);
    setState(() {
      _installLatest = false;
    });
  }

  PackageCommand? _currentCommand() {
    final typedVersion = _versionController.text.trim();
    if (typedVersion.isNotEmpty) {
      return widget.controller.installCommandForVersion(
        widget.option,
        typedVersion,
      );
    }
    if (_installLatest) {
      return widget.controller.installCommandForLatest(widget.option);
    }
    if (_showVersionSearch) {
      return null;
    }
    return widget.controller.installCommandFor(widget.option);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final contentMaxHeight = _showVersionSearch
        ? (viewportHeight - 210).clamp(320.0, 560.0)
        : (viewportHeight - 260).clamp(260.0, 360.0);
    final managerName = widget.controller.displayNameForManagerId(
      widget.option.managerId,
    );
    final canInstallLatest = widget.controller.canInstallLatestTag(
      widget.option,
    );
    final canInstallSpecificVersion = widget.controller
        .canInstallSpecificVersion(widget.option);
    final typedVersion = _versionController.text.trim();
    final command = _currentCommand();

    return AlertDialog(
      title: Text(l10n.installWithManager(managerName)),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: contentMaxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.option.packageName,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        typedVersion.isNotEmpty
                            ? l10n.installDialogVersionSelected(typedVersion)
                            : _installLatest
                            ? l10n.installDialogLatestSelected
                            : l10n.installDialogDefaultSelected,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (canInstallLatest) ...<Widget>[
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _installLatest,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(l10n.installLatestTitle),
                          subtitle: Text(l10n.installLatestSubtitle),
                          onChanged: (value) {
                            setState(() {
                              _installLatest = value ?? false;
                              if (_installLatest) {
                                _showVersionSearch = false;
                                _versionController.clear();
                              }
                            });
                          },
                        ),
                      ],
                      if (canInstallSpecificVersion) ...<Widget>[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _startVersionSearch,
                            icon: const Icon(Icons.manage_search_outlined),
                            label: Text(l10n.installSpecificVersionAction),
                          ),
                        ),
                      ],
                      if (_showVersionSearch) ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _versionController,
                          autofocus: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: l10n.versionSearchHint,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      if (command != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          l10n.pendingCommandLabel,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        _CommandPreview(command: command.command),
                      ],
                    ],
                  ),
                ),
              ),
              if (_showVersionSearch) ...<Widget>[
                const SizedBox(height: 12),
                Flexible(
                  child: FutureBuilder<PackageVersionQueryResult>(
                    future: _versionsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: _BusyIndicator(size: 22));
                      }
                      if (snapshot.hasError) {
                        return _buildInstallVersionStatus(
                          context,
                          message: l10n.loadVersionListFailed(
                            '${snapshot.error}',
                          ),
                        );
                      }

                      final result =
                          snapshot.data ?? const PackageVersionQueryResult();
                      final visibleVersions = _computeVisibleVersions(
                        versions: result.versions,
                        filter: _versionController.text.trim(),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (result.note != null &&
                              result.note!.trim().isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                result.note!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (result.note != null &&
                              result.note!.trim().isNotEmpty)
                            const SizedBox(height: 12),
                          Text(
                            result.versions.isEmpty
                                ? l10n.noAvailableVersionList
                                : visibleVersions.isTruncated
                                ? _versionController.text.trim().isEmpty
                                      ? l10n.availableVersionListTruncated(
                                          visibleVersions.matchedCount,
                                          _maxVisibleInstallVersions,
                                        )
                                      : l10n.availableVersionListTruncatedFiltered(
                                          visibleVersions.matchedCount,
                                          _maxVisibleInstallVersions,
                                        )
                                : l10n.availableVersionListCount(
                                    visibleVersions.matchedCount,
                                  ),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: visibleVersions.items.isEmpty
                                ? _buildInstallVersionStatus(
                                    context,
                                    message:
                                        _versionController.text.trim().isEmpty
                                        ? l10n.noDisplayableVersions
                                        : l10n.noMatchedVersionsUseTypedValue,
                                  )
                                : ListView.separated(
                                    itemCount: visibleVersions.items.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final version =
                                          visibleVersions.items[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                        title: Text(version),
                                        selected:
                                            version ==
                                            _versionController.text.trim(),
                                        trailing: const Icon(
                                          Icons.download_outlined,
                                          size: 18,
                                        ),
                                        onTap: () => _selectVersion(version),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.buttonCancel),
        ),
        FilledButton(
          onPressed: command == null
              ? null
              : () => Navigator.of(context).pop(command),
          child: Text(l10n.buttonConfirm),
        ),
      ],
    );
  }
}

class _InstallSpecificVersionDialog extends StatefulWidget {
  const _InstallSpecificVersionDialog({
    required this.controller,
    required this.option,
  });

  final PackagePanelController controller;
  final SearchPackageInstallOption option;

  @override
  State<_InstallSpecificVersionDialog> createState() =>
      _InstallSpecificVersionDialogState();
}

class _InstallSpecificVersionDialogState
    extends State<_InstallSpecificVersionDialog> {
  late final TextEditingController _filterController;
  late final Future<PackageVersionQueryResult> _versionsFuture;

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
    _versionsFuture = widget.controller.loadInstallableVersions(widget.option);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final filter = _filterController.text.trim();
    final managerName = widget.controller.displayNameForManagerId(
      widget.option.managerId,
    );
    return AlertDialog(
      title: Text(l10n.specificVersionDialogTitle),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$managerName · ${widget.option.packageName}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.specificVersionDialogDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filterController,
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: l10n.versionSearchHint,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                final normalized = value.trim();
                if (normalized.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(normalized);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<PackageVersionQueryResult>(
                future: _versionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: _BusyIndicator(size: 22));
                  }

                  if (snapshot.hasError) {
                    return _buildInstallVersionStatus(
                      context,
                      message: l10n.loadVersionListFailed('${snapshot.error}'),
                    );
                  }

                  final result =
                      snapshot.data ?? const PackageVersionQueryResult();
                  final visibleVersions = _computeVisibleVersions(
                    versions: result.versions,
                    filter: filter,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (result.note != null && result.note!.trim().isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            result.note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (result.note != null && result.note!.trim().isNotEmpty)
                        const SizedBox(height: 12),
                      Text(
                        result.versions.isEmpty
                            ? l10n.noAvailableVersionList
                            : visibleVersions.isTruncated
                            ? filter.isEmpty
                                  ? l10n.availableVersionListTruncated(
                                      visibleVersions.matchedCount,
                                      _maxVisibleInstallVersions,
                                    )
                                  : l10n.availableVersionListTruncatedFiltered(
                                      visibleVersions.matchedCount,
                                      _maxVisibleInstallVersions,
                                    )
                            : l10n.availableVersionListCount(
                                visibleVersions.matchedCount,
                              ),
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: visibleVersions.items.isEmpty
                            ? _buildInstallVersionStatus(
                                context,
                                message: filter.isEmpty
                                    ? l10n.noDisplayableVersions
                                    : l10n.noMatchedVersionsCanInstallTyped,
                              )
                            : ListView.separated(
                                itemCount: visibleVersions.items.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final version = visibleVersions.items[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    title: Text(version),
                                    trailing: const Icon(
                                      Icons.download_outlined,
                                      size: 18,
                                    ),
                                    onTap: () =>
                                        Navigator.of(context).pop(version),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.buttonCancel),
        ),
        FilledButton(
          onPressed: filter.isEmpty
              ? null
              : () => Navigator.of(context).pop(filter),
          child: Text(l10n.buttonInstallInputVersion),
        ),
      ],
    );
  }
}

Widget _buildInstallVersionStatus(
  BuildContext context, {
  required String message,
}) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLowest,
      border: Border.all(color: theme.colorScheme.outlineVariant),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

_VisibleVersions _computeVisibleVersions({
  required List<String> versions,
  required String filter,
}) {
  final normalizedFilter = filter.trim().toLowerCase();
  final items = <String>[];
  var matchedCount = 0;

  for (final version in versions) {
    if (normalizedFilter.isNotEmpty &&
        !version.toLowerCase().contains(normalizedFilter)) {
      continue;
    }
    matchedCount += 1;
    if (items.length < _maxVisibleInstallVersions) {
      items.add(version);
    }
  }

  return _VisibleVersions(items: items, matchedCount: matchedCount);
}

class _VisibleVersions {
  const _VisibleVersions({required this.items, required this.matchedCount});

  final List<String> items;
  final int matchedCount;

  bool get isTruncated => matchedCount > items.length;
}

class _CommandPreview extends StatelessWidget {
  const _CommandPreview({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        command,
        style: _monospaceTextStyle(context, color: Colors.white, height: 1.45),
      ),
    );
  }
}

TextStyle? _monospaceTextStyle(
  BuildContext context, {
  Color? color,
  double? height,
}) {
  final baseStyle = Theme.of(context).textTheme.bodyMedium;
  final fallback = <String>[
    ...?baseStyle?.fontFamilyFallback,
    'Cascadia Code',
    'JetBrains Mono',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Segoe UI',
  ];
  return baseStyle?.copyWith(
    color: color,
    height: height,
    fontFamily: 'Cascadia Code',
    fontFamilyFallback: fallback.toSet().toList(growable: false),
  );
}

class _EmptyPackages extends StatelessWidget {
  const _EmptyPackages({
    required this.hasManagersLoading,
    required this.hasVisibleManagers,
    required this.errorManagerCount,
    required this.onOpenSettings,
    required this.onShowLoadErrors,
    required this.searchQuery,
  });

  final bool hasManagersLoading;
  final bool hasVisibleManagers;
  final int errorManagerCount;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onShowLoadErrors;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (hasManagersLoading)
            const SizedBox(
              width: 28,
              height: 28,
              child: _BusyIndicator(size: 28),
            )
          else
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
          const SizedBox(height: 14),
          Text(
            hasManagersLoading
                ? l10n.emptyLoadingManagers
                : hasVisibleManagers
                ? l10n.emptyNoMatchingPackages
                : l10n.emptyNoEnabledManagers,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _description(context),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (!hasManagersLoading && errorManagerCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.tonalIcon(
                onPressed: onShowLoadErrors,
                icon: const Icon(Icons.terminal_outlined),
                label: Text(l10n.viewLoadErrorsButton(errorManagerCount)),
              ),
            ),
          if (!hasManagersLoading && !hasVisibleManagers)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.tonalIcon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.tune),
                label: Text(l10n.buttonOpenSettings),
              ),
            ),
        ],
      ),
    );
  }

  String _description(BuildContext context) {
    final l10n = context.l10n;
    if (!hasVisibleManagers) {
      return l10n.emptyNoEnabledManagersDescription;
    }
    if (errorManagerCount > 0) {
      return l10n.emptyManagersLoadErrorDescription(errorManagerCount);
    }
    return searchQuery.isEmpty
        ? l10n.emptyClickRefresh
        : l10n.emptyNoSearchResult(searchQuery);
  }
}
