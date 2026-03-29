import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LocalIconImage extends StatelessWidget {
  const LocalIconImage({
    super.key,
    required this.filePath,
    required this.size,
    required this.fallback,
  });

  final String filePath;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final lowerFilePath = filePath.toLowerCase();
    if (!_isSupportedImageFile(lowerFilePath)) {
      return SizedBox.square(dimension: size, child: fallback);
    }

    return SizedBox.square(
      dimension: size,
      child: lowerFilePath.endsWith('.svg')
          ? SvgPicture.file(
              File(filePath),
              fit: BoxFit.contain,
              placeholderBuilder: (_) => fallback,
            )
          : Image.file(
              File(filePath),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }

  bool _isSupportedImageFile(String filePath) {
    return filePath.endsWith('.svg') ||
        filePath.endsWith('.ico') ||
        filePath.endsWith('.png') ||
        filePath.endsWith('.jpg') ||
        filePath.endsWith('.jpeg') ||
        filePath.endsWith('.webp') ||
        filePath.endsWith('.bmp') ||
        filePath.endsWith('.gif');
  }
}
