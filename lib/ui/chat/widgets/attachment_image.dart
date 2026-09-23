import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shows an image from wherever it happens to live.
///
/// `image_picker` hands back a filesystem path on Android and a blob URL on
/// the web, and `Image.file` cannot read the latter — hence the split. The
/// demo backend adds a third case: it has no server to download a profile
/// photo from, so its avatars are bundled and arrive as asset keys.
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
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, _, _) => _fallback(),
      );
    }
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
