import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/formatters.dart';
import '../../../core/glass_tokens.dart';
import '../../../core/tg_theme.dart';
import '../../../app.dart';
import '../../../data/models.dart';
import '../../chats/widgets/chat_row.dart' show MessageStatusTicks;
import 'attachment_image.dart';
import 'bubble_shape.dart';
import 'message_text.dart';
import 'photo_viewer.dart';
import '../../../core/tg_icons.dart';
import '../../../data/audio_player.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppL10n.of(context);

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
          autoAdjustToScreen: true,
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
              title: l10n.reply,
              icon: const Icon(TgIcons.reply),
              onTap: () => onReply(message),
            ),
            GlassMenuItem(
              title: l10n.copy,
              icon: const Icon(TgIcons.copy),
              onTap: () => Clipboard.setData(ClipboardData(text: message.text)),
            ),
            if (message.isOutgoing && message.kind == TgMessageKind.text)
              GlassMenuItem(
                title: l10n.editMessage,
                icon: const Icon(TgIcons.edit),
                onTap: () => onEdit(message),
              ),
            GlassMenuItem(
              title: l10n.forward,
              icon: const Icon(TgIcons.forwardMessage),
              onTap: () => onForward(message),
            ),
            const GlassMenuDivider(),
            GlassMenuItem(
              title: l10n.delete,
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
    final l10n = AppL10n.of(context);
    final outgoing = message.isOutgoing;
    final fill = outgoing
        ? TgColors.outgoingBubble.resolveFrom(context)
        : TgColors.incomingBubble.resolveFrom(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          12,
          message.kind == TgMessageKind.photo ? 4 : 8,
          12,
          7,
        ),
        decoration: ShapeDecoration(
          color: fill,
          shape: BubbleShape(fromRight: outgoing, withTail: showTail),
        ),
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
                sender: message.replyToSender ?? l10n.message,
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
    final l10n = AppL10n.of(context);
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
                  if (message.localPath != null)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          fullscreenDialog: true,
                          builder: (_) => PhotoViewerScreen(
                            path: message.localPath!,
                            heroTag: 'photo-${message.id}',
                          ),
                        ),
                      ),
                      child: Hero(
                        tag: 'photo-${message.id}',
                        child: AttachmentImage(
                          path: message.localPath!,
                          width: 220,
                          height: 150,
                        ),
                      ),
                    )
                  else
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
              MessageText(
                text: message.text,
                entities: message.entities,
                linkColor: message.isOutgoing
                    ? CupertinoColors.white
                    : TgColors.accent.resolveFrom(context),
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.3,
                  color: textColor,
                ),
              ),
            ],
          ],
        );

      case TgMessageKind.video:
        return _VideoContent(
          path: message.localPath,
          seconds: message.voiceSeconds,
          tint: textColor,
          caption: message.text,
          fontSize: fontSize,
        );

      case TgMessageKind.audio:
        return _AudioContent(
          message: message,
          title: message.audioTitle?.isNotEmpty == true
              ? message.audioTitle!
              : (message.fileName ?? 'Audio'),
          performer: message.audioPerformer,
          size: message.fileSize,
          seconds: message.voiceSeconds,
          tint: textColor,
        );

      case TgMessageKind.voice:
        return _VoiceContent(message: message, tint: textColor);

      case TgMessageKind.file:
        return _FileContent(
          name: message.fileName ?? l10n.documents,
          size: message.fileSize ?? '',
          progress: message.uploadProgress,
          tint: textColor,
        );

      case TgMessageKind.sticker:
        if (message.localPath != null) {
          return AttachmentImage(
            path: message.localPath!,
            width: 140,
            height: 140,
            fit: BoxFit.contain,
          );
        }
        // Animated stickers are not decoded yet; show the emoji they stand for
        // rather than an empty bubble.
        return Text(
          message.text.isEmpty ? '🎨' : message.text,
          style: const TextStyle(fontSize: 54),
        );

      case TgMessageKind.service:
      case TgMessageKind.text:
        final text = MessageText(
          text: message.text,
          entities: message.entities,
          linkColor: message.isOutgoing
              ? CupertinoColors.white
              : TgColors.accent.resolveFrom(context),
          style: TextStyle(
            fontSize: fontSize,
            height: 1.32,
            letterSpacing: -0.2,
            color: textColor,
          ),
        );

        final preview = message.linkPreview;
        if (preview == null) return text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            text,
            const SizedBox(height: 6),
            _LinkPreviewCard(
              preview: preview,
              isOutgoing: message.isOutgoing,
              fontSize: fontSize,
            ),
          ],
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

/// A voice note, played in place. The waveform doubles as the scrubber: the
/// played part is solid, the rest is dimmed, and a tap anywhere seeks.
class _VoiceContent extends StatelessWidget {
  const _VoiceContent({required this.message, required this.tint});

  final TgMessage message;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final seconds = message.voiceSeconds ?? 0;
    final path = message.localPath;

    return ListenableBuilder(
      listenable: TgAudio.instance,
      builder: (context, _) {
        final audio = TgAudio.instance;
        final isCurrent = audio.currentMessageId == message.id;
        final playing = audio.isPlayingMessage(message.id);
        final progress = audio.progressFor(message.id);

        // Once it is playing, the elapsed time is more useful than the length.
        final label = isCurrent && audio.duration > Duration.zero
            ? TgFormat.duration(audio.position)
            : TgFormat.duration(Duration(seconds: seconds));

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: path == null ? null : () => audio.toggle(message.id, path),
              behavior: HitTestBehavior.opaque,
              child: path == null
                  // Still coming down from the server.
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CupertinoActivityIndicator(color: tint, radius: 9),
                    )
                  : Icon(
                      playing ? TgIcons.pause : TgIcons.play,
                      size: 22,
                      color: tint,
                    ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTapDown: (details) {
                if (!isCurrent) return;
                audio.seekFraction(message.id, details.localPosition.dx / 120);
              },
              child: SizedBox(
                width: 120,
                height: 26,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    tint: tint,
                    seed: seconds,
                    progress: isCurrent ? progress : 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 12.5, color: tint)),
          ],
        );
      },
    );
  }
}

