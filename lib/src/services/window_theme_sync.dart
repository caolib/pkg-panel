import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class WindowThemeSync {
  const WindowThemeSync();

  Future<void> sync(ThemeMode themeMode);
}

class PlatformWindowThemeSync implements WindowThemeSync {
  const PlatformWindowThemeSync();

  static const MethodChannel _channel = MethodChannel('pkg_panel/window_theme');

  @override
  Future<void> sync(ThemeMode themeMode) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setWindowThemeMode', <String, String>{
        'themeMode': themeMode.name,
      });
    } on MissingPluginException {
      // Ignore in tests and non-Windows runtimes.
    } on PlatformException {
      // Ignore native sync failures; the Flutter theme still applies.
    }
  }
}
