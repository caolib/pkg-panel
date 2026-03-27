import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'models/package_models.dart';
import 'services/package_panel_controller.dart';

void runPkgPanel(PackagePanelController controller) {
  runApp(PkgPanelApp(controller: controller));
}

class PkgPanelApp extends StatefulWidget {
  const PkgPanelApp({
    super.key,
    required this.controller,
    this.autoLoad = true,
  });

  final PackagePanelController controller;
  final bool autoLoad;

  @override
  State<PkgPanelApp> createState() => _PkgPanelAppState();
}

class _PkgPanelAppState extends State<PkgPanelApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '包管理面板',
      theme: _buildTheme(),
      home: PackagePanelHome(
        controller: widget.controller,
        autoLoad: widget.autoLoad,
      ),
    );
  }
}

ThemeData _buildTheme() {
  const seed = Color(0xFF0F766E);
  const primaryFont = 'Cascadia Code';
  const fallbackFonts = <String>[
    'JetBrains Mono',
    '喵字果汁体',
    '汉仪有圆',
    '霞鹜文楷',
    'Segoe UI Variable Text',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Segoe UI',
  ];
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );
  final baseTextTheme = ThemeData(useMaterial3: true).textTheme;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
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

class _PackagePanelHomeState extends State<PackagePanelHome> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _ActionBar(
                        controller: widget.controller,
                        searchController: _searchController,
                        onRefreshAll: widget.controller.loadAll,
                        onBatchCheckLatest: widget
                            .controller
                            .batchCheckLatestVersionsForSelectedManager,
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
                          onRunAction: _confirmAndRunCommand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
        content: Text(result.isSuccess ? '命令执行完成。' : '命令执行失败。'),
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
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.controller,
    required this.searchController,
    required this.onRefreshAll,
    required this.onBatchCheckLatest,
    required this.onBatchUpdate,
  });

  final PackagePanelController controller;
  final TextEditingController searchController;
  final Future<void> Function() onRefreshAll;
  final Future<void> Function() onBatchCheckLatest;
  final Future<void> Function() onBatchUpdate;

  @override
  Widget build(BuildContext context) {
    final batchCommand = controller.batchUpdateCommandForSelectedManager();
    final canBatchCheckLatest =
        controller.canBatchCheckLatestForSelectedManager;
    final isBatchCheckingLatest =
        controller.isBatchCheckingLatestForSelectedManager;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 380,
              child: SearchBar(
                controller: searchController,
                hintText: '搜索包名、来源、附加信息',
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
              onPressed: controller.isRefreshingAll ? null : onRefreshAll,
              icon: controller.isRefreshingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('刷新'),
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
            FilledButton.tonalIcon(
              onPressed: batchCommand == null ? null : onBatchUpdate,
              icon: const Icon(Icons.system_update_alt),
              label: const Text('批量更新'),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          FilterChip(
            selected: controller.selectedManagerId == null,
            showCheckmark: false,
            label: Text('全部 (${controller.totalPackages})'),
            onSelected: (_) => controller.selectManager(null),
          ),
          const SizedBox(width: 10),
          ...controller.snapshots.expand((snapshot) sync* {
            final label = switch (snapshot.loadState) {
              ManagerLoadState.error =>
                '${snapshot.manager.displayName} (加载失败)',
              ManagerLoadState.loading =>
                '${snapshot.manager.displayName} (刷新中)',
              _ =>
                '${snapshot.manager.displayName} (${snapshot.packages.length})',
            };
            yield FilterChip(
              selected: controller.selectedManagerId == snapshot.manager.id,
              showCheckmark: false,
              label: Text(label),
              avatar: _ManagerIcon(
                managerId: snapshot.manager.id,
                fallbackIcon: snapshot.manager.icon,
                fallbackColor: snapshot.manager.color,
              ),
              onSelected: (_) => controller.selectManager(snapshot.manager.id),
            );
            yield const SizedBox(width: 10);
          }),
        ],
      ),
    );
  }
}

class _PackageListView extends StatelessWidget {
  const _PackageListView({required this.controller, required this.onRunAction});

  final PackagePanelController controller;
  final Future<void> Function(PackageCommand command) onRunAction;

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
                  hasManagersLoading: controller.isRefreshingAll,
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
                Expanded(flex: 5, child: Text('附加信息', style: style)),
              ],
            ),
    );
  }
}