/// A video is shown as its poster with a play badge; tapping opens the frame
/// full screen. Playing the video itself is not wired up yet.
class _VideoContent extends StatelessWidget {
  const _VideoContent({
    required this.path,
    required this.seconds,
    required this.tint,
    required this.caption,
    required this.fontSize,
  });

  final String? path;
  final int? seconds;
  final Color tint;
  final String caption;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (path != null)
                AttachmentImage(path: path!, width: 220, height: 150)
              else
                Container(
                  width: 220,
                  height: 150,
                  color: CupertinoColors.black.withValues(alpha: 0.35),
                ),
              const Icon(TgIcons.play, size: 34, color: CupertinoColors.white),
              if (seconds != null)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        TgFormat.duration(Duration(seconds: seconds!)),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(fontSize: fontSize, height: 1.3, color: tint),
          ),
        ],
      ],
    );
  }
}

/// Music: title, performer, and how long it runs.
/// A music track. Tapping the disc downloads it if it is not here yet, then
/// plays it; a hairline under the row tracks the position.
class _AudioContent extends StatelessWidget {
  const _AudioContent({
    required this.message,
    required this.title,
    required this.performer,
    required this.size,
    required this.seconds,
    required this.tint,
  });

  final TgMessage message;
  final String title;
  final String? performer;
  final String? size;
  final int? seconds;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TgAudio.instance,
      builder: (context, _) {
        final audio = TgAudio.instance;
        final path = message.localPath;
        final isCurrent = audio.currentMessageId == message.id;
        final playing = audio.isPlayingMessage(message.id);

        final elapsed = isCurrent && audio.duration > Duration.zero
            ? TgFormat.duration(audio.position)
            : (seconds != null
                  ? TgFormat.duration(Duration(seconds: seconds!))
                  : null);
        final subtitle = [
          if (performer != null && performer!.isNotEmpty) performer!,
          ?elapsed,
          if (size != null && size!.isNotEmpty) size!,
        ].join(' · ');

        return SizedBox(
          width: 230,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (path != null) {
                        audio.toggle(message.id, path);
                      } else {
                        AppScope.read(context).client
                            .downloadMessageMedia(message.chatId, message.id);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tint.withValues(alpha: 0.18),
                      ),
                      child: Icon(
                        path == null
                            ? TgIcons.download
                            : (playing ? TgIcons.pause : TgIcons.play),
                        size: 18,
                        color: tint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: tint,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
              if (isCurrent) ...[
                const SizedBox(height: 8),
                _TrackBar(
                  progress: audio.progressFor(message.id),
                  tint: tint,
                  onSeek: (fraction) =>
                      audio.seekFraction(message.id, fraction),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The hairline under a playing track. Tapping it seeks.
class _TrackBar extends StatelessWidget {
  const _TrackBar({
    required this.progress,
    required this.tint,
    required this.onSeek,
  });

  final double progress;
  final Color tint;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) =>
              onSeek(details.localPosition.dx / constraints.maxWidth),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 12,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: tint.withValues(alpha: 0.2)),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: ColoredBox(color: tint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.tint, required this.seed, this.progress = 0});

  final Color tint;
  final int seed;

  /// 0..1 through the note; bars before it are solid, bars after are dimmed.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final played = Paint()
      ..color = tint
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final remaining = Paint()
      ..color = tint.withValues(alpha: 0.35)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final head = size.width * progress;
    const step = 5.0;
    for (var x = 0.0; x < size.width; x += step) {
      final height = size.height * (0.25 + random.nextDouble() * 0.75);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        x <= head ? played : remaining,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.tint != tint ||
      oldDelegate.seed != seed ||
      oldDelegate.progress != progress;
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

/// The card Telegram draws under a link: an accent rule, the site, the title
/// and a couple of lines of description, with the thumbnail when there is one.
class _LinkPreviewCard extends StatelessWidget {
  const _LinkPreviewCard({
    required this.preview,
    required this.isOutgoing,
    required this.fontSize,
  });

  final TgLinkPreview preview;
  final bool isOutgoing;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // On an outgoing bubble the accent is the bubble itself, so the rule and
    // the site name go white rather than fighting the blue behind them.
    final accent = isOutgoing
        ? CupertinoColors.white
        : TgColors.accent.resolveFrom(context);
    final body = isOutgoing
        ? CupertinoColors.white.withValues(alpha: 0.92)
        : TgColors.label.resolveFrom(context);
    final secondary = isOutgoing
        ? CupertinoColors.white.withValues(alpha: 0.75)
        : TgColors.secondaryLabel.resolveFrom(context);

    final title = preview.title;
    final description = preview.description;
    final siteName = preview.siteName;
    final imagePath = preview.imagePath;

    return GestureDetector(
      onTap: () {
        final uri = Uri.tryParse(preview.url);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              constraints: const BoxConstraints(minHeight: 34),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (siteName != null && siteName.isNotEmpty)
                    Text(
                      siteName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize - 2,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  if (title != null && title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize - 1,
                        fontWeight: FontWeight.w600,
                        color: body,
                      ),
                    ),
                  if (description != null && description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize - 2,
                        height: 1.25,
                        color: secondary,
                      ),
                    ),
                  if (imagePath != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AttachmentImage(
                        path: imagePath,
                        width: 226,
                        height: 118,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
