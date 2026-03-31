import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import 'localization.dart';
import 'models/app_theme_palette.dart';
import 'models/package_models.dart';
import 'services/app_update_service.dart';
import 'services/external_link_opener.dart';
import 'services/local_file_picker.dart';
import 'services/package_panel_controller.dart';
import 'services/window_theme_sync.dart';
import 'widgets/linkified_selectable_text.dart';
import 'widgets/local_icon_image.dart';

void runPkgPanel(PackagePanelController controller) {
  runApp(PkgPanelApp(controller: controller));
}

const String _appDisplayName = 'Pkg Panel';
const String _appAuthor = 'caolib';
const String _appAuthorUrl = 'https://github.com/caolib';
const String _appRepositoryUrl = 'https://github.com/caolib/pkg-panel';
const String _defaultPrimaryFontFamily = 'Cascadia Code';
const List<String> _defaultFallbackFontFamilies = <String>[
  'JetBrains Mono',
  '喵字果汁体',
  '汉仪有圆',
  '霞鹜文楷',
  'Segoe UI Variable Text',
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Segoe UI',
];

void _showCompactSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  final theme = Theme.of(context);
  final mediaWidth = MediaQuery.sizeOf(context).width;
  const horizontalInset = 24.0;
  const bottomInset = 24.0;
  final availableWidth = math.max(160.0, mediaWidth - horizontalInset * 2);
  final targetMaxWidth = math.min(520.0, availableWidth);
  final textStyle =
      theme.snackBarTheme.contentTextStyle ??
      theme.textTheme.bodyMedium ??
      const TextStyle();
  final contentTextStyle = textStyle.copyWith(color: Colors.white);
  final textPainter = TextPainter(
    text: TextSpan(text: message, style: contentTextStyle),
    textDirection: Directionality.of(context),
    maxLines: 3,
  )..layout(maxWidth: targetMaxWidth - 72);
  final width = math.min(
    targetMaxWidth,
    math.max(160.0, textPainter.width + 72),
  );
  final leftInset = math.max(
    horizontalInset,
    mediaWidth - width - horizontalInset,
  );

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: leftInset,
          right: horizontalInset,
          bottom: bottomInset,
        ),
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: contentTextStyle,
        ),
      ),
    );
}

String _formatUiError(Object error) {
  return '$error'
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '')
      .replaceFirst('HttpException: ', '');
}

bool _isQueuedStatus(String? statusLabel) {
  final normalized = statusLabel?.trim();
  return normalized == '排队中' || normalized == 'Queued';
}

String _localizedCommandStatus(BuildContext context, RunningCommandInfo command) {
  final l10n = context.l10n;
  if (command.isCancelling) {
    return l10n.commandCancelling;
  }
  if (_isQueuedStatus(command.statusLabel)) {
    return l10n.commandStatusQueued;
  }
  return command.statusLabel ?? l10n.commandNotCancelable;
}

