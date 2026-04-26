import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

part 'app/home_and_actions.dart';
part 'app/settings.dart';
part 'app/install.dart';

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

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator({this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(size * 0.32),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.14),
            child: FittedBox(
              child: Icon(
                Icons.hourglass_top_rounded,
                size: size * 0.58,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isQueuedStatus(String? statusLabel) {
  final normalized = statusLabel?.trim();
  return normalized == '排队中' || normalized == 'Queued';
}

String _localizedCommandStatus(
  BuildContext context,
  RunningCommandInfo command,
) {
  final l10n = context.l10n;
  if (command.isCancelling) {
    return l10n.commandCancelling;
  }
  if (_isQueuedStatus(command.statusLabel)) {
    return l10n.commandStatusQueued;
  }
  return command.statusLabel ?? '';
}

String _homeFilterGroupDisplayName(
  BuildContext context,
  HomeFilterGroup group,
) {
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
  late _AppViewConfig _appViewConfig;
  _WindowThemeSyncConfig? _lastSyncedWindowThemeConfig;
  _WindowThemeSyncConfig? _pendingWindowThemeConfig;
  bool _windowThemeSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _appViewConfig = _AppViewConfig.fromController(widget.controller);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant PkgPanelApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _appViewConfig = _AppViewConfig.fromController(widget.controller);
    }
    if (oldWidget.windowThemeSync != widget.windowThemeSync) {
      _lastSyncedWindowThemeConfig = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final nextConfig = _AppViewConfig.fromController(widget.controller);
    if (nextConfig == _appViewConfig) {
      return;
    }
    setState(() {
      _appViewConfig = nextConfig;
    });
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
      if (configToSync == null ||
          configToSync == _lastSyncedWindowThemeConfig) {
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
    final themeMode = _appViewConfig.themeMode;
    final lightTheme = _buildTheme(
      brightness: Brightness.light,
      seedColor: _appViewConfig.activeThemeSeedColor,
      customFontFamily: _appViewConfig.customFontFamily,
      customFallbackFontFamilies: _appViewConfig.customFallbackFontFamilies,
    );
    final darkTheme = _buildTheme(
      brightness: Brightness.dark,
      seedColor: _appViewConfig.activeThemeSeedColor,
      customFontFamily: _appViewConfig.customFontFamily,
      customFallbackFontFamilies: _appViewConfig.customFallbackFontFamilies,
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
      locale: _appViewConfig.locale,
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
        other.darkForegroundColor.toARGB32() == darkForegroundColor.toARGB32();
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

class _AppViewConfig {
  const _AppViewConfig({
    required this.locale,
    required this.themeMode,
    required this.activeThemeSeedColor,
    required this.customFontFamily,
    required this.customFallbackFontFamilies,
  });

  factory _AppViewConfig.fromController(PackagePanelController controller) {
    return _AppViewConfig(
      locale: controller.locale,
      themeMode: controller.themeMode,
      activeThemeSeedColor: controller.activeThemeSeedColor,
      customFontFamily: controller.customFontFamily,
      customFallbackFontFamilies: controller.customFallbackFontFamilies,
    );
  }

  final Locale locale;
  final ThemeMode themeMode;
  final Color activeThemeSeedColor;
  final String? customFontFamily;
  final List<String> customFallbackFontFamilies;

  @override
  bool operator ==(Object other) {
    return other is _AppViewConfig &&
        other.locale == locale &&
        other.themeMode == themeMode &&
        other.activeThemeSeedColor.toARGB32() ==
            activeThemeSeedColor.toARGB32() &&
        other.customFontFamily == customFontFamily &&
        listEquals(
          other.customFallbackFontFamilies,
          customFallbackFontFamilies,
        );
  }

  @override
  int get hashCode => Object.hash(
    locale,
    themeMode,
    activeThemeSeedColor.toARGB32(),
    customFontFamily,
    Object.hashAll(customFallbackFontFamilies),
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
