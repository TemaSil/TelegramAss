import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

import '../../../core/formatters.dart';
import '../../../core/tg_icons.dart';
import '../../../data/diagnostics.dart';

/// Full-screen video playback, presented the way the photo viewer is: black
/// ground, the frame centred, and chrome that gets out of the way.
class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({super.key, required this.path, this.heroTag});

  final String path;
  final Object? heroTag;

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.file(File(widget.path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } on Object catch (error) {
      TgDiagnostics.instance.error('Video failed to open: $error');
      await controller.dispose();
      if (mounted) setState(() => _error = '$error');
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          Center(
            child: _error != null
                ? const Icon(
                    TgIcons.failed,
                    size: 40,
                    color: CupertinoColors.systemGrey,
                  )
                : controller == null
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : GestureDetector(
                    onTap: _togglePlay,
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
          ),
          if (controller != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: _Controls(controller: controller, onToggle: _togglePlay),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: CupertinoButton(
              padding: const EdgeInsets.all(8),
              minimumSize: Size.zero,
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Icon(
                TgIcons.close,
                size: 22,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Play/pause and a scrubber, rebuilt from the controller's own value.
class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.onToggle});

  final VideoPlayerController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final total = value.duration.inMilliseconds;
        final progress = total <= 0
            ? 0.0
            : (value.position.inMilliseconds / total).clamp(0.0, 1.0);

        return Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              onPressed: onToggle,
              child: Icon(
                value.isPlaying ? TgIcons.pause : TgIcons.play,
                size: 24,
                color: CupertinoColors.white,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => controller.seekTo(
                    value.duration *
                        (details.localPosition.dx / constraints.maxWidth).clamp(
                          0.0,
                          1.0,
                        ),
                  ),
                  child: SizedBox(
                    height: 20,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 3,
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: ColoredBox(color: Color(0x59FFFFFF)),
                              ),
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: const ColoredBox(
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${TgFormat.duration(value.position)} / '
              '${TgFormat.duration(value.duration)}',
              style: const TextStyle(
                fontSize: 12.5,
                color: CupertinoColors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }
}
