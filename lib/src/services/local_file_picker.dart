import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

class LocalFilePicker {
  const LocalFilePicker();

  Future<String?> pickManagerIconFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_managerIconTypeGroup],
      );
      return file?.path;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static const XTypeGroup _managerIconTypeGroup = XTypeGroup(
    label: 'manager icons',
    extensions: <String>['svg', 'png', 'jpg', 'jpeg', 'webp', 'ico'],
  );
}
