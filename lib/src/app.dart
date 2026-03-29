import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/package_models.dart';
import 'services/package_panel_controller.dart';
import 'services/external_link_opener.dart';
import 'services/window_theme_sync.dart';
import 'widgets/local_icon_image.dart';

void runPkgPanel(PackagePanelController controller) {
  runApp(PkgPanelApp(controller: controller));
}

const String _appDisplayName = 'Pkg Panel';
const String _appTagline = '一个管理各种包管理器的面板。';
const String _appAuthor = 'caolib';
const String _appAuthorUrl = 'https://github.com/caolib';
const String _appRepositoryUrl = 'https://github.com/caolib/pkg-panel';

class PkgPanelApp extends StatefulWidget {
  const PkgPanelApp({
    super.key,
    required this.controller,
    this.autoLoad = true,
    this.windowThemeSync = const PlatformWindowThemeSync(),
  });

  final PackagePanelController controller;
  final bool autoLoad;
  final WindowThemeSync windowThemeSync;

  @override
  State<PkgPanelApp> createState() => _PkgPanelAppState();
}

class _PkgPanelAppState extends State<PkgPanelApp> {
  ThemeMode? _lastSyncedWindowThemeMode;
  ThemeMode? _pendingWindowThemeMode;
  bool _windowThemeSyncScheduled = false;

  @override
  void didUpdateWidget(covariant PkgPanelApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowThemeSync != widget.windowThemeSync) {
      _lastSyncedWindowThemeMode = null;
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _scheduleWindowThemeSync(ThemeMode themeMode) {
    _pendingWindowThemeMode = themeMode;
    if (_windowThemeSyncScheduled) {
      return;
    }

    _windowThemeSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _windowThemeSyncScheduled = false;
      if (!mounted) {
        return;
      }

      final themeModeToSync = _pendingWindowThemeMode;
      _pendingWindowThemeMode = null;
      if (themeModeToSync == null ||
          themeModeToSync == _lastSyncedWindowThemeMode) {
        return;
      }

      _lastSyncedWindowThemeMode = themeModeToSync;
      unawaited(widget.windowThemeSync.sync(themeModeToSync));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final themeMode = widget.controller.themeMode;
        _scheduleWindowThemeSync(themeMode);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '包管理面板',
          themeMode: themeMode,
          theme: _buildTheme(
            brightness: Brightness.light,
            customFontFamily: widget.controller.customFontFamily,
            customFallbackFontFamilies:
                widget.controller.customFallbackFontFamilies,
          ),
          darkTheme: _buildTheme(
            brightness: Brightness.dark,
            customFontFamily: widget.controller.customFontFamily,
            customFallbackFontFamilies:
                widget.controller.customFallbackFontFamilies,
          ),
          home: PackagePanelHome(
            controller: widget.controller,
            autoLoad: widget.autoLoad,
          ),
        );
      },
    );
  }
}

ThemeData _buildTheme({
  required Brightness brightness,
  required String? customFontFamily,
  required List<String> customFallbackFontFamilies,
}) {
  const seed = Color(0xFF0F766E);
  const darkBase = Color(0xFF202020);
  final primaryFont = customFontFamily?.trim().isNotEmpty == true
      ? customFontFamily!.trim()
      : 'Cascadia Code';
  final fallbackFonts = customFallbackFontFamilies.isEmpty
      ? const <String>[
          'JetBrains Mono',
          '喵字果汁体',
          '汉仪有圆',
          '霞鹜文楷',
          'Segoe UI Variable Text',
          'Microsoft YaHei UI',
          'Microsoft YaHei',
          'Segoe UI',
        ]
      : customFallbackFontFamilies;
  final colorScheme = brightness == Brightness.dark
      ? const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFE6E6E6),
          onPrimary: Color(0xFF202020),
          primaryContainer: Color(0xFF2C2C2C),
          onPrimaryContainer: Color(0xFFF2F2F2),
          secondary: Color(0xFFD0D0D0),
          onSecondary: Color(0xFF202020),
          secondaryContainer: Color(0xFF303030),
          onSecondaryContainer: Color(0xFFEAEAEA),
          tertiary: Color(0xFFC8C8C8),
          onTertiary: Color(0xFF202020),
          tertiaryContainer: Color(0xFF343434),
          onTertiaryContainer: Color(0xFFEAEAEA),
          error: Color(0xFFFFB4AB),
          onError: Color(0xFF690005),
          errorContainer: Color(0xFF93000A),
          onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF262626),
          onSurface: Color(0xFFEAEAEA),
          surfaceContainerLowest: Color(0xFF202020),
          surfaceContainerLow: Color(0xFF242424),
          surfaceContainer: Color(0xFF2A2A2A),
          surfaceContainerHigh: Color(0xFF303030),
          surfaceContainerHighest: Color(0xFF363636),
          onSurfaceVariant: Color(0xFFB8B8B8),
          outline: Color(0xFF7A7A7A),
          outlineVariant: Color(0xFF3A3A3A),
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: Color(0xFFEAEAEA),
          onInverseSurface: Color(0xFF202020),
          inversePrimary: Color(0xFF3A3A3A),
          surfaceTint: Color(0xFFE0E0E0),
        )
      : ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final baseTheme = ThemeData(useMaterial3: true, brightness: brightness);
  final baseTextTheme = baseTheme.textTheme;
  final scaffoldBackgroundColor = brightness == Brightness.dark
      ? darkBase
      : const Color(0xFFF3F3F3);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    fontFamily: primaryFont,
    textTheme: _withFontStack(
      baseTextTheme,
      primaryFont: primaryFont,
      fallbackFonts: fallbackFonts,
    ),
    primaryTextTheme: _withFontStack(
      baseTextTheme,
      primaryFont: primaryFont,
      fallbackFonts: fallbackFonts,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surface),
      surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 14),
      ),
    ),
  );
}

