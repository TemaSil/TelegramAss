import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/custom_emoji.dart';
import '../../../data/models.dart';
import 'animated_sticker.dart';
import 'attachment_image.dart';
import 'video_sticker.dart';

/// Renders message text with the formatting TDLib reports.
///
/// Until this existed every message was drawn as plain text, so bold, links,
/// code and spoilers all looked identical to ordinary words.
class MessageText extends StatefulWidget {
  const MessageText({
    super.key,
    required this.text,
    required this.entities,
    required this.style,
    required this.linkColor,
  });

  final String text;
  final List<TgTextEntity> entities;
  final TextStyle style;
  final Color linkColor;

  @override
  State<MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<MessageText> {
  /// Spoilers stay hidden until tapped, one range at a time.
  final _revealed = <int>{};

  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // Custom emoji arrive after the message does, so the text rebuilds when
    // the registry gets one. With no custom emoji in this message the listener
    // costs a rebuild that changes nothing, so it is skipped.
    final hasCustomEmoji = widget.entities.any(
      (entity) => entity.kind == TgEntityKind.customEmoji,
    );
    if (!hasCustomEmoji) {
      return Text.rich(
        TextSpan(children: _buildSpans(context)),
        style: widget.style,
      );
    }

    return ListenableBuilder(
      listenable: TgCustomEmoji.instance,
      builder: (context, _) => Text.rich(
        TextSpan(children: _buildSpans(context)),
        style: widget.style,
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context) {
    final text = widget.text;
    if (widget.entities.isEmpty) return [TextSpan(text: text)];

    // Entities can overlap and arrive unsorted; walking the boundaries keeps
    // every character in exactly one span.
    final sorted = [...widget.entities]
      ..sort((a, b) => a.offset.compareTo(b.offset));

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final entity in sorted) {
      final end = entity.end.clamp(0, text.length);
      if (end <= cursor) continue;

      // Overlapping ranges are common — a bold link, say. The earlier entity
      // keeps the shared characters so nothing is emitted twice.
      final start = math.max(entity.offset.clamp(0, text.length), cursor);
      if (start >= end) continue;

      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      spans.add(_spanFor(context, entity, text.substring(start, end)));
      cursor = end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  InlineSpan _spanFor(BuildContext context, TgTextEntity entity, String slice) {
    switch (entity.kind) {
      case TgEntityKind.bold:
        return TextSpan(
          text: slice,
          style: const TextStyle(fontWeight: FontWeight.w700),
        );

      case TgEntityKind.italic:
        return TextSpan(
          text: slice,
          style: const TextStyle(fontStyle: FontStyle.italic),
        );

      case TgEntityKind.underline:
        return TextSpan(
          text: slice,
          style: const TextStyle(decoration: TextDecoration.underline),
        );

      case TgEntityKind.strikethrough:
        return TextSpan(
          text: slice,
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        );

      case TgEntityKind.code:
      case TgEntityKind.pre:
        return TextSpan(
          text: slice,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: widget.style.fontSize == null
                ? null
                : widget.style.fontSize! - 1,
            backgroundColor: CupertinoColors.systemFill.resolveFrom(context),
          ),
        );

      case TgEntityKind.spoiler:
        final hidden = !_revealed.contains(entity.offset);
        final recognizer = TapGestureRecognizer()
          ..onTap = () => setState(() => _revealed.add(entity.offset));
        _recognizers.add(recognizer);
        return TextSpan(
          text: slice,
          recognizer: hidden ? recognizer : null,
          style: hidden
              ? TextStyle(
                  color: const Color(0x00000000),
                  backgroundColor: CupertinoColors.systemGrey
                      .resolveFrom(context)
                      .withValues(alpha: 0.55),
                )
              : null,
        );

      case TgEntityKind.link:
        final target = entity.url ?? slice;
        final recognizer = TapGestureRecognizer()..onTap = () => _open(target);
        _recognizers.add(recognizer);
        return TextSpan(
          text: slice,
          recognizer: recognizer,
          style: TextStyle(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
        );

      case TgEntityKind.mention:
      case TgEntityKind.hashtag:
        return TextSpan(
          text: slice,
          style: TextStyle(color: widget.linkColor),
        );

      case TgEntityKind.customEmoji:
        final id = entity.customEmojiId;
        final path = id == null ? null : TgCustomEmoji.instance.pathFor(id);
        // The covered characters are the emoji Telegram itself falls back to,
        // so they stand in until the sticker is on disk.
        if (path == null) return TextSpan(text: slice);

        final size = (widget.style.fontSize ?? 16) * 1.35;
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          // TDLib names the file after its encoding, which is what says how it
          // has to be drawn: Lottie, video, or a still image.
          child: switch (path.split('.').last) {
            'tgs' => AnimatedSticker(
              path: path,
              size: size,
              fallbackEmoji: slice,
            ),
            'webm' => VideoSticker(
              path: path,
              size: size,
              fallbackEmoji: slice,
            ),
            _ => AttachmentImage(
              path: path,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          },
        );
    }
  }
}
