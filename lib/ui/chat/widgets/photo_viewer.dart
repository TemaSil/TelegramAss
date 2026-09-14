import 'package:flutter/cupertino.dart';

import '../../../core/tg_icons.dart';
import 'attachment_image.dart';

/// Full-screen photo, the way Messages shows one: black, pinch to zoom, drag
/// down to dismiss.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.path, this.heroTag});

  final String path;
  final Object? heroTag;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final _controller = TransformationController();

  double _dragOffset = 0;

  bool get _isZoomed => _controller.value.getMaxScaleOnAxis() > 1.02;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fades the backdrop as the photo is dragged away, so the gesture reads as
    // "putting it back" rather than as a scroll.
    final progress = (_dragOffset.abs() / 320).clamp(0.0, 1.0);

    Widget image = AttachmentImage(path: widget.path, fit: BoxFit.contain);
    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black.withValues(alpha: 1 - progress),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              onVerticalDragUpdate: _isZoomed
                  ? null
                  : (details) =>
                        setState(() => _dragOffset += details.delta.dy),
              onVerticalDragEnd: _isZoomed
                  ? null
                  : (details) {
                      if (_dragOffset.abs() > 120 ||
                          (details.primaryVelocity ?? 0).abs() > 700) {
                        Navigator.of(context).maybePop();
                      } else {
                        setState(() => _dragOffset = 0);
                      }
                    },
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 5,
                  onInteractionEnd: (_) => setState(() {}),
                  child: Center(child: image),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: CupertinoButton(
                onPressed: () => Navigator.of(context).maybePop(),
                padding: const EdgeInsets.all(14),
                child: const Icon(
                  TgIcons.close,
                  color: CupertinoColors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
