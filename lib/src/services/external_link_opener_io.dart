import 'dart:io';

Future<bool> openExternalLinkWithSystem(String url) async {
  try {
    if (Platform.isWindows) {
      await Process.start('cmd', <String>['/c', 'start', '', url]);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.start('open', <String>[url]);
      return true;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', <String>[url]);
      return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}