TextTheme _withFontStack(
  TextTheme textTheme, {
  required String primaryFont,
  required List<String> fallbackFonts,
}) {
  TextStyle? apply(TextStyle? style) {
    if (style == null) {
      return null;
    }
    return style.copyWith(
      fontFamily: primaryFont,
      fontFamilyFallback: fallbackFonts,
    );
  }

  return textTheme.copyWith(
    displayLarge: apply(textTheme.displayLarge),
    displayMedium: apply(textTheme.displayMedium),
    displaySmall: apply(textTheme.displaySmall),
    headlineLarge: apply(textTheme.headlineLarge),
    headlineMedium: apply(textTheme.headlineMedium),
    headlineSmall: apply(textTheme.headlineSmall),
    titleLarge: apply(textTheme.titleLarge),
    titleMedium: apply(textTheme.titleMedium),
    titleSmall: apply(textTheme.titleSmall),
    bodyLarge: apply(textTheme.bodyLarge),
    bodyMedium: apply(textTheme.bodyMedium),
    bodySmall: apply(textTheme.bodySmall),
    labelLarge: apply(textTheme.labelLarge),
    labelMedium: apply(textTheme.labelMedium),
    labelSmall: apply(textTheme.labelSmall),
  );
}

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
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );

    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.ensureLoaded();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final runningCommands = widget.controller.runningCommandTexts;
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TabBar(
                        controller: _tabController,
                        tabs: const <Widget>[
                          Tab(text: '本地'),
                          Tab(text: '安装'),
                          Tab(text: '设置'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: <Widget>[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _ActionBar(
                                  controller: widget.controller,
                                  searchController: _searchController,
                                  onRefreshAll:
                                      widget.controller.refreshCurrentSelection,
                                  onBatchCheckLatest:
                                      _handleBatchCheckLatestForSelectedManager,
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
                                _ManagerFilterBar(
                                  controller: widget.controller,
                                ),
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
                            ),
                            PackageInstallPage(controller: widget.controller),
                            PackageSettingsPage(controller: widget.controller),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (runningCommands.isNotEmpty)
                  Positioned(
                    right: 24,
                    bottom: 24,
                    child: _RunningCommandToast(commands: runningCommands),
                  ),
              ],
            ),
          ),
        );
      },
    );
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

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(command.command),
      ),
    );

    if (!result.isSuccess) {
      await showDialog<void>(
        context: context,
        builder: (context) => _CommandOutputDialog(
          title: '命令执行失败',
          output: result.combinedOutput.isEmpty
              ? '没有输出内容。'
              : result.combinedOutput,
        ),
      );
    }
  }

  Future<void> _handleBatchCheckLatestForSelectedManager() async {
    final prerequisiteCommand = await widget.controller
        .batchLatestVersionPrerequisiteCommandForSelectedManager();
    if (!mounted) {
      return;
    }

    if (prerequisiteCommand != null) {
      final prompt =
          widget.controller
              .batchLatestVersionPrerequisitePromptForSelectedManager() ??
          '批量检查更新前需要先安装依赖命令，是否现在安装？';
      final shouldInstall =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('需要先安装依赖'),
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
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('安装'),
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
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(prerequisiteCommand.command),
        ),
      );
      if (!result.isSuccess) {
        await showDialog<void>(
          context: context,
          builder: (context) => _CommandOutputDialog(
            title: '命令执行失败',
            output: result.combinedOutput.isEmpty
                ? '没有输出内容。'
                : result.combinedOutput,
          ),
        );
        return;
      }
    }

    await widget.controller.batchCheckLatestVersionsForSelectedManager();
  }

  Future<void> _openSettings() async {
    _tabController.animateTo(2);
  }

  Future<void> _showLoadErrorsDialog() async {
    final output = _buildLoadErrorOutput(widget.controller);
    if (output == null || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) =>
          _CommandOutputDialog(title: '加载错误详情', output: output),
    );
  }
}

