import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

import '../../../data/diagnostics.dart';
import 'attachment_image.dart';

/// Plays a Telegram `.webm` sticker: VP9, muted, looping, no controls.
///
/// Video stickers are the one format the app used to skip. They are ordinary
/// video files, so the player the chat already uses can draw them — with two
/// things a video message does not have to care about.
///
/// The first is the poster. A sticker is the whole message, so an empty frame
/// while the decoder opens is very visible; [posterPath] is the thumbnail
/// TDLib ships with the sticker and it holds the space until the first frame
/// is ready, with the emoji standing in if there is no thumbnail either.
///
/// The second is how many of these can exist at once. Every player is a
/// hardware decoder, devices have few, and a lively chat can put a dozen
/// stickers and custom emoji on screen together. [_DecoderBudget] hands out a
/// fixed number of slots; a sticker that cannot get one keeps showing its
/// poster instead of failing to open, and takes a slot when one frees up.
class VideoSticker extends StatefulWidget {
  const VideoSticker({
    super.key,
    required this.path,
    required this.size,
    required this.fallbackEmoji,
    this.posterPath,
  });

  final String path;
  final double size;

  /// Shown until the first frame, and kept if the video will not open.
  final String fallbackEmoji;

  /// Still frame for the sticker, if TDLib sent one.
  final String? posterPath;

  @override
  State<VideoSticker> createState() => _VideoStickerState();
}

class _VideoStickerState extends State<VideoSticker> {
  VideoPlayerController? _controller;
  bool _holdsSlot = false;

  /// Held as a field so the budget can drop it again by identity.
  late final VoidCallback _wake = _onSlotFreed;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(VideoSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _close();
      _open();
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  Future<void> _open() async {
    if (!_DecoderBudget.instance.take(_wake)) return;
    _holdsSlot = true;

    final controller = VideoPlayerController.file(File(widget.path));
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
    } on Object catch (error) {
      TgDiagnostics.instance.warn('Video sticker failed to open: $error');
      await controller.dispose();
      _release();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      _release();
      return;
    }
    setState(() => _controller = controller);
  }

  void _close() {
    _controller?.dispose();
    _controller = null;
    _release();
  }

  void _release() {
    if (!_holdsSlot) {
      // Never got one — stop waiting for it.
      _DecoderBudget.instance.cancel(_wake);
      return;
    }
    _holdsSlot = false;
    _DecoderBudget.instance.give();
  }

  /// A slot came free while this sticker was showing its poster.
  void _onSlotFreed() {
    if (!mounted || _controller != null || _holdsSlot) return;
    _open();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: controller == null
          ? _poster()
          : FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
    );
  }

  Widget _poster() {
    final poster = widget.posterPath;
    if (poster != null) {
      return AttachmentImage(
        path: poster,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    }
    return Center(
      child: Text(
        widget.fallbackEmoji.isEmpty ? '🎨' : widget.fallbackEmoji,
        style: TextStyle(fontSize: widget.size * 0.72),
      ),
    );
  }
}

/// How many video stickers may hold a decoder at the same time.
///
/// Android guarantees far fewer concurrent decoders than a chat can show
/// stickers, and asking for one too many fails the whole player rather than
/// queueing. Waiters are woken oldest first as slots come back.
class _DecoderBudget {
  _DecoderBudget._();

  static final instance = _DecoderBudget._();

  static const _limit = 6;

  int _inUse = 0;
  final _waiting = <VoidCallback>[];

  bool take(VoidCallback onFreed) {
    if (_inUse >= _limit) {
      if (!_waiting.contains(onFreed)) _waiting.add(onFreed);
      return false;
    }
    _inUse++;
    return true;
  }

  void cancel(VoidCallback onFreed) => _waiting.remove(onFreed);

  void give() {
    _inUse--;
    // A woken sticker that has since left the tree does not take the slot, so
    // keep going until one does or nobody is left waiting.
    while (_inUse < _limit && _waiting.isNotEmpty) {
      _waiting.removeAt(0)();
    }
  }
}
