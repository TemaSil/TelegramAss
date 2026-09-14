import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/formatters.dart';
import '../../../core/glass_tokens.dart';
import '../../../core/tg_theme.dart';
import '../../../data/models.dart';
import '../../common/tg_avatar.dart';
import '../../../core/tg_icons.dart';

/// One conversation in the chat list.
///
/// The row itself is not glass — a list of 30 glass panels would both cost
/// frames and read as noise. Glass is reserved for what floats: the unread
/// badge, and the context menu the row opens on long press.
class ChatRow extends StatelessWidget {
  const ChatRow({
    super.key,
    required this.chat,
    required this.onTap,
    required this.onMute,
    required this.onPin,
    required this.onMarkRead,
    required this.onDelete,
    this.isTyping = false,
  });

  final TgChat chat;
  final VoidCallback onTap;
  final VoidCallback onMute;
  final VoidCallback onPin;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    return GlassMenu(
      menuWidth: 250,
      menuBorderRadius: 28,
      quality: GlassQuality.premium,
      settings: GlassTokens.menu(context),
      menuAlignment: GlassMenuAlignment.bottomLeft,
      triggerBuilder: (context, toggleMenu) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: toggleMenu,
        child: _content(context),
      ),
      items: [
        GlassMenuItem(
          title: chat.isPinned ? 'Unpin' : 'Pin to top',
          icon: const Icon(TgIcons.pin),
          onTap: onPin,
        ),
        GlassMenuItem(
          title: chat.isMuted ? 'Unmute' : 'Mute',
          icon: Icon(chat.isMuted ? TgIcons.unmute : TgIcons.mute),
          onTap: onMute,
        ),
        if (chat.unreadCount > 0)
          GlassMenuItem(
            title: 'Mark as read',
            icon: const Icon(TgIcons.markRead),
            onTap: onMarkRead,
          ),
        const GlassMenuDivider(),
        GlassMenuItem(
          title: 'Delete chat',
          icon: const Icon(TgIcons.delete),
          isDestructive: true,
          onTap: onDelete,
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TgAvatar(
            seed: chat.id,
            initials: chat.initials,
            isOnline: chat.isOnline,
            hasStory: chat.hasStory,
            icon: _iconFor(chat.kind),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TgText.rowTitle(context),
                      ),
                    ),
                    if (chat.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        TgIcons.verified,
                        size: 14,
                        color: TgColors.accent.resolveFrom(context),
                      ),
                    ],
                    if (chat.isMuted) ...[
                      const SizedBox(width: 4),
                      Icon(
                        TgIcons.muteFilled,
                        size: 13,
                        color: TgColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ],
                    const Spacer(),
                    if (chat.lastMessageOutgoing && chat.unreadCount == 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: _StatusTicks(status: chat.lastMessageStatus),
                      ),
                    Text(
                      TgFormat.listStamp(chat.lastMessageTime),
                      style: TgText.timestamp(context),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _preview(context)),
                    if (chat.unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      _UnreadBadge(
                        count: chat.unreadCount,
                        muted: chat.isMuted,
                      ),
                    ] else if (chat.isPinned) ...[
                      const SizedBox(width: 8),
                      Icon(
                        TgIcons.pinFilled,
                        size: 13,
                        color: TgColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    if (isTyping) {
      return Text(
        'typing…',
        maxLines: 1,
        style: TgText.rowPreview(context).copyWith(
          color: TgColors.accent.resolveFrom(context),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (chat.draft != null && chat.draft!.isNotEmpty) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Draft: ',
              style: TextStyle(
                color: TgColors.destructive.resolveFrom(context),
              ),
            ),
            TextSpan(text: chat.draft),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TgText.rowPreview(context),
      );
    }

    return Text(
      chat.lastMessage ?? '',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TgText.rowPreview(context),
    );
  }

  static IconData? _iconFor(TgChatKind kind) {
    switch (kind) {
      case TgChatKind.saved:
        return TgIcons.saved;
      case TgChatKind.bot:
        return TgIcons.bot;
      case TgChatKind.channel:
        return TgIcons.channel;
      case TgChatKind.private:
      case TgChatKind.group:
        return null;
    }
  }
}

/// Unread counter — a real glass pill so it lifts off the row.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.muted});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final label = count > 999 ? '999+' : '$count';
    final tint = muted
        ? TgColors.tertiaryLabel.resolveFrom(context)
        : TgColors.accent.resolveFrom(context);

    return GlassContainer(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: const LiquidRoundedRectangle(borderRadius: 11.5),
      settings: GlassTokens.chrome(context)
          .copyWith(glassColor: tint.withValues(alpha: 0.72), thickness: 10),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.white,
          ),
        ),
      ),
    );
  }
}

/// One tick for sent, two for delivered, two tinted for read.
class _StatusTicks extends StatelessWidget {
  const _StatusTicks({required this.status, this.color});

  final TgMessageStatus status;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (status == TgMessageStatus.sending) {
      return Icon(
        TgIcons.pending,
        size: 13,
        color: color ?? TgColors.tertiaryLabel.resolveFrom(context),
      );
    }
    if (status == TgMessageStatus.failed) {
      return Icon(
        TgIcons.failed,
        size: 13,
        color: TgColors.destructive.resolveFrom(context),
      );
    }

    final tint = status == TgMessageStatus.read
        ? (color ?? TgColors.accent.resolveFrom(context))
        : (color ?? TgColors.tertiaryLabel.resolveFrom(context));

    if (status == TgMessageStatus.sent) {
      return Icon(TgIcons.sent, size: 14, color: tint);
    }

    // Double tick — two glyphs overlapped, which is how Telegram draws it.
    return SizedBox(
      width: 18,
      height: 14,
      child: Stack(
        children: [
          Positioned(left: 0, child: Icon(TgIcons.sent, size: 14, color: tint)),
          Positioned(left: 5, child: Icon(TgIcons.sent, size: 14, color: tint)),
        ],
      ),
    );
  }
}

/// Re-exported so the conversation view can draw the same ticks.
class MessageStatusTicks extends StatelessWidget {
  const MessageStatusTicks({super.key, required this.status, this.color});

  final TgMessageStatus status;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      _StatusTicks(status: status, color: color);
}