class _RunningCommandToast extends StatelessWidget {
  const _RunningCommandToast({required this.commands});

  final List<String> commands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewCommands = commands.take(3).toList(growable: false);
    final extraCount = commands.length - previewCommands.length;
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(38),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '正在执行命令',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...previewCommands.map(
                      (command) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          command,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cascadia Code',
                            fontFamilyFallback:
                                theme.textTheme.bodyMedium?.fontFamilyFallback,
                          ),
                        ),
                      ),
                    ),
                    if (extraCount > 0)
                      Text(
                        '另外 $extraCount 个命令正在运行',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
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
    final batchCommand = controller.batchUpdateCommandForSelectedManager();
    final canBatchCheckLatest =
        controller.canBatchCheckLatestForSelectedManager;
    final isBatchCheckingLatest =
        controller.isBatchCheckingLatestForSelectedManager;
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
                hintText: '搜索本地包',
                leading: const Icon(Icons.search),
                onChanged: controller.setSearchQuery,
                trailing: <Widget>[
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: '清空',
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('刷新'),
            ),
            if (hasLoadErrors)
              FilledButton.tonalIcon(
                onPressed: onShowLoadErrors,
                icon: const Icon(Icons.error_outline),
                label: Text('查看加载错误 (${controller.errorManagers})'),
              ),
            if (canBatchCheckLatest)
              FilledButton.tonalIcon(
                onPressed: isBatchCheckingLatest ? null : onBatchCheckLatest,
                icon: isBatchCheckingLatest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.find_replace_outlined),
                label: const Text('检查更新'),
              ),
            if (showBatchUpdate)
              FilledButton.tonalIcon(
                onPressed: onBatchUpdate,
                icon: const Icon(Icons.system_update_alt),
                label: const Text('批量更新'),
              ),
            Chip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text('当前 $visibleCount 个包'),
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilterChip(
          selected: controller.selectedManagerId == null,
          showCheckmark: false,
          label: const Text('全部'),
          onSelected: (_) => controller.selectManager(null),
        ),
        ...controller.visibleSnapshots.map((snapshot) {
          final label = switch (snapshot.loadState) {
            ManagerLoadState.error =>
              '${controller.displayNameForManagerId(snapshot.manager.id)} (加载失败)',
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
        final compact = constraints.maxWidth < 1120;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
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
                      child: ListView.separated(
                        itemCount: packages.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        itemBuilder: (context, index) {
                          return _PackageListTile(
                            package: packages[index],
                            controller: controller,
                            onRunAction: onRunAction,
                            compact: compact,
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
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: compact
          ? Row(
              children: <Widget>[
                Text('包列表', style: style),
                const Spacer(),
                Text(
                  selectedCount > 1
                      ? '$count 项 · 已选 $selectedCount'
                      : '$count 项',
                  style: style,
                ),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(flex: 5, child: Text('包名', style: style)),
                Expanded(flex: 2, child: Text('当前版本', style: style)),
                Expanded(flex: 2, child: Text('最新版本', style: style)),
                Expanded(flex: 8, child: Text('附加信息', style: style)),
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
    final versionInstallOption = _installOptionFromManagedPackage(package);
    final updateCommand = controller.commandFor(PackageAction.update, package);
    final removeCommand = controller.commandFor(PackageAction.remove, package);
    final canViewDetails = controller.canViewPackageDetails(package);
    final canCheckLatest = controller.canCheckLatestVersion(package);
    final canInstallSpecificVersion = controller.canInstallSpecificVersion(
      versionInstallOption,
    );
    final isLoadingDetails = controller.isLoadingPackageDetails(package);
    final isCheckingLatest = controller.isCheckingLatestVersion(package);
    final isInstallingSpecificVersion = controller.isInstallingSearchOption(
      versionInstallOption,
    );
    final isUpdating =
        updateCommand != null && controller.isBusy(updateCommand.busyKey);
    final isRemoving =
        removeCommand != null && controller.isBusy(removeCommand.busyKey);
    final accent = _managerAccent(package.managerId);
    final extra = _extraLine(package);
    final isSelected = controller.isPackageSelected(package);
    final theme = Theme.of(context);
    final rowContent = compact
        ? Row(
            children: <Widget>[
              _ManagerIcon(
                managerId: package.managerId,
                customIconPath:
                    controller.packageIconPath(package) ??
                    controller.customManagerIconPath(package.managerId),
                fallbackIcon: _managerIcon(package.managerId),
                fallbackColor: accent,
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
                      _compactSummaryLine(package),
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
                      customIconPath:
                          controller.packageIconPath(package) ??
                          controller.customManagerIconPath(package.managerId),
                      fallbackIcon: _managerIcon(package.managerId),
                      fallbackColor: accent,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons != kPrimaryMouseButton) {
            return;
          }
          controller.selectPackage(
            package,
            additive: _isAdditiveSelectionPressed(),
            range: _isRangeSelectionPressed(),
          );
        },
        child: Material(
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(36)
              : Colors.transparent,
          child: InkWell(
            onTap: () {},
            onDoubleTap: canViewDetails && !isLoadingDetails
                ? () => _openPackageDetails(context)
                : null,
            onSecondaryTapUp: (details) => _showContextMenu(
              context,
              details.globalPosition,
              canViewDetails: canViewDetails,
              canCheckLatest: canCheckLatest,
              isLoadingDetails: isLoadingDetails,
              isCheckingLatest: isCheckingLatest,
              isUpdating: isUpdating,
              isRemoving: isRemoving,
              canInstallSpecificVersion: canInstallSpecificVersion,
              isInstallingSpecificVersion: isInstallingSpecificVersion,
              versionInstallOption: versionInstallOption,
              updateCommand: updateCommand,
              removeCommand: removeCommand,
            ),
            child: Padding(padding: innerPadding, child: rowContent),
          ),
        ),
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
    controller.selectPackageForContextMenu(package);

    final items = <_ContextMenuActionItem>[
      if (canViewDetails)
        _ContextMenuActionItem(
          icon: Icons.info_outline,
          label: '查看详情',
          enabled: !isLoadingDetails,
          onPressed: () => _openPackageDetails(context),
        ),
      if (canCheckLatest)
        _ContextMenuActionItem(
          icon: Icons.find_replace_outlined,
          label: '检查更新',
          enabled: !isCheckingLatest,
          onPressed: () async {
            final latestVersion = await controller.checkLatestVersion(package);
            if (!context.mounted) {
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            messenger.clearSnackBars();
            if (latestVersion != null) {
              final isLatest = latestVersion.trim() == package.version.trim();
              messenger.showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    isLatest
                        ? '${package.name} 已经是最新版本。'
                        : '${package.name} 有新版本：$latestVersion',
                  ),
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
              messenger.showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    recentError != null
                        ? '检查 ${package.name} 失败：${recentError.message}'
                        : '检查 ${package.name} 失败，请查看活动日志。',
                  ),
                ),
              );
            }
          },
        ),
      if (updateCommand != null)
        _ContextMenuActionItem(
          icon: Icons.system_update_alt,
          label: package.hasUpdate ? '升级' : '更新',
          enabled: !isUpdating,
          onPressed: () => onRunAction(updateCommand),
        ),
      if (canInstallSpecificVersion)
        _ContextMenuActionItem(
          icon: Icons.pin_outlined,
          label: '安装特定版本',
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
          label: '删除',
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
  const _ContextMenuItemLabel({this.icon, this.leading, required this.label})
    : assert(icon != null || leading != null);

  final IconData? icon;
  final Widget? leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        leading ?? Icon(icon, size: 18),
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
    return InkWell(
      onTap: item.enabled ? () => onPressed() : null,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Opacity(
            opacity: item.enabled ? 1 : 0.45,
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium ?? const TextStyle(),
              child: _ContextMenuItemLabel(
                icon: item.icon,
                leading: item.leading,
                label: item.label,
              ),
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
                        ConnectionState.active => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('正在加载详情...'),
                            ],
                          ),
                        ),
                        _ when details != null && details.trim().isNotEmpty =>
                          SingleChildScrollView(
                            child: SelectableText(
                              details,
                              style: _monospaceTextStyle(context, height: 1.5),
                            ),
                          ),
                        _ => Center(
                          child: Text(
                            '详情加载失败或没有返回内容。',
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
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerIcon extends StatelessWidget {
  const _ManagerIcon({
    required this.managerId,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.customIconPath,
    this.size = 18,
  });

  final String managerId;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final String? customIconPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final customPath = customIconPath?.trim();
    final fallback = _buildDefaultManagerIcon();
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

    final lowerAssetPath = assetPath.toLowerCase();

    return SizedBox.square(
      dimension: size,
      child: lowerAssetPath.endsWith('.svg')
          ? SvgPicture.asset(
              assetPath,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => fallback,
            )
          : Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }

  Widget _buildDefaultManagerIcon() {
    final assetPath = _managerSvgAsset(managerId);
    final iconFallback = Icon(fallbackIcon, size: size, color: fallbackColor);
    if (assetPath == null) {
      return iconFallback;
    }

    final lowerAssetPath = assetPath.toLowerCase();
    return SizedBox.square(
      dimension: size,
      child: lowerAssetPath.endsWith('.svg')
          ? SvgPicture.asset(
              assetPath,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => iconFallback,
            )
          : Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => iconFallback,
            ),
    );
  }
}

class _CommandDialog extends StatelessWidget {
  const _CommandDialog({required this.command});

  final PackageCommand command;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('确认执行命令'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('将执行下面的命令：'),
          const SizedBox(height: 12),
          _CommandPreview(command: command.command),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('执行'),
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
    return AlertDialog(
      title: Text(title),
      content: SizedBox(width: 720, child: _CommandPreview(command: output)),
      actions: <Widget>[
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: output));
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('已复制到剪贴板。'),
                ),
              );
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('复制'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

String? _buildLoadErrorOutput(PackagePanelController controller) {
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
              ? '没有返回错误输出。'
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
      title: Text('使用 $managerName 安装'),
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
                            ? '当前将安装版本 $typedVersion。'
                            : _installLatest
                            ? '当前将显式安装 @latest。'
                            : '当前将执行默认安装命令。',
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
                          title: const Text('安装最新'),
                          subtitle: const Text('使用 @latest 形式安装'),
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
                            label: const Text('安装特定版本'),
                          ),
                        ),
                      ],
                      if (_showVersionSearch) ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _versionController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '输入版本号快速筛选，例如 1.2.3',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      if (command != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text('将要执行的命令', style: theme.textTheme.labelLarge),
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
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        );
                      }
                      if (snapshot.hasError) {
                        return _buildInstallVersionStatus(
                          context,
                          message: '读取版本列表失败：${snapshot.error}',
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
                                ? '当前命令没有返回可用版本列表。'
                                : visibleVersions.isTruncated
                                ? _versionController.text.trim().isEmpty
                                      ? '共 ${visibleVersions.matchedCount} 个可选版本，仅显示最新 $_maxVisibleInstallVersions 个，请输入版本号缩小范围。'
                                      : '匹配 ${visibleVersions.matchedCount} 个版本，仅显示前 $_maxVisibleInstallVersions 个，请继续输入缩小范围。'
                                : '共 ${visibleVersions.matchedCount} 个可选版本',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: visibleVersions.items.isEmpty
                                ? _buildInstallVersionStatus(
                                    context,
                                    message:
                                        _versionController.text.trim().isEmpty
                                        ? '没有可显示的版本。'
                                        : '没有匹配的版本，确定时会直接使用输入框里的版本号。',
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: command == null
              ? null
              : () => Navigator.of(context).pop(command),
          child: const Text('确定'),
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
    final filter = _filterController.text.trim();
    final managerName = widget.controller.displayNameForManagerId(
      widget.option.managerId,
    );
    return AlertDialog(
      title: const Text('安装特定版本'),
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
              '选择一个可用版本，或直接输入版本号执行安装。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filterController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入版本号快速筛选，例如 1.2.3',
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
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildInstallVersionStatus(
                      context,
                      message: '读取版本列表失败：${snapshot.error}',
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
                            ? '当前命令没有返回可用版本列表。'
                            : visibleVersions.isTruncated
                            ? filter.isEmpty
                                  ? '共 ${visibleVersions.matchedCount} 个可选版本，仅显示最新 $_maxVisibleInstallVersions 个，请输入版本号缩小范围。'
                                  : '匹配 ${visibleVersions.matchedCount} 个版本，仅显示前 $_maxVisibleInstallVersions 个，请继续输入缩小范围。'
                            : '共 ${visibleVersions.matchedCount} 个可选版本',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: visibleVersions.items.isEmpty
                            ? _buildInstallVersionStatus(
                                context,
                                message: filter.isEmpty
                                    ? '没有可显示的版本。'
                                    : '没有匹配的版本，可以直接使用下方按钮安装输入值。',
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: filter.isEmpty
              ? null
              : () => Navigator.of(context).pop(filter),
          child: const Text('安装输入版本'),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (hasManagersLoading)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.2),
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
                ? '正在刷新包管理器...'
                : hasVisibleManagers
                ? '没有匹配的包'
                : '暂未启用包管理器',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _description,
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
                label: Text('查看加载错误 ($errorManagerCount)'),
              ),
            ),
          if (!hasManagersLoading && !hasVisibleManagers)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.tonalIcon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.tune),
                label: const Text('打开设置'),
              ),
            ),
        ],
      ),
    );
  }

  String get _description {
    if (!hasVisibleManagers) {
      return '当前没有启用任何包管理器，请先到设置中选择要展示的项。';
    }
    if (errorManagerCount > 0) {
      return '有 $errorManagerCount 个包管理器加载失败，可以打开错误详情查看完整输出。';
    }
    return searchQuery.isEmpty ? '可以先点击“刷新”。' : '没有找到“$searchQuery”的结果。';
  }
}

class PackageSettingsPage extends StatelessWidget {
  const PackageSettingsPage({super.key, required this.controller});

  final PackagePanelController controller;

  static const List<String> _fontSuggestions = <String>[
    'Cascadia Code',
    'Segoe UI',
    'Microsoft YaHei UI',
    '霞鹜文楷',
    'JetBrains Mono',
  ];
  static const List<String> _fallbackFontSuggestions = <String>[
    'Segoe UI',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    '霞鹜文楷',
    'JetBrains Mono',
  ];

  Future<void> _editManagerIconPath(
    BuildContext context,
    PackageManagerVisibilityState state,
  ) async {
    final managerName = controller.displayNameForManagerId(state.manager.id);
    final textController = TextEditingController(
      text: controller.customManagerIconPath(state.manager.id) ?? '',
    );

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('自定义 $managerName 图标'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('输入本地图标文件路径，支持 svg、png、jpg、webp、ico。'),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: r'C:\icons\my-manager.svg',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(textController.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (value == null || !context.mounted) {
      return;
    }

    await controller.setCustomManagerIconPath(state.manager.id, value);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            value.trim().isEmpty
                ? '$managerName 已恢复默认图标。'
                : '$managerName 图标已更新。',
          ),
        ),
      );
  }

  Future<void> _editManagerDisplayName(
    BuildContext context,
    PackageManagerVisibilityState state,
  ) async {
    final textController = TextEditingController(
      text:
          controller.customManagerDisplayName(state.manager.id) ??
          state.manager.displayName,
    );

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('修改 ${state.manager.displayName} 显示名称'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入新的显示名称',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(textController.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (value == null) {
      return;
    }

    if (value.trim() == state.manager.displayName.trim()) {
      await controller.clearCustomManagerDisplayName(state.manager.id);
      return;
    }

    await controller.setCustomManagerDisplayName(state.manager.id, value);
  }

  Future<void> _editFontFamily(BuildContext context) async {
    final textController = TextEditingController(
      text: controller.customFontFamily ?? 'Cascadia Code',
    );

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('设置字体'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('输入系统已安装的字体名称。留空或恢复默认会使用内置默认字体。'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '例如 Segoe UI / Microsoft YaHei UI',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _fontSuggestions
                          .map(
                            (font) => ActionChip(
                              label: Text(font),
                              onPressed: () {
                                textController.text = font;
                                setState(() {});
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: const Text('恢复默认'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(textController.text),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (value == null) {
      return;
    }
    await controller.setCustomFontFamily(value);
  }

  Future<void> _editFallbackFontFamilies(BuildContext context) async {
    final textController = TextEditingController(
      text: controller.customFallbackFontFamilies.join(', '),
    );

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('设置 fallback 字体'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('用英文逗号分隔多个字体，前面的优先级更高。'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '例如 Segoe UI, Microsoft YaHei UI, 霞鹜文楷',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _fallbackFontSuggestions
                          .map(
                            (font) => ActionChip(
                              label: Text(font),
                              onPressed: () {
                                final current = textController.text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                if (!current.contains(font)) {
                                  current.add(font);
                                  textController.text = current.join(', ');
                                  setState(() {});
                                }
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: const Text('恢复默认'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(textController.text),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (value == null) {
      return;
    }

    final fonts = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    await controller.setCustomFallbackFontFamilies(fonts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: '包管理器'),
              Tab(text: '外观'),
              Tab(text: '关于'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final states = controller.managerVisibilityStates;
                return TabBarView(
                  children: <Widget>[
                    ListView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerLowest,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        '包管理器',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        '状态',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '显示',
                                        textAlign: TextAlign.right,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                buildDefaultDragHandles: false,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: states.length,
                                onReorder: (oldIndex, newIndex) {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  controller.reorderManager(oldIndex, newIndex);
                                },
                                itemBuilder: (context, index) {
                                  final state = states[index];
                                  return DecoratedBox(
                                    key: ValueKey(state.manager.id),
                                    decoration: BoxDecoration(
                                      border: index == states.length - 1
                                          ? null
                                          : Border(
                                              bottom: BorderSide(
                                                color: theme
                                                    .colorScheme
                                                    .outlineVariant,
                                              ),
                                            ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          MouseRegion(
                                            cursor: SystemMouseCursors.grab,
                                            child: ReorderableDragStartListener(
                                              index: index,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 12,
                                                ),
                                                child: Icon(
                                                  Icons.drag_indicator,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Row(
                                              children: <Widget>[
                                                _ManagerIcon(
                                                  managerId: state.manager.id,
                                                  customIconPath: controller
                                                      .customManagerIconPath(
                                                        state.manager.id,
                                                      ),
                                                  fallbackIcon:
                                                      state.manager.icon,
                                                  fallbackColor:
                                                      state.manager.color,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      Text(
                                                        controller
                                                            .displayNameForManagerId(
                                                              state.manager.id,
                                                            ),
                                                        style: theme
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      if (controller
                                                              .customManagerIconPath(
                                                                state
                                                                    .manager
                                                                    .id,
                                                              ) !=
                                                          null) ...<Widget>[
                                                        Text(
                                                          controller
                                                              .customManagerIconPath(
                                                                state
                                                                    .manager
                                                                    .id,
                                                              )!,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                      ],
                                                      Wrap(
                                                        spacing: 8,
                                                        children: <Widget>[
                                                          TextButton(
                                                            onPressed: () =>
                                                                _editManagerDisplayName(
                                                                  context,
                                                                  state,
                                                                ),
                                                            child: const Text(
                                                              '重命名',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                _editManagerIconPath(
                                                                  context,
                                                                  state,
                                                                ),
                                                            child: const Text(
                                                              '自定义图标',
                                                            ),
                                                          ),
                                                          if (controller
                                                                  .customManagerIconPath(
                                                                    state
                                                                        .manager
                                                                        .id,
                                                                  ) !=
                                                              null)
                                                            TextButton(
                                                              onPressed: () =>
                                                                  controller
                                                                      .clearCustomManagerIconPath(
                                                                        state
                                                                            .manager
                                                                            .id,
                                                                      ),
                                                              child: const Text(
                                                                '恢复默认',
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 5,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  state.isAvailable
                                                      ? '已检测到'
                                                      : '未检测到',
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: state.isAvailable
                                                            ? theme
                                                                  .colorScheme
                                                                  .primary
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  state.manager.description,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Switch(
                                                value: state.isVisible,
                                                onChanged: (value) => controller
                                                    .setManagerVisibility(
                                                      state.manager.id,
                                                      value,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        children: <Widget>[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '主题模式',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 12),
                                  SegmentedButton<ThemeMode>(
                                    segments: const <ButtonSegment<ThemeMode>>[
                                      ButtonSegment<ThemeMode>(
                                        value: ThemeMode.system,
                                        label: Text('系统'),
                                        icon: Icon(
                                          Icons.brightness_auto_outlined,
                                        ),
                                      ),
                                      ButtonSegment<ThemeMode>(
                                        value: ThemeMode.light,
                                        label: Text('浅色'),
                                        icon: Icon(Icons.light_mode_outlined),
                                      ),
                                      ButtonSegment<ThemeMode>(
                                        value: ThemeMode.dark,
                                        label: Text('深色'),
                                        icon: Icon(Icons.dark_mode_outlined),
                                      ),
                                    ],
                                    selected: <ThemeMode>{controller.themeMode},
                                    onSelectionChanged: (values) {
                                      controller.setThemeMode(values.first);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              '字体',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              controller.customFontFamily ??
                                                  'Cascadia Code',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () =>
                                            _editFontFamily(context),
                                        child: const Text('设置字体'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: const Text(
                                      '字体预览：The quick brown fox jumps over the lazy dog. 敏捷的棕狐跳过了懒狗。',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              'Fallback 字体',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              controller
                                                      .customFallbackFontFamilies
                                                      .isEmpty
                                                  ? '使用默认 fallback 字体栈'
                                                  : controller
                                                        .customFallbackFontFamilies
                                                        .join(', '),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () =>
                                            _editFallbackFontFamilies(context),
                                        child: const Text('设置 fallback'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: _AboutAppCard(theme: theme),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutAppCard extends StatelessWidget {
  const _AboutAppCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '关于',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SvgPicture.asset(
                'assets/branding/logo.svg',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _appDisplayName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Text(
                _appTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _AboutMetaRow(),
          ],
        ),
      ),
    );
  }
}

class _AboutMetaRow extends StatelessWidget {
  const _AboutMetaRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final packageInfo = snapshot.data;
        final versionLabel = packageInfo == null
            ? '读取中...'
            : packageInfo.buildNumber.trim().isEmpty
            ? packageInfo.version
            : '${packageInfo.version}+${packageInfo.buildNumber}';
        final theme = Theme.of(context);
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              Chip(
                avatar: const Icon(Icons.sell_outlined, size: 18),
                label: Text(versionLabel),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                backgroundColor: theme.colorScheme.surfaceContainerLow,
              ),
              OutlinedButton.icon(
                onPressed: () => _openExternalLink(context, _appAuthorUrl),
                icon: const Icon(Icons.person_outline),
                label: const Text(_appAuthor),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openExternalLink(context, _appRepositoryUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('GitHub 仓库'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _openExternalLink(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) {
      return;
    }
  } catch (_) {
    final openedWithSystem = await openExternalLinkWithSystem(url);
    if (openedWithSystem || !context.mounted) {
      return;
    }
  }
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('无法打开链接：$url'),
      ),
    );
}

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

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(command.command),
      ),
    );

    if (!result.isSuccess) {
      await showDialog<void>(
        context: context,
        builder: (context) => _CommandOutputDialog(
          title: '命令执行失败',
          output: result.combinedOutput.isEmpty
              ? '没有输出内容。'
              : result.combinedOutput,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runningCommands = widget.controller.runningCommandTexts;
    return Stack(
      children: <Widget>[
        AnimatedBuilder(
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
                            hintText: '搜索可安装的包',
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
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.travel_explore_outlined),
                        label: const Text('搜索'),
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
                          label: const Text('全部'),
                          onSelected: (_) {
                            setState(() => _selectedSearchFilterId = null);
                          },
                        ),
                        ...filterIds.map((filterId) {
                          final representativeManagerId = widget.controller
                              .installSearchFilterRepresentativeManagerId(
                                filterId,
                              );
                          return FilterChip(
                            selected: _selectedSearchFilterId == filterId,
                            showCheckmark: false,
                            avatar: representativeManagerId == null
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
                            label: Text(
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
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
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
                                          color:
                                              theme.colorScheme.outlineVariant,
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
        ),
        if (runningCommands.isNotEmpty)
          Positioned(
            right: 24,
            bottom: 24,
            child: _RunningCommandToast(commands: runningCommands),
          ),
      ],
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
        isSearching ? '正在搜索...' : '输入关键词后搜索可安装的包。',
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
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: compact
          ? Row(
              children: <Widget>[
                Text('搜索结果', style: style),
                const Spacer(),
                Text('$count 项', style: style),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(flex: 5, child: Text('包名', style: style)),
                Expanded(flex: 2, child: Text('版本', style: style)),
                Expanded(flex: 3, child: Text('来源', style: style)),
                Expanded(flex: 5, child: Text('附加信息', style: style)),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('包管理器', style: style),
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
    final managerSummary = _searchPackageManagerSummary(package, controller);
    final source = _searchPackageSourceLine(package);
    final extra = _searchPackageExtraLine(package);
    final icons = _searchManagerIcons();

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
                      _searchPackageCompactSummaryLine(package, managerSummary),
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

  List<Widget> _searchManagerIcons() {
    return package.installOptions
        .map(
          (option) => Opacity(
            opacity: option.isInstalled ? 1 : 0.82,
            child: Tooltip(
              message: option.isInstalled
                  ? '${controller.displayNameForManagerId(option.managerId)} · 已安装'
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
          ),
        )
        .toList(growable: false);
  }

  Future<void> _showInstallMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
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
                      ? '使用 $label 安装特定版本'
                      : '$label 已安装'
                : isInstalling
                ? '$label 安装中'
                : '使用 $label 安装',
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

String _compactSummaryLine(ManagedPackage package) {
  final parts = <String>[
    '当前 ${package.version}',
    if (package.latestVersion != null) '最新 ${package.latestVersion}',
  ];
  return parts.join(' · ');
}

String _searchPackageCompactSummaryLine(
  SearchPackage package,
  String managerSummary,
) {
  final parts = <String>[
    managerSummary,
    if ((package.version ?? '').isNotEmpty) '版本 ${package.version}',
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
  return '${package.installOptions.length} 个包管理器';
}

String _searchPackageExtraLine(SearchPackage package) {
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
      '标识: ${package.identifier}',
    if (installedManagers.isNotEmpty) '已安装: ${installedManagers.join(', ')}',
  ];
  return parts.join(' · ');
}

String _extraLine(ManagedPackage package) {
  final parts = <String>[
    if (package.notes != null && package.notes!.trim().isNotEmpty)
      package.notes!,
    if (package.latestVersionCheckedAt != null)
      '上次检查 ${_formatCheckedAt(package.latestVersionCheckedAt!)}',
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
  'bun': 'assets/package_icons/bun.svg',
  'cargo': 'assets/package_icons/cargo.png',
  'choco': 'assets/package_icons/chocolatey.svg',
  'npm': 'assets/package_icons/npm.svg',
  'pip': 'assets/package_icons/python.svg',
  'pnpm': 'assets/package_icons/pnpm.svg',
  'uv': 'assets/package_icons/uv.svg',
  'winget': 'assets/package_icons/winget.ico',
};
