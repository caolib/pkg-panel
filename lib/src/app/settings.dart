part of '../app.dart';

class PackageSettingsPage extends StatelessWidget {
  const PackageSettingsPage({
    super.key,
    required this.controller,
    required this.settingsTabController,
    this.filePicker = const LocalFilePicker(),
  });

  final PackagePanelController controller;
  final TabController settingsTabController;
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
    final currentLanguageLabel = controller.locale.languageCode == 'en'
        ? l10n.languageEnglish
        : l10n.languageChinese;
    final currentThemeLabel = switch (controller.themeMode) {
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
      ThemeMode.system => l10n.themeModeSystem,
    };
    return _SettingsContentViewport(
      maxWidth: 1040,
      builder: (context, contentWidth) {
        final useTwoColumns = contentWidth >= 860;
        const gap = 20.0;
        final cardWidth = useTwoColumns
            ? (contentWidth - gap) / 2
            : contentWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            SizedBox(
              width: cardWidth,
              child: _SettingsChoiceCard(
                icon: Icons.translate_outlined,
                title: l10n.languageTitle,
                detail: currentLanguageLabel,
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Locale>(
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
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SettingsChoiceCard(
                icon: Icons.tune_outlined,
                title: l10n.themeModeTitle,
                detail: currentThemeLabel,
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
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
                ),
              ),
            ),
            SizedBox(
              width: contentWidth,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.crop_square_outlined,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  l10n.rememberWindowPlacementTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.rememberWindowPlacementSubtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Switch.adaptive(
                            value: controller.rememberWindowPlacement,
                            onChanged: (value) {
                              unawaited(
                                controller.setRememberWindowPlacement(value),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCustomThemeSeedColor(BuildContext context) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (dialogContext) =>
          _ThemeSeedColorDialog(initialColor: controller.customThemeSeedColor),
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

    return _SettingsContentViewport(
      maxWidth: 1080,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: paletteIds
                          .map(
                            (paletteId) => _ThemePaletteOptionCard(
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
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(width: 16),
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
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(l10n.fontPreview),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller,
        settingsTabController,
      ]),
      builder: (context, _) {
        final currentTabIndex = settingsTabController.index;
        final homeFilterGroups = controller.homeFilterGroups;
        final states = controller.managerVisibilityStates;
        return switch (currentTabIndex) {
          0 => _buildGeneralTab(context, theme),
          1 => ListView(
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
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerLowest,
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
                                              child:
                                                  ReorderableDragStartListener(
                                                    index: index,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
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
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          group.kind ==
                                                                  HomeFilterGroupKind
                                                                      .custom
                                                              ? l10n.customGroupType
                                                              : l10n.builtinGroupType,
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
                                                alignment:
                                                    Alignment.centerRight,
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
                                                      label: Text(
                                                        l10n.buttonEdit,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Switch(
                                                      value: group.isVisible,
                                                      onChanged: (value) =>
                                                          controller
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
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerLowest,
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
                                    controller.reorderManager(
                                      oldIndex,
                                      newIndex,
                                    );
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
                                              child:
                                                  ReorderableDragStartListener(
                                                    index: index,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
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
                                                                state
                                                                    .manager
                                                                    .id,
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
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
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
                                                            overflow:
                                                                TextOverflow
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
                                                          color:
                                                              state.isAvailable
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
                                                alignment:
                                                    Alignment.centerRight,
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
                                                      label: Text(
                                                        l10n.buttonEdit,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Switch(
                                                      value: state.isVisible,
                                                      onChanged: (value) =>
                                                          controller
                                                              .setManagerVisibility(
                                                                state
                                                                    .manager
                                                                    .id,
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
          2 => _buildAppearanceTab(context, theme),
          _ => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: _AboutAppCard(
                          theme: theme,
                          controller: controller,
                        ),
                      ),
        };
      },
    );
  }
}

class _SettingsContentViewport extends StatelessWidget {
  const _SettingsContentViewport({
    required this.builder,
    this.maxWidth = 1080,
  });

  final double maxWidth;
  final Widget Function(BuildContext context, double contentWidth) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 1280 ? 32.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: LayoutBuilder(
                builder: (context, innerConstraints) {
                  return builder(context, innerConstraints.maxWidth);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsChoiceCard extends StatelessWidget {
  const _SettingsChoiceCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
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
                            width: previewColor.toARGB32() == color.toARGB32()
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
              child: Image.asset(
                'assets/branding/logo.png',
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

class _AboutMetaRow extends StatefulWidget {
  const _AboutMetaRow({required this.controller});

  final PackagePanelController controller;

  @override
  State<_AboutMetaRow> createState() => _AboutMetaRowState();
}

class _AboutMetaRowState extends State<_AboutMetaRow> {
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        final packageInfo = snapshot.data;
        final versionLabel = packageInfo == null
            ? context.l10n.versionLoading
            : packageInfo.buildNumber.trim().isEmpty
            ? packageInfo.version
            : '${packageInfo.version}+${packageInfo.buildNumber}';
        final theme = Theme.of(context);
        return AnimatedBuilder(
          animation: widget.controller,
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
                    onPressed: widget.controller.isCheckingAppUpdate
                        ? null
                        : () {
                            unawaited(
                              _checkForAppUpdateWithUi(
                                context,
                                widget.controller,
                              ),
                            );
                          },
                    icon: widget.controller.isCheckingAppUpdate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                    label: Text(
                      widget.controller.isCheckingAppUpdate
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

String _appReleaseAssetKindLabel(
  BuildContext context,
  AppReleaseAssetKind kind,
) {
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
              assets.isEmpty
                  ? l10n.releaseAssetsEmpty
                  : l10n.releaseAssetsTitle,
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
