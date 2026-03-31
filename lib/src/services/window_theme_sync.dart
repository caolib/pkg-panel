import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class WindowThemeSync {
  const WindowThemeSync();

  Future<void> sync({
    required ThemeMode themeMode,
    required Color lightBackgroundColor,
    required Color darkBackgroundColor,
    required Color lightForegroundColor,
    required Color darkForegroundColor,
  });
}

class PlatformWindowThemeSync implements WindowThemeSync {
  const PlatformWindowThemeSync();

  static const MethodChannel _channel = MethodChannel('pkg_panel/window_theme');

  @override
  Future<void> sync({
    required ThemeMode themeMode,
    required Color lightBackgroundColor,
    required Color darkBackgroundColor,
    required Color lightForegroundColor,
    required Color darkForegroundColor,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setWindowThemeMode', <String, Object>{
        'themeMode': themeMode.name,
        'lightBackgroundColor': lightBackgroundColor.toARGB32(),
        'darkBackgroundColor': darkBackgroundColor.toARGB32(),
        'lightForegroundColor': lightForegroundColor.toARGB32(),
        'darkForegroundColor': darkForegroundColor.toARGB32(),
      });
    } on MissingPluginException {
      // Ignore in tests and non-Windows runtimes.
    } on PlatformException {
      // Ignore native sync failures; the Flutter theme still applies.
    }
  }
}
