import 'package:flutter/widgets.dart';

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
    return SizedBox.square(dimension: size, child: fallback);
  }
}