enum _PackageContextAction { checkLatest, update, remove }

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
    final updateCommand = controller.commandFor(PackageAction.update, package);
    final removeCommand = controller.commandFor(PackageAction.remove, package);
    final canCheckLatest = controller.canCheckLatestVersion(package);
    final isCheckingLatest = controller.isCheckingLatestVersion(package);
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
                flex: 5,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withAlpha(18)
            : Colors.transparent,
        child: InkWell(
          onTap: () => controller.selectPackage(
            package,
            additive: _isAdditiveSelectionPressed(),
            range: _isRangeSelectionPressed(),
          ),
          onSecondaryTapUp: (details) => _showContextMenu(
            context,
            details.globalPosition,
            canCheckLatest: canCheckLatest,
            isCheckingLatest: isCheckingLatest,
            isUpdating: isUpdating,
            isRemoving: isRemoving,
            updateCommand: updateCommand,
            removeCommand: removeCommand,
          ),
          child: Padding(padding: innerPadding, child: rowContent),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition, {
    required bool canCheckLatest,
    required bool isCheckingLatest,
    required bool isUpdating,
    required bool isRemoving,
    required PackageCommand? updateCommand,
    required PackageCommand? removeCommand,
  }) async {
    controller.selectPackageForContextMenu(package);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selectedAction = await showMenu<_PackageContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<_PackageContextAction>>[
        if (canCheckLatest)
          PopupMenuItem<_PackageContextAction>(
            value: _PackageContextAction.checkLatest,
            enabled: !isCheckingLatest,
            child: const _ContextMenuItemLabel(
              icon: Icons.find_replace_outlined,
              label: '检查更新',
            ),
          ),
        PopupMenuItem<_PackageContextAction>(
          value: _PackageContextAction.update,
          enabled: updateCommand != null && !isUpdating,
          child: _ContextMenuItemLabel(
            icon: Icons.system_update_alt,
            label: package.hasUpdate ? '升级' : '更新',
          ),
        ),
        PopupMenuItem<_PackageContextAction>(
          value: _PackageContextAction.remove,
          enabled: removeCommand != null && !isRemoving,
          child: const _ContextMenuItemLabel(
            icon: Icons.delete_outline,
            label: '删除',
          ),
        ),
      ],
    );

    if (selectedAction == null || !context.mounted) {
      return;
    }

    switch (selectedAction) {
      case _PackageContextAction.checkLatest:
        await controller.checkLatestVersion(package);
        return;
      case _PackageContextAction.update:
        if (updateCommand == null || isUpdating) {
          return;
        }
        await onRunAction(updateCommand);
        return;
      case _PackageContextAction.remove:
        if (removeCommand == null || isRemoving) {
          return;
        }
        await onRunAction(removeCommand);
        return;
    }
  }
}

class _ContextMenuItemLabel extends StatelessWidget {
  const _ContextMenuItemLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _ManagerIcon extends StatelessWidget {
  const _ManagerIcon({
    required this.managerId,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 18,
  });

  final String managerId;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetPath = _managerSvgAsset(managerId);
    if (assetPath == null) {
      return Icon(fallbackIcon, size: size, color: fallbackColor);
    }

    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        assetPath,
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            Icon(fallbackIcon, size: size, color: fallbackColor),
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
          const Text('将通过 PowerShell 执行下面的命令：'),
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
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontFamily: 'Consolas',
          height: 1.45,
        ),
      ),
    );
  }
}

class _EmptyPackages extends StatelessWidget {
  const _EmptyPackages({
    required this.hasManagersLoading,
    required this.searchQuery,
  });

  final bool hasManagersLoading;
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
            hasManagersLoading ? '正在刷新包管理器...' : '没有匹配的包',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isEmpty ? '可以先点击“刷新”。' : '没有找到“$searchQuery”的结果。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _compactSummaryLine(ManagedPackage package) {
  final parts = <String>[
    '当前 ${package.version}',
    if (package.latestVersion != null) '最新 ${package.latestVersion}',
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
  'npm': 'assets/package_icons/npm.svg',
  'pip': 'assets/package_icons/python.svg',
  'pnpm': 'assets/package_icons/pnpm.svg',
};
