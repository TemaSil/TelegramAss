import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/formatters.dart';
import '../../../core/glass_tokens.dart';
import '../../../core/tg_theme.dart';
import '../../../data/models.dart';
import '../../chats/widgets/chat_row.dart' show MessageStatusTicks;
import '../../../core/tg_icons.dart';

/// A single message.
///
/// The bubble itself is the glass: outgoing bubbles tint the material with the
/// accent, incoming ones stay neutral and let the wallpaper supply the colour.
/// Long press opens a context menu whose first row is a reaction picker.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.fontSize,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onForward,
    required this.onReact,
    this.showTail = true,
    this.showSender = false,
  });

  final TgMessage message;
  final double fontSize;
  final ValueChanged<TgMessage> onReply;
  final ValueChanged<TgMessage> onEdit;
  final ValueChanged<TgMessage> onDelete;
  final ValueChanged<TgMessage> onForward;
  final void Function(TgMessage message, String emoji) onReact;

  /// Last message of a group gets the wider corner.
  final bool showTail;

  /// Group chats label the author above the first bubble of a run.
  final bool showSender;

  static const _quickReactions = ['👍', '❤️', '🔥', '😂', '😮', '😢'];

  @override
  Widget build(BuildContext context) {
    final outgoing = message.isOutgoing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        outgoing ? 56 : 12,
        1.5,
        outgoing ? 12 : 56,
        1.5,
      ),
      child: Align(
        alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: GlassMenu(
          menuWidth: 240,
          menuBorderRadius: 26,
          quality: GlassQuality.premium,
          settings: GlassTokens.menu(context),
          menuAlignment: outgoing
              ? GlassMenuAlignment.bottomRight
              : GlassMenuAlignment.bottomLeft,
          triggerBuilder: (context, toggleMenu) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () {
              HapticFeedback.mediumImpact();
              toggleMenu();
            },
            onDoubleTap: () {
              HapticFeedback.lightImpact();
              onReact(message, '❤️');
            },
            child: _bubble(context),
          ),
          items: [
            GlassMenuLabel(
              height: 52,
              child: _ReactionPicker(
                chosen: {
                  for (final reaction in message.reactions)
                    if (reaction.chosen) reaction.emoji,
                },
                onPick: (emoji) => onReact(message, emoji),
              ),
            ),
            GlassMenuItem(
              title: 'Reply',
              icon: const Icon(TgIcons.reply),
              onTap: () => onReply(message),
            ),
            GlassMenuItem(
              title: 'Copy',
              icon: const Icon(TgIcons.copy),
              onTap: () => Clipboard.setData(ClipboardData(text: message.text)),
            ),
            if (message.isOutgoing && message.kind == TgMessageKind.text)
              GlassMenuItem(
                title: 'Edit',
                icon: const Icon(TgIcons.edit),
                onTap: () => onEdit(message),
              ),
            GlassMenuItem(
              title: 'Forward',
              icon: const Icon(TgIcons.forwardMessage),
              onTap: () => onForward(message),
            ),
            const GlassMenuDivider(),
            GlassMenuItem(
              title: 'Delete',
              icon: const Icon(TgIcons.delete),
              isDestructive: true,
              onTap: () => onDelete(message),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context) {
    final outgoing = message.isOutgoing;
    // A grouped run keeps square-ish inner corners; the last bubble of the
    // run gets the full radius on every corner.
    final radius = GlassTokens.bubbleRadius;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: GlassContainer(
        padding: EdgeInsets.fromLTRB(
          12,
          message.kind == TgMessageKind.photo ? 4 : 8,
          12,
          7,
        ),
        shape: LiquidRoundedRectangle(borderRadius: showTail ? radius : 12),
        settings: outgoing
            ? GlassTokens.outgoingBubble(context)
            : GlassTokens.incomingBubble(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSender && !outgoing && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.senderName!,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: TgColors.avatarGradient(
                      message.senderId ?? message.senderName.hashCode,
                    ).last,
                  ),
                ),
              ),
            if (message.replyToText != null)
              _ReplyQuote(
                sender: message.replyToSender ?? 'Message',
                text: message.replyToText!,
                outgoing: outgoing,
              ),
            _content(context),
            if (message.reactions.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ReactionRow(
                reactions: message.reactions,
                onTap: (emoji) => onReact(message, emoji),
              ),
            ],
            const SizedBox(height: 3),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final textColor = message.isOutgoing
        ? CupertinoColors.white
        : TgColors.label.resolveFrom(context);

    switch (message.kind) {
      case TgMessageKind.photo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  _PhotoPlaceholder(seed: message.mediaSeed ?? message.id),
                  if (message.uploadProgress != null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: CupertinoColors.black.withValues(alpha: 0.35),
                        child: Center(
                          child: GlassProgressIndicator.circular(
                            value: message.uploadProgress,
                            size: 44,
                            strokeWidth: 3,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (message.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message.text,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.3,
                  color: textColor,
                ),
              ),
            ],
          ],
        );

      case TgMessageKind.voice:
        return _VoiceContent(
          seconds: message.voiceSeconds ?? 12,
          tint: textColor,
        );

      case TgMessageKind.file:
        return _FileContent(
          name: message.fileName ?? 'Document',
          size: message.fileSize ?? '',
          progress: message.uploadProgress,
          tint: textColor,
        );

      case TgMessageKind.sticker:
      case TgMessageKind.service:
      case TgMessageKind.text:
        return Text(
          message.text,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.32,
            letterSpacing: -0.2,
            color: textColor,
          ),
        );
    }
  }

  Widget _footer(BuildContext context) {
    final tint = message.isOutgoing
        ? CupertinoColors.white.withValues(alpha: 0.78)
        : TgColors.tertiaryLabel.resolveFrom(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text('edited', style: TextStyle(fontSize: 11, color: tint)),
          ),
        Text(
          TgFormat.time(message.date),
          style: TextStyle(fontSize: 11.5, color: tint),
        ),
        if (message.isOutgoing) ...[
          const SizedBox(width: 4),
          MessageStatusTicks(
            status: message.status,
            color: message.status == TgMessageStatus.read
                ? CupertinoColors.white
                : tint,
          ),
        ],
      ],
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.sender,
    required this.text,
    required this.outgoing,
  });

  final String sender;
  final String text;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final tint = outgoing
        ? CupertinoColors.white
        : TgColors.accent.resolveFrom(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: tint, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sender,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: outgoing
                  ? CupertinoColors.white.withValues(alpha: 0.8)
                  : TgColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Existing reactions under the text, each a tappable glass chip.
class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.reactions, required this.onTap});

  final List<TgReaction> reactions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final reaction in reactions)
          GlassChip(
            label: '${reaction.emoji} ${reaction.count}',
            selected: reaction.chosen,
            onTap: () => onTap(reaction.emoji),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            settings: GlassTokens.chrome(context),
            labelStyle: TextStyle(
              fontSize: 13,
              color: reaction.chosen
                  ? TgColors.accent.resolveFrom(context)
                  : TgColors.label.resolveFrom(context),
            ),
          ),
      ],
    );
  }
}

