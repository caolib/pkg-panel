import 'package:flutter/material.dart';

const String defaultAppThemePaletteId = 'teal';
const String customAppThemePaletteId = 'custom';
const Color defaultCustomAppThemeSeedColor = Color(0xFF0F766E);

class AppThemePalette {
  const AppThemePalette({
    required this.id,
    required this.seedColor,
    required this.previewColors,
  });

  final String id;
  final Color seedColor;
  final List<Color> previewColors;
}

const List<AppThemePalette> appThemePalettes = <AppThemePalette>[
  AppThemePalette(
    id: defaultAppThemePaletteId,
    seedColor: Color(0xFF0F766E),
    previewColors: <Color>[
      Color(0xFF0F766E),
      Color(0xFF14B8A6),
      Color(0xFF99F6E4),
    ],
  ),
  AppThemePalette(
    id: 'ocean',
    seedColor: Color(0xFF0284C7),
    previewColors: <Color>[
      Color(0xFF0284C7),
      Color(0xFF38BDF8),
      Color(0xFFE0F2FE),
    ],
  ),
  AppThemePalette(
    id: 'sunset',
    seedColor: Color(0xFFEA580C),
    previewColors: <Color>[
      Color(0xFFEA580C),
      Color(0xFFFB923C),
      Color(0xFFFFEDD5),
    ],
  ),
  AppThemePalette(
    id: 'forest',
    seedColor: Color(0xFF15803D),
    previewColors: <Color>[
      Color(0xFF15803D),
      Color(0xFF4ADE80),
      Color(0xFFDCFCE7),
    ],
  ),
  AppThemePalette(
    id: 'berry',
    seedColor: Color(0xFFBE185D),
    previewColors: <Color>[
      Color(0xFFBE185D),
      Color(0xFFF472B6),
      Color(0xFFFCE7F3),
    ],
  ),
  AppThemePalette(
    id: 'slate',
    seedColor: Color(0xFF475569),
    previewColors: <Color>[
      Color(0xFF475569),
      Color(0xFF94A3B8),
      Color(0xFFF1F5F9),
    ],
  ),
];

AppThemePalette? appThemePaletteById(String id) {
  for (final palette in appThemePalettes) {
    if (palette.id == id) {
      return palette;
    }
  }
  return null;
}
