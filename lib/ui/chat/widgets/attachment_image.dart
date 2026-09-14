import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shows a picked attachment from wherever the picker put it.
///
/// `image_picker` hands back a filesystem path on Android and a blob URL on
/// the web, and `Image.file` cannot read the latter — hence the split.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, _, _) => _fallback(),
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, _, _) => _fallback(),
    );
  }

  Widget _fallback() => SizedBox(width: width, height: height);
}