/// The emoji row at the top of the long-press menu.
class _ReactionPicker extends StatelessWidget {
  const _ReactionPicker({required this.chosen, required this.onPick});

  final Set<String> chosen;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final emoji in MessageBubble._quickReactions)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onPick(emoji);
            },
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chosen.contains(emoji)
                    ? TgColors.accent
                          .resolveFrom(context)
                          .withValues(alpha: 0.25)
                    : null,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 21)),
            ),
          ),
      ],
    );
  }
}

/// Deterministic gradient stand-in for an image attachment.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    final colors = TgColors.avatarGradient(seed);
    return Container(
      width: 220,
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          TgIcons.photo,
          size: 34,
          color: CupertinoColors.white.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

class _VoiceContent extends StatelessWidget {
  const _VoiceContent({required this.seconds, required this.tint});

  final int seconds;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(TgIcons.play, size: 22, color: tint),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          height: 26,
          child: CustomPaint(
            painter: _WaveformPainter(tint: tint, seed: seconds),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          TgFormat.duration(Duration(seconds: seconds)),
          style: TextStyle(fontSize: 12.5, color: tint),
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.tint, required this.seed});

  final Color tint;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()
      ..color = tint
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const step = 5.0;
    for (var x = 0.0; x < size.width; x += step) {
      final height = size.height * (0.25 + random.nextDouble() * 0.75);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.tint != tint || oldDelegate.seed != seed;
}

class _FileContent extends StatelessWidget {
  const _FileContent({
    required this.name,
    required this.size,
    required this.tint,
    this.progress,
  });

  final String name;
  final String size;
  final Color tint;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TgIcons.file, size: 30, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: tint,
                  ),
                ),
                const SizedBox(height: 3),
                if (progress != null)
                  GlassProgressIndicator.linear(
                    value: progress,
                    height: 4,
                    color: tint,
                  )
                else
                  Text(
                    size,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: tint.withValues(alpha: 0.75),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
