import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';

import '../../../data/diagnostics.dart';

/// Plays a Telegram `.tgs` sticker.
///
/// A TGS file is a Lottie animation gzipped, nothing more — so it is
/// decompressed once and handed to Lottie. Decoding happens off the build:
/// the file is read and inflated in a [Future], and the emoji stands in until
/// it lands.
class AnimatedSticker extends StatefulWidget {
  const AnimatedSticker({
    super.key,
    required this.path,
    required this.size,
    required this.fallbackEmoji,
  });

  final String path;
  final double size;

  /// Shown while decoding, and kept if the file turns out not to be readable.
  final String fallbackEmoji;

  @override
  State<AnimatedSticker> createState() => _AnimatedStickerState();
}

class _AnimatedStickerState extends State<AnimatedSticker> {
  late Future<Uint8List?> _bytes = _load();

  @override
  void didUpdateWidget(AnimatedSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _bytes = _load();
  }

  Future<Uint8List?> _load() async {
    try {
      final raw = await File(widget.path).readAsBytes();
      // Telegram also serves plain Lottie JSON under the same extension in
      // some builds; the gzip magic number says which this is.
      if (raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b) {
        return Uint8List.fromList(gzip.decode(raw));
      }
      return raw;
    } on Object catch (error) {
      TgDiagnostics.instance.warn('Could not read sticker: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return Center(
              child: Text(
                widget.fallbackEmoji.isEmpty ? '🎨' : widget.fallbackEmoji,
                style: TextStyle(fontSize: widget.size * 0.72),
              ),
            );
          }
          return Lottie.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            // Telegram stickers loop; so does this.
            repeat: true,
            errorBuilder: (context, error, stack) => Center(
              child: Text(
                widget.fallbackEmoji.isEmpty ? '🎨' : widget.fallbackEmoji,
                style: TextStyle(fontSize: widget.size * 0.72),
              ),
            ),
          );
        },
      ),
    );
  }
}