String _homeFilterGroupDisplayName(BuildContext context, HomeFilterGroup group) {
  return switch (group.kind) {
    HomeFilterGroupKind.all => context.l10n.homeFilterGroupAll,
    HomeFilterGroupKind.updates => context.l10n.homeFilterGroupUpdates,
    HomeFilterGroupKind.custom => group.displayName,
  };
}

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
  _WindowThemeSyncConfig? _lastSyncedWindowThemeConfig;
  _WindowThemeSyncConfig? _pendingWindowThemeConfig;
  bool _windowThemeSyncScheduled = false;

  @override
  void didUpdateWidget(covariant PkgPanelApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowThemeSync != widget.windowThemeSync) {
      _lastSyncedWindowThemeConfig = null;
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _scheduleWindowThemeSync(_WindowThemeSyncConfig config) {
    _pendingWindowThemeConfig = config;
    if (_windowThemeSyncScheduled) {
      return;
    }

    _windowThemeSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _windowThemeSyncScheduled = false;
      if (!mounted) {
        return;
      }

      final configToSync = _pendingWindowThemeConfig;
      _pendingWindowThemeConfig = null;
      if (configToSync == null || configToSync == _lastSyncedWindowThemeConfig) {
        return;
      }

      _lastSyncedWindowThemeConfig = configToSync;
      unawaited(
        widget.windowThemeSync.sync(
          themeMode: configToSync.themeMode,
          lightBackgroundColor: configToSync.lightBackgroundColor,
          darkBackgroundColor: configToSync.darkBackgroundColor,
          lightForegroundColor: configToSync.lightForegroundColor,
          darkForegroundColor: configToSync.darkForegroundColor,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final themeMode = widget.controller.themeMode;
        final lightTheme = _buildTheme(
          brightness: Brightness.light,
          seedColor: widget.controller.activeThemeSeedColor,
          customFontFamily: widget.controller.customFontFamily,
          customFallbackFontFamilies:
              widget.controller.customFallbackFontFamilies,
        );
        final darkTheme = _buildTheme(
          brightness: Brightness.dark,
          seedColor: widget.controller.activeThemeSeedColor,
          customFontFamily: widget.controller.customFontFamily,
          customFallbackFontFamilies:
              widget.controller.customFallbackFontFamilies,
        );
        _scheduleWindowThemeSync(
          _WindowThemeSyncConfig(
            themeMode: themeMode,
            lightBackgroundColor: lightTheme.scaffoldBackgroundColor,
            darkBackgroundColor: darkTheme.scaffoldBackgroundColor,
            lightForegroundColor: lightTheme.colorScheme.onSurface,
            darkForegroundColor: darkTheme.colorScheme.onSurface,
          ),
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => context.l10n.appTitle,
          locale: widget.controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          themeMode: themeMode,
          theme: lightTheme,
          darkTheme: darkTheme,
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
  required Color seedColor,
  required String? customFontFamily,
  required List<String> customFallbackFontFamilies,
}) {
  final primaryFont = customFontFamily?.trim().isNotEmpty == true
      ? customFontFamily!.trim()
      : _defaultPrimaryFontFamily;
  final fallbackFonts = customFallbackFontFamilies.isEmpty
      ? _defaultFallbackFontFamilies
      : customFallbackFontFamilies;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final baseTheme = ThemeData(useMaterial3: true, brightness: brightness);
  final baseTextTheme = baseTheme.textTheme;
  final scaffoldBackgroundColor = brightness == Brightness.dark
      ? Color.alphaBlend(
          colorScheme.primary.withAlpha(18),
          const Color(0xFF18181B),
        )
      : Color.alphaBlend(
          colorScheme.primary.withAlpha(10),
          const Color(0xFFF7F7F7),
        );

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
    appBarTheme: AppBarThemeData(
      centerTitle: false,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
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
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: colorScheme.primary,
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      dividerColor: colorScheme.outlineVariant,
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
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: colorScheme.onPrimary,
        backgroundColor: colorScheme.primary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    chipTheme: baseTheme.chipTheme.copyWith(
      selectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

String _themePaletteLabel(BuildContext context, String paletteId) {
  final l10n = context.l10n;
  return switch (paletteId) {
    defaultAppThemePaletteId => l10n.themePaletteTeal,
    'ocean' => l10n.themePaletteOcean,
    'sunset' => l10n.themePaletteSunset,
    'forest' => l10n.themePaletteForest,
    'berry' => l10n.themePaletteBerry,
    'slate' => l10n.themePaletteSlate,
    customAppThemePaletteId => l10n.themePaletteCustom,
    _ => paletteId,
  };
}

class _WindowThemeSyncConfig {
  const _WindowThemeSyncConfig({
    required this.themeMode,
    required this.lightBackgroundColor,
    required this.darkBackgroundColor,
    required this.lightForegroundColor,
    required this.darkForegroundColor,
  });

  final ThemeMode themeMode;
  final Color lightBackgroundColor;
  final Color darkBackgroundColor;
  final Color lightForegroundColor;
  final Color darkForegroundColor;

  @override
  bool operator ==(Object other) {
    return other is _WindowThemeSyncConfig &&
        other.themeMode == themeMode &&
        other.lightBackgroundColor.toARGB32() ==
            lightBackgroundColor.toARGB32() &&
        other.darkBackgroundColor.toARGB32() ==
            darkBackgroundColor.toARGB32() &&
        other.lightForegroundColor.toARGB32() ==
            lightForegroundColor.toARGB32() &&
        other.darkForegroundColor.toARGB32() ==
            darkForegroundColor.toARGB32();
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    lightBackgroundColor.toARGB32(),
    darkBackgroundColor.toARGB32(),
    lightForegroundColor.toARGB32(),
    darkForegroundColor.toARGB32(),
  );
}

String _formatThemeSeedColorHex(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color? _parseThemeSeedColorHex(String value) {
  final normalized = value.trim().replaceAll('#', '').replaceAll('0x', '');
  if (normalized.length != 6) {
    return null;
  }
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(0xFF000000 | parsed);
}

List<Color> _themePreviewColorsForPalette({
  required String paletteId,
  required Color customSeedColor,
}) {
  if (paletteId == customAppThemePaletteId) {
    final lightScheme = ColorScheme.fromSeed(seedColor: customSeedColor);
    return <Color>[
      customSeedColor,
      lightScheme.primaryContainer,
      lightScheme.secondaryContainer,
    ];
  }
  return appThemePaletteById(paletteId)?.previewColors ??
      appThemePaletteById(defaultAppThemePaletteId)!.previewColors;
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
  bool _hasQueuedStartupUpdateCheck = false;

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
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final runningCommands = widget.controller.runningCommands;
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
                        tabs: <Widget>[
                          Tab(text: context.l10n.tabLocal),
                          Tab(text: context.l10n.tabInstall),
                          Tab(text: context.l10n.tabSettings),
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
                    child: _RunningCommandToast(
                      commands: runningCommands,
                      onCancelCommand: (command) =>
                          unawaited(_cancelRunningCommand(command)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelRunningCommand(RunningCommandInfo command) async {
    final cancelled = await widget.controller.cancelRunningCommand(
      command.busyKey,
    );
    if (!mounted) {
      return;
    }

    _showCompactSnackBar(
      context,
      cancelled ? context.l10n.cancelRequested : context.l10n.commandCannotCancel,
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

    await widget.controller.batchCheckLatestVersionsForSelectedManager();
  }

  Future<void> _openSettings() async {
    _tabController.animateTo(2);
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
  const _RunningCommandToast({required this.commands, this.onCancelCommand});

  final List<RunningCommandInfo> commands;
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
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 360),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    command.command,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Cascadia Code',
                                      fontFamilyFallback: theme
                                          .textTheme
                                          .bodyMedium
                                          ?.fontFamilyFallback,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (command.canCancel)
                                  command.isCancelling
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          tooltip: l10n.commandCancelTooltip,
                                          onPressed: () =>
                                              onCancelCommand?.call(command),
                                          icon: const Icon(
                                            Icons.stop_circle_outlined,
                                          ),
                                        )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _localizedCommandStatus(context, command),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(l10n.buttonRefresh),
            ),
            if (hasLoadErrors)
              FilledButton.tonalIcon(
                onPressed: onShowLoadErrors,
                icon: const Icon(Icons.error_outline),
                label: Text(l10n.viewLoadErrorsButton(controller.errorManagers)),
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
            ManagerLoadState.error =>
              l10n.managerLoadFailedSuffix(
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
        final compact = constraints.maxWidth < 1120;
        final theme = Theme.of(context);
        final borderRadius = BorderRadius.circular(18);

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: borderRadius,
          ),
          foregroundDecoration: BoxDecoration(
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
                      child: ListView.separated(
                        itemCount: packages.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant,
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
    final l10n = context.l10n;
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
                Expanded(flex: 5, child: Text(l10n.packageNameColumn, style: style)),
                Expanded(flex: 2, child: Text(l10n.currentVersionColumn, style: style)),
                Expanded(flex: 2, child: Text(l10n.latestVersionColumn, style: style)),
                Expanded(flex: 8, child: Text(l10n.extraInfoColumn, style: style)),
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
    final extra = _extraLine(context, package);
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
                              const CircularProgressIndicator(),
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
      if (!showFallbackWhenNoAsset) {
        return const SizedBox.shrink();
      }
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
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: output));
            if (!context.mounted) {
              return;
            }
            _showCompactSnackBar(context, l10n.copyToClipboardSuccess);
          },
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
                        Text(l10n.pendingCommandLabel, style: theme.textTheme.labelLarge),
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
                          message: l10n.loadVersionListFailed('${
                            snapshot.error
                          }'),
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
                                      : l10n
                                            .availableVersionListTruncatedFiltered(
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
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    );
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

class PackageSettingsPage extends StatelessWidget {
  const PackageSettingsPage({
    super.key,
    required this.controller,
    this.filePicker = const LocalFilePicker(),
  });

  final PackagePanelController controller;
  final LocalFilePicker filePicker;

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

  String? _managerCustomizationSummary(
    BuildContext context,
    PackageManagerVisibilityState state,
  ) {
    final l10n = context.l10n;
    final parts = <String>[];
    final customName = controller.customManagerDisplayName(state.manager.id);
    if (customName != null &&
        customName.trim() != state.manager.displayName.trim()) {
      parts.add(l10n.managerOriginalName(state.manager.displayName));
    }
    if (controller.customManagerIconPath(state.manager.id) != null) {
      parts.add(l10n.managerCustomIconSet);
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }

  String _homeFilterGroupSummary(BuildContext context, HomeFilterGroup group) {
    final l10n = context.l10n;
    return switch (group.kind) {
      HomeFilterGroupKind.all => l10n.homeFilterSummaryAll,
      HomeFilterGroupKind.updates => l10n.homeFilterSummaryUpdates,
      HomeFilterGroupKind.custom => [
        if (group.managerIds.isNotEmpty)
          l10n.homeFilterSummaryManagers(group.managerIds.length),
        if (group.packageKeys.isNotEmpty)
          l10n.homeFilterSummaryPackages(group.packageKeys.length),
        if (group.managerIds.isEmpty && group.packageKeys.isEmpty)
          l10n.homeFilterSummaryUnconfigured,
      ].join(' · '),
    };
  }

  Future<void> _editManager(
    BuildContext context,
    PackageManagerVisibilityState state,
  ) async {
    final result = await showDialog<_ManagerEditOutcome>(
      context: context,
      builder: (dialogContext) => _ManagerEditDialog(
        controller: controller,
        state: state,
        filePicker: filePicker,
      ),
    );

    if (result == null || !context.mounted || result.changedParts.isEmpty) {
      return;
    }

    _showCompactSnackBar(
      context,
      context.l10n.managerUpdatedMessage(
        result.managerName,
        result.changedParts.join(' / '),
      ),
    );
  }

  Future<void> _addHomeFilterGroup(BuildContext context) async {
    final draft = await showDialog<_HomeFilterGroupDraft>(
      context: context,
      builder: (dialogContext) => _HomeFilterGroupEditDialog(
        controller: controller,
        filePicker: filePicker,
      ),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    await controller.createHomeFilterGroup(
      displayName: draft.displayName,
      iconPath: draft.iconPath,
      managerIds: draft.managerIds,
      packageKeys: draft.packageKeys,
    );

    if (!context.mounted) {
      return;
    }

    _showCompactSnackBar(
      context,
      context.l10n.groupAddedMessage(draft.displayName),
    );
  }

  Future<void> _editHomeFilterGroup(
    BuildContext context,
    HomeFilterGroup group,
  ) async {
    final result = await showDialog<_HomeFilterGroupDraft>(
      context: context,
      builder: (dialogContext) => _HomeFilterGroupEditDialog(
        controller: controller,
        group: group,
        filePicker: filePicker,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }

    if (result.deleteGroup) {
      await controller.deleteHomeFilterGroup(group.id);
      if (!context.mounted) {
        return;
      }
      _showCompactSnackBar(
        context,
        context.l10n.groupDeletedMessage(
          _homeFilterGroupDisplayName(context, group),
        ),
      );
      return;
    }

    await controller.updateHomeFilterGroup(
      group.copyWith(
        displayName: result.displayName,
        iconPath: result.iconPath,
        clearIconPath: result.iconPath == null,
        managerIds: result.managerIds,
        packageKeys: result.packageKeys,
      ),
    );
    if (!context.mounted) {
      return;
    }

    _showCompactSnackBar(
      context,
      context.l10n.groupUpdatedMessage(result.displayName),
    );
  }

  List<String> _currentFontFamilyStack() {
    final configured = <String>[
      if (controller.customFontFamily != null) controller.customFontFamily!,
      ...controller.customFallbackFontFamilies,
    ];
    if (configured.isNotEmpty) {
      return configured;
    }
    return <String>[_defaultPrimaryFontFamily, ..._defaultFallbackFontFamilies];
  }

  Future<void> _editFontFamilyStack(BuildContext context) async {
    final l10n = context.l10n;
    final textController = TextEditingController(
      text: _currentFontFamilyStack().join(', '),
    );
    final fontSuggestions = <String>{
      _defaultPrimaryFontFamily,
      ..._defaultFallbackFontFamilies,
      ..._fontSuggestions,
      ..._fallbackFontSuggestions,
    }.toList(growable: false);

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.editFontStackTitle),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.commaSeparatedHint),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: l10n.fontStackInputHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: fontSuggestions
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
                                } else if (current.isEmpty) {
                                  textController.text = font;
                                }
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
                  child: Text(l10n.buttonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: Text(l10n.buttonRestoreDefault),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(textController.text),
                  child: Text(l10n.buttonSave),
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
    await controller.setFontFamilyStack(fonts);
  }

  Widget _buildGeneralTab(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.languageTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<Locale>(
                    segments: <ButtonSegment<Locale>>[
                      ButtonSegment<Locale>(
                        value: const Locale('zh'),
                        label: Text(l10n.languageChinese),
                        icon: const Icon(Icons.translate_outlined),
                      ),
                      ButtonSegment<Locale>(
                        value: const Locale('en'),
                        label: Text(l10n.languageEnglish),
                        icon: const Icon(Icons.language_outlined),
                      ),
                    ],
                    selected: <Locale>{controller.locale},
                    onSelectionChanged: (values) {
                      unawaited(controller.setLocale(values.first));
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
                  Text(
                    l10n.themeModeTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text(l10n.themeModeSystem),
                        icon: const Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text(l10n.themeModeLight),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeModeDark),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: <ThemeMode>{controller.themeMode},
                    onSelectionChanged: (values) {
                      unawaited(controller.setThemeMode(values.first));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editCustomThemeSeedColor(BuildContext context) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => _ThemeSeedColorDialog(
        initialColor: controller.customThemeSeedColor,
      ),
    );
    if (color == null || !context.mounted) {
      return;
    }

    await controller.setCustomThemeSeedColor(color, selectCustomPalette: true);
    if (!context.mounted) {
      return;
    }

    _showCompactSnackBar(
      context,
      context.l10n.customThemeUpdated(_formatThemeSeedColorHex(color)),
    );
  }

  Widget _buildAppearanceTab(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    final paletteIds = <String>[
      ...appThemePalettes.map((palette) => palette.id),
      customAppThemePaletteId,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.colorThemeTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.colorThemeDescription,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.tonalIcon(
                        onPressed: () => _editCustomThemeSeedColor(context),
                        icon: const Icon(Icons.palette_outlined),
                        label: Text(l10n.buttonCustomizeTheme),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: paletteIds
                        .map((paletteId) => _ThemePaletteOptionCard(
                              label: _themePaletteLabel(context, paletteId),
                              detail: paletteId == customAppThemePaletteId
                                  ? _formatThemeSeedColorHex(
                                      controller.customThemeSeedColor,
                                    )
                                  : null,
                              previewColors: _themePreviewColorsForPalette(
                                paletteId: paletteId,
                                customSeedColor: controller.customThemeSeedColor,
                              ),
                              selected: controller.themePaletteId == paletteId,
                              onTap: () => unawaited(
                                controller.setThemePaletteId(paletteId),
                              ),
                            ))
                        .toList(growable: false),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.fontStackTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentFontFamilyStack().join(', '),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _editFontFamilyStack(context),
                        child: Text(l10n.buttonSetFont),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.fontStackDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Text(l10n.fontPreview),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: <Widget>[
          TabBar(
            tabs: <Widget>[
              Tab(text: l10n.settingsTabGeneral),
              Tab(text: l10n.settingsTabManagers),
              Tab(text: l10n.settingsTabAppearance),
              Tab(text: l10n.settingsTabAbout),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final homeFilterGroups = controller.homeFilterGroups;
                final states = controller.managerVisibilityStates;
                return TabBarView(
                  children: <Widget>[
                    _buildGeneralTab(context, theme),
                    ListView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  l10n.settingsManagersDescription,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => _addHomeFilterGroup(context),
                              icon: const Icon(Icons.add),
                              label: Text(l10n.buttonAddGroup),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed:
                                  controller.isRefreshingManagerAvailability
                                  ? null
                                  : () async {
                                      await controller
                                          .refreshManagerAvailability();
                                    },
                              icon: controller.isRefreshingManagerAvailability
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_outlined),
                              label: Text(l10n.buttonRefreshStatus),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                        l10n.groupColumn,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        l10n.descriptionColumn,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        l10n.enabledColumn,
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
                                itemCount: homeFilterGroups.length,
                                onReorder: (oldIndex, newIndex) {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  controller.reorderHomeFilterGroup(
                                    oldIndex,
                                    newIndex,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final group = homeFilterGroups[index];
                                  final iconPath = controller
                                      .iconPathForHomeFilterGroup(group.id);
                                  final hasIcon = iconPath != null;
                                  return DecoratedBox(
                                    key: ValueKey(group.id),
                                    decoration: BoxDecoration(
                                      border:
                                          index == homeFilterGroups.length - 1
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
                                                if (hasIcon)
                                                  _ManagerIcon(
                                                    managerId: group.id,
                                                    customIconPath: iconPath,
                                                    fallbackIcon: Icons
                                                        .filter_alt_outlined,
                                                    fallbackColor: theme
                                                        .colorScheme
                                                        .primary,
                                                    size: 20,
                                                    showFallbackWhenNoAsset:
                                                        false,
                                                  ),
                                                if (hasIcon)
                                                  const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      Text(
                                                        _homeFilterGroupDisplayName(
                                                          context,
                                                          group,
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
                                                      Text(
                                                        group.kind ==
                                                                HomeFilterGroupKind
                                                                    .custom
                                                            ? l10n.customGroupType
                                                            : l10n
                                                                  .builtinGroupType,
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
                                                  group.isVisible
                                                      ? l10n.groupVisibleOnHome
                                                      : l10n.groupHiddenOnHome,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: group.isVisible
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
                                                  _homeFilterGroupSummary(
                                                    context,
                                                    group,
                                                  ),
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
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: <Widget>[
                                                  OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _editHomeFilterGroup(
                                                          context,
                                                          group,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 18,
                                                    ),
                                                    label: Text(l10n.buttonEdit),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Switch(
                                                    value: group.isVisible,
                                                    onChanged: (value) => controller
                                                        .setHomeFilterGroupVisibility(
                                                          group.id,
                                                          value,
                                                        ),
                                                  ),
                                                ],
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
                        const SizedBox(height: 12),
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
                                        l10n.packageManagerColumn,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        l10n.statusColumn,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        l10n.enabledColumn,
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
                                                      if (_managerCustomizationSummary(
                                                            context,
                                                            state,
                                                          ) !=
                                                          null) ...<Widget>[
                                                        Text(
                                                          _managerCustomizationSummary(
                                                            context,
                                                            state,
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
                                                      ? l10n.managerDetected
                                                      : l10n.managerNotDetected,
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
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: <Widget>[
                                                  OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _editManager(
                                                          context,
                                                          state,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 18,
                                                    ),
                                                    label: Text(l10n.buttonEdit),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Switch(
                                                    value: state.isVisible,
                                                    onChanged: (value) =>
                                                        controller
                                                            .setManagerVisibility(
                                                              state.manager.id,
                                                              value,
                                                            ),
                                                  ),
                                                ],
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
                    _buildAppearanceTab(context, theme),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: _AboutAppCard(
                        theme: theme,
                        controller: controller,
                      ),
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

class _ThemePaletteOptionCard extends StatelessWidget {
  const _ThemePaletteOptionCard({
    required this.label,
    required this.previewColors,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String? detail;
  final List<Color> previewColors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = selected
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerLowest;
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return SizedBox(
      width: 196,
      child: Material(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor, width: selected ? 1.4 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (var i = 0; i < previewColors.length; i++)
                      Transform.translate(
                        offset: Offset(i == 0 ? 0 : -10.0 * i, 0),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: previewColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeSeedColorDialog extends StatefulWidget {
  const _ThemeSeedColorDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_ThemeSeedColorDialog> createState() => _ThemeSeedColorDialogState();
}

class _ThemeSeedColorDialogState extends State<_ThemeSeedColorDialog> {
  late final TextEditingController _hexController;
  Color? _candidateColor;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(
      text: _formatThemeSeedColorHex(widget.initialColor),
    );
    _candidateColor = widget.initialColor;
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyColor(Color color) {
    setState(() {
      _candidateColor = color;
      _hexController.value = TextEditingValue(
        text: _formatThemeSeedColorHex(color),
        selection: TextSelection.collapsed(
          offset: _formatThemeSeedColorHex(color).length,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final previewColor = _candidateColor ?? widget.initialColor;
    final previewScheme = ColorScheme.fromSeed(seedColor: previewColor);
    final quickColors = <Color>[
      for (final palette in appThemePalettes) palette.seedColor,
      defaultCustomAppThemeSeedColor,
    ];

    return AlertDialog(
      title: Text(l10n.customThemeDialogTitle),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: previewColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.colorPreviewLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatThemeSeedColorHex(previewColor),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final color in <Color>[
                        previewScheme.primary,
                        previewScheme.secondary,
                        previewScheme.tertiary,
                      ])
                        Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hexController,
              autofocus: true,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: InputDecoration(
                labelText: l10n.colorHexLabel,
                border: const OutlineInputBorder(),
                hintText: l10n.colorHexHint,
                errorText: _candidateColor == null
                    ? l10n.colorHexInvalid
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _candidateColor = _parseThemeSeedColorHex(value);
                });
              },
            ),
            const SizedBox(height: 14),
            Text(
              l10n.quickColorTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: quickColors
                  .map(
                    (color) => InkWell(
                      onTap: () => _applyColor(color),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: previewColor.toARGB32() == color.toARGB32()
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.outlineVariant,
                            width:
                                previewColor.toARGB32() == color.toARGB32()
                                ? 2.2
                                : 1,
                          ),
                        ),
                      ),
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
          child: Text(l10n.buttonCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(defaultCustomAppThemeSeedColor),
          child: Text(l10n.buttonRestoreDefault),
        ),
        FilledButton(
          onPressed: _candidateColor == null
              ? null
              : () => Navigator.of(context).pop(_candidateColor),
          child: Text(l10n.buttonSave),
        ),
      ],
    );
  }
}

class _HomeFilterGroupDraft {
  const _HomeFilterGroupDraft({
    required this.displayName,
    required this.iconPath,
    required this.managerIds,
    required this.packageKeys,
    this.deleteGroup = false,
  });

  final String displayName;
  final String? iconPath;
  final List<String> managerIds;
  final List<String> packageKeys;
  final bool deleteGroup;
}

class _HomeFilterGroupEditDialog extends StatefulWidget {
  const _HomeFilterGroupEditDialog({
    required this.controller,
    required this.filePicker,
    this.group,
  });

  final PackagePanelController controller;
  final LocalFilePicker filePicker;
  final HomeFilterGroup? group;

  @override
  State<_HomeFilterGroupEditDialog> createState() =>
      _HomeFilterGroupEditDialogState();
}

class _HomeFilterGroupEditDialogState
    extends State<_HomeFilterGroupEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _packageSearchController;
  late String? _selectedIconPath;
  late Set<String> _selectedManagerIds;
  late Set<String> _selectedPackageKeys;
  final bool _isSaving = false;

  bool get _isCustomGroup =>
      widget.group == null || widget.group!.kind == HomeFilterGroupKind.custom;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.group?.displayName ?? '',
    );
    _packageSearchController = TextEditingController();
    _selectedIconPath = widget.group?.iconPath;
    _selectedManagerIds = Set<String>.from(
      widget.group?.managerIds ?? const <String>{},
    );
    _selectedPackageKeys = Set<String>.from(
      widget.group?.packageKeys ?? const <String>{},
    );
    _packageSearchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packageSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final pickedPath = await widget.filePicker.pickManagerIconFile();
    if (!mounted || pickedPath == null) {
      return;
    }
    setState(() {
      _selectedIconPath = pickedPath;
    });
  }

  void _save() {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _HomeFilterGroupDraft(
        displayName: displayName,
        iconPath: _selectedIconPath?.trim().isEmpty ?? true
            ? null
            : _selectedIconPath?.trim(),
        managerIds: _selectedManagerIds.toList(growable: false),
        packageKeys: _selectedPackageKeys.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final managerStates = widget.controller.managerVisibilityStates;
    final packages =
        widget.controller.snapshots
            .expand((snapshot) => snapshot.packages)
            .toList(growable: false)
          ..sort((a, b) {
            final managerCompare = widget.controller
                .displayNameForPackage(a)
                .compareTo(widget.controller.displayNameForPackage(b));
            if (managerCompare != 0) {
              return managerCompare;
            }
            return a.name.compareTo(b.name);
          });
    final packageFilter = _packageSearchController.text.trim().toLowerCase();
    final visiblePackages = packages
        .where((package) {
          if (packageFilter.isEmpty) {
            return true;
          }
          return [
            package.name,
            widget.controller.displayNameForPackage(package),
            package.version,
          ].join(' ').toLowerCase().contains(packageFilter);
        })
        .toList(growable: false);
    final hasIcon =
        _selectedIconPath != null && _selectedIconPath!.trim().isNotEmpty;

    return AlertDialog(
      title: Text(
        widget.group == null
            ? l10n.dialogAddGroupTitle
            : l10n.dialogEditGroupTitle(widget.group!.displayName),
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.groupNameLabel,
                  border: OutlineInputBorder(),
                  hintText: l10n.groupNameHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.iconLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    if (hasIcon)
                      _ManagerIcon(
                        managerId: widget.group?.id ?? 'new_group',
                        customIconPath: _selectedIconPath,
                        fallbackIcon: Icons.filter_alt_outlined,
                        fallbackColor: theme.colorScheme.primary,
                        size: 20,
                        showFallbackWhenNoAsset: false,
                      ),
                    if (hasIcon) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedIconPath ?? l10n.iconNotSet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.iconFormatsHint),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : _pickIcon,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(
                      _selectedIconPath == null
                          ? l10n.buttonSelectIcon
                          : l10n.buttonChangeIcon,
                    ),
                  ),
                  if (_selectedIconPath != null)
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _selectedIconPath = null;
                              });
                            },
                      child: Text(l10n.buttonRemoveIcon),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isCustomGroup) ...<Widget>[
                Text(
                  l10n.includedManagersLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: managerStates
                      .map((state) {
                        final selected = _selectedManagerIds.contains(
                          state.manager.id,
                        );
                        return FilterChip(
                          selected: selected,
                          label: Text(
                            widget.controller.displayNameForManagerId(
                              state.manager.id,
                            ),
                          ),
                          avatar: _ManagerIcon(
                            managerId: state.manager.id,
                            customIconPath: widget.controller
                                .customManagerIconPath(state.manager.id),
                            fallbackIcon: state.manager.icon,
                            fallbackColor: state.manager.color,
                          ),
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedManagerIds.add(state.manager.id);
                              } else {
                                _selectedManagerIds.remove(state.manager.id);
                              }
                            });
                          },
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.includedPackagesLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _packageSearchController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.searchLocalHint,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: visiblePackages.isEmpty
                      ? Center(
                          child: Text(
                            packageFilter.isEmpty
                                ? l10n.noLocalPackages
                                : l10n.emptyNoMatchingPackages,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: visiblePackages.length,
                          itemBuilder: (context, index) {
                            final package = visiblePackages[index];
                            final selected = _selectedPackageKeys.contains(
                              package.key,
                            );
                            return CheckboxListTile(
                              dense: true,
                              value: selected,
                              title: Text(package.name),
                              subtitle: Text(
                                '${widget.controller.displayNameForPackage(package)} · ${package.version}',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (value ?? false) {
                                    _selectedPackageKeys.add(package.key);
                                  } else {
                                    _selectedPackageKeys.remove(package.key);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ] else ...<Widget>[
                Text(
                  widget.group?.kind == HomeFilterGroupKind.all
                      ? l10n.builtinAllGroupHint
                      : l10n.builtinUpdatesGroupHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (widget.group != null && _isCustomGroup)
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              const _HomeFilterGroupDraft(
                displayName: '',
                iconPath: null,
                managerIds: <String>[],
                packageKeys: <String>[],
                deleteGroup: true,
              ),
            ),
            child: Text(l10n.buttonDeleteGroup),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.buttonCancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(l10n.buttonSave),
        ),
      ],
    );
  }
}

class _ManagerEditDialog extends StatefulWidget {
  const _ManagerEditDialog({
    required this.controller,
    required this.state,
    required this.filePicker,
  });

  final PackagePanelController controller;
  final PackageManagerVisibilityState state;
  final LocalFilePicker filePicker;

  @override
  State<_ManagerEditDialog> createState() => _ManagerEditDialogState();
}

class _ManagerEditDialogState extends State<_ManagerEditDialog> {
  late final TextEditingController _nameController;
  late String? _selectedIconPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text:
          widget.controller.customManagerDisplayName(widget.state.manager.id) ??
          widget.state.manager.displayName,
    );
    _selectedIconPath = widget.controller.customManagerIconPath(
      widget.state.manager.id,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final pickedPath = await widget.filePicker.pickManagerIconFile();
    if (!mounted || pickedPath == null) {
      return;
    }
    setState(() {
      _selectedIconPath = pickedPath;
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final l10n = context.l10n;
    final managerId = widget.state.manager.id;
    final originalDisplayName = widget.state.manager.displayName.trim();
    final currentCustomDisplayName = widget.controller
        .customManagerDisplayName(managerId)
        ?.trim();
    final currentIconPath = widget.controller.customManagerIconPath(managerId);
    final normalizedDisplayName = _nameController.text.trim();
    final nextIconPath = _selectedIconPath?.trim();
    final changedParts = <String>[];
    var shouldResetSaving = true;

    setState(() {
      _isSaving = true;
    });

    try {
      if (normalizedDisplayName.isEmpty ||
          normalizedDisplayName == originalDisplayName) {
        if (currentCustomDisplayName != null) {
          await widget.controller.clearCustomManagerDisplayName(managerId);
          changedParts.add(l10n.changedDisplayName);
        }
      } else if (normalizedDisplayName != currentCustomDisplayName) {
        await widget.controller.setCustomManagerDisplayName(
          managerId,
          normalizedDisplayName,
        );
        changedParts.add(l10n.changedDisplayName);
      }

      if (nextIconPath == null || nextIconPath.isEmpty) {
        if (currentIconPath != null) {
          await widget.controller.clearCustomManagerIconPath(managerId);
          changedParts.add(l10n.changedIcon);
        }
      } else if (nextIconPath != currentIconPath) {
        await widget.controller.setCustomManagerIconPath(
          managerId,
          nextIconPath,
        );
        changedParts.add(l10n.changedIcon);
      }

      if (!mounted) {
        return;
      }

      shouldResetSaving = false;
      Navigator.of(context).pop(
        _ManagerEditOutcome(
          managerName: widget.controller.displayNameForManagerId(managerId),
          changedParts: changedParts,
        ),
      );
    } finally {
      if (mounted && shouldResetSaving) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final managerId = widget.state.manager.id;
    return AlertDialog(
      title: Text(
        l10n.editManagerTitle(
          widget.controller.displayNameForManagerId(managerId),
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.displayNameLabel,
                  border: OutlineInputBorder(),
                  hintText: l10n.displayNameHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.iconLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    _ManagerIcon(
                      managerId: managerId,
                      customIconPath: _selectedIconPath,
                      fallbackIcon: widget.state.manager.icon,
                      fallbackColor: widget.state.manager.color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedIconPath ?? l10n.defaultIconLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.iconFormatsHint),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : _pickIcon,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(
                      _selectedIconPath == null
                          ? l10n.buttonSelectIcon
                          : l10n.buttonChangeIcon,
                    ),
                  ),
                  if (_selectedIconPath != null)
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _selectedIconPath = null;
                              });
                            },
                      child: Text(l10n.buttonResetDefaultIcon),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.buttonCancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? l10n.saveInProgress : l10n.buttonSave),
        ),
      ],
    );
  }
}

class _ManagerEditOutcome {
  const _ManagerEditOutcome({
    required this.managerName,
    required this.changedParts,
  });

  final String managerName;
  final List<String> changedParts;
}

class _AboutAppCard extends StatelessWidget {
  const _AboutAppCard({required this.theme, required this.controller});

  final ThemeData theme;
  final PackagePanelController controller;

  Future<void> _editGithubMirrorBaseUrl(BuildContext context) async {
    final l10n = context.l10n;
    final textController = TextEditingController(
      text: controller.githubMirrorBaseUrl,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.editGithubMirrorTitle),
          content: SizedBox(
            width: 560,
            child: TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: l10n.githubMirrorHint,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.buttonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: Text(l10n.buttonRestoreDefault),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(textController.text),
              child: Text(l10n.buttonSave),
            ),
          ],
        );
      },
    );
    textController.dispose();

    if (value == null || !context.mounted) {
      return;
    }

    await controller.setGithubMirrorBaseUrl(value);
    if (!context.mounted) {
      return;
    }
    _showCompactSnackBar(context, l10n.githubMirrorUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.aboutTitle,
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
                l10n.appTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _AboutMetaRow(controller: controller),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return Column(
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: SwitchListTile.adaptive(
                        value: controller.autoCheckAppUpdates,
                        onChanged: (value) {
                          unawaited(controller.setAutoCheckAppUpdates(value));
                        },
                        title: Text(l10n.autoCheckUpdatesTitle),
                        subtitle: Text(l10n.autoCheckUpdatesSubtitle),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          SwitchListTile.adaptive(
                            value: controller.useGithubMirrorForDownloads,
                            onChanged: (value) {
                              unawaited(
                                controller.setUseGithubMirrorForDownloads(
                                  value,
                                ),
                              );
                            },
                            title: Text(l10n.githubMirrorTitle),
                            subtitle: Text(l10n.githubMirrorSubtitle),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        l10n.githubMirrorBaseUrlLabel,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      SelectableText(
                                        controller.githubMirrorBaseUrl,
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
                                const SizedBox(width: 12),
                                FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _editGithubMirrorBaseUrl(context),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: Text(l10n.buttonEdit),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutMetaRow extends StatelessWidget {
  const _AboutMetaRow({required this.controller});

  final PackagePanelController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final packageInfo = snapshot.data;
        final versionLabel = packageInfo == null
            ? context.l10n.versionLoading
            : packageInfo.buildNumber.trim().isEmpty
            ? packageInfo.version
            : '${packageInfo.version}+${packageInfo.buildNumber}';
        final theme = Theme.of(context);
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
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
                    onPressed: () =>
                        _openExternalLink(context, _appRepositoryUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(context.l10n.buttonGitHubRepo),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: controller.isCheckingAppUpdate
                        ? null
                        : () {
                            unawaited(
                              _checkForAppUpdateWithUi(context, controller),
                            );
                          },
                    icon: controller.isCheckingAppUpdate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                    label: Text(
                      controller.isCheckingAppUpdate
                          ? context.l10n.checkingUpdates
                          : context.l10n.buttonCheckUpdates,
                    ),
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
  _showCompactSnackBar(context, context.l10n.openLinkFailed(url));
}

Future<void> _checkForAppUpdateWithUi(
  BuildContext context,
  PackagePanelController controller, {
  bool showAlreadyLatestMessage = true,
  bool showErrorMessage = true,
}) async {
  AppUpdateInfo info;
  try {
    info = await controller.checkForAppUpdate();
  } catch (error) {
    if (!context.mounted || !showErrorMessage) {
      return;
    }
    _showCompactSnackBar(
      context,
      context.l10n.checkUpdatesFailed(_formatUiError(error)),
    );
    return;
  }

  if (!context.mounted) {
    return;
  }
  if (!info.hasUpdate) {
    if (showAlreadyLatestMessage) {
      _showCompactSnackBar(
        context,
        context.l10n.alreadyLatestVersion(info.currentDisplayVersion),
      );
    }
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => _AppUpdateDialog(controller: controller, info: info),
  );
}

String _appReleaseAssetKindLabel(BuildContext context, AppReleaseAssetKind kind) {
  return switch (kind) {
    AppReleaseAssetKind.installer => context.l10n.releaseAssetInstaller,
    AppReleaseAssetKind.portable => context.l10n.releaseAssetPortable,
    AppReleaseAssetKind.other => context.l10n.releaseAssetOther,
  };
}

String _formatAppReleaseAssetSize(int bytes) {
  if (bytes <= 0) {
    return '';
  }
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  final precision = unitIndex == 0 ? 0 : 1;
  return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
}

String _buildDownloadProgressLabel(
  BuildContext context,
  AppUpdateDownloadProgress? progress,
) {
  if (progress == null) {
    return context.l10n.downloadPreparing;
  }
  final received = _formatAppReleaseAssetSize(progress.receivedBytes);
  final total = progress.totalBytes;
  final percent = progress.progress;
  if (total == null || total <= 0 || percent == null) {
    return context.l10n.downloadedBytes(received);
  }
  return context.l10n.downloadedProgress(
    received,
    _formatAppReleaseAssetSize(total),
    (percent * 100).toStringAsFixed(0),
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.controller, required this.info});

  final PackagePanelController controller;
  final AppUpdateInfo info;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  String? _activeDownloadUrl;
  AppUpdateDownloadProgress? _downloadProgress;
  bool _isDisablingAutoCheck = false;
  bool _autoCheckDisabledInDialog = false;

  Future<void> _disableAutoCheck() async {
    if (_isDisablingAutoCheck || _autoCheckDisabledInDialog) {
      return;
    }

    setState(() {
      _isDisablingAutoCheck = true;
    });
    try {
      await widget.controller.setAutoCheckAppUpdates(false);
      if (!mounted) {
        return;
      }
      setState(() {
        _autoCheckDisabledInDialog = true;
      });
      _showCompactSnackBar(context, context.l10n.autoCheckDisabled);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showCompactSnackBar(
        context,
        context.l10n.disableAutoCheckFailed(_formatUiError(error)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDisablingAutoCheck = false;
        });
      }
    }
  }

  Future<void> _downloadAsset(AppReleaseAsset asset) async {
    if (_activeDownloadUrl != null) {
      return;
    }

    setState(() {
      _activeDownloadUrl = asset.downloadUrl;
      _downloadProgress = const AppUpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      );
    });
    try {
      final result = await widget.controller.downloadAppUpdateAsset(
        asset,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
      if (!mounted) {
        return;
      }

      final message = asset.startsInstaller
          ? result.startedInstaller
                ? context.l10n.installerStarted
                : context.l10n.installerDownloadedNotStarted
          : result.openedLocation
          ? context.l10n.downloadedAndOpenedFolder
          : context.l10n.downloadCompleted;
      _showCompactSnackBar(context, message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showCompactSnackBar(
        context,
        context.l10n.downloadFailed(_formatUiError(error)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeDownloadUrl = null;
          _downloadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final assets = widget.info.assets;
    final currentVersion = widget.info.currentVersion;
    final latestVersion = widget.info.latestVersion;
    final releaseNotes = widget.info.releaseBody.trim();
    return AlertDialog(
      title: Text(l10n.updateAvailableTitle),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: l10n.versionTransition(currentVersion, latestVersion),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.releaseNotesTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SingleChildScrollView(
                child: releaseNotes.isEmpty
                    ? Text(
                        l10n.releaseNotesEmpty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : LinkifiedSelectableText(
                        text: releaseNotes,
                        style: theme.textTheme.bodyMedium,
                        onOpenLink: (url) => _openExternalLink(context, url),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              assets.isEmpty ? l10n.releaseAssetsEmpty : l10n.releaseAssetsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (assets.isNotEmpty) const SizedBox(height: 10),
            if (assets.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: assets
                        .map(
                          (asset) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Icon(
                                        asset.startsInstaller
                                            ? Icons.install_desktop_outlined
                                            : Icons.archive_outlined,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              asset.name,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_appReleaseAssetKindLabel(context, asset.kind)} · ${_formatAppReleaseAssetSize(asset.size).isEmpty ? l10n.unknownSize : _formatAppReleaseAssetSize(asset.size)}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton.tonalIcon(
                                        onPressed: _activeDownloadUrl == null
                                            ? () => _downloadAsset(asset)
                                            : null,
                                        icon:
                                            _activeDownloadUrl ==
                                                asset.downloadUrl
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                asset.startsInstaller
                                                    ? Icons
                                                          .download_for_offline_outlined
                                                    : Icons.download_outlined,
                                              ),
                                        label: Text(
                                          _activeDownloadUrl ==
                                                  asset.downloadUrl
                                              ? l10n.searching
                                              : asset.startsInstaller
                                              ? l10n.buttonDownloadAndInstall
                                              : l10n.buttonDownload,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_activeDownloadUrl ==
                                      asset.downloadUrl) ...<Widget>[
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                      value: _downloadProgress?.progress,
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _buildDownloadProgressLabel(
                                        context,
                                        _downloadProgress,
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.controller.autoCheckAppUpdates &&
            !_autoCheckDisabledInDialog)
          TextButton(
            onPressed: _isDisablingAutoCheck ? null : _disableAutoCheck,
            child: Text(
              _isDisablingAutoCheck
                  ? l10n.processing
                  : l10n.disableAutoCheckButton,
            ),
          ),
        TextButton(
          onPressed: widget.info.releasePageUrl.trim().isEmpty
              ? null
              : () => _openExternalLink(context, widget.info.releasePageUrl),
          child: Text(l10n.buttonOpenReleasePage),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.buttonClose),
        ),
      ],
    );
  }
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
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: borderRadius,
                      ),
                      foregroundDecoration: BoxDecoration(
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
        isSearching ? context.l10n.searching : context.l10n.installPageEmptyHint,
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
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
                Expanded(flex: 5, child: Text(l10n.packageNameColumn, style: style)),
                Expanded(flex: 2, child: Text(l10n.versionColumn, style: style)),
                Expanded(flex: 3, child: Text(l10n.sourceColumn, style: style)),
                Expanded(flex: 5, child: Text(l10n.extraInfoColumn, style: style)),
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
          (option) => Opacity(
            opacity: option.isInstalled ? 1 : 0.82,
            child: Tooltip(
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
  'bun': 'assets/package_icons/bun.svg',
  'cargo': 'assets/package_icons/cargo.png',
  'choco': 'assets/package_icons/chocolatey.svg',
  'npm': 'assets/package_icons/npm.svg',
  'pip': 'assets/package_icons/python.svg',
  'pnpm': 'assets/package_icons/pnpm.svg',
  'uv': 'assets/package_icons/uv.svg',
  'winget': 'assets/package_icons/winget.ico',
  'yarn': 'assets/package_icons/yarn.png',
};
