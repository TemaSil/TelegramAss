import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/models.dart';
import '../common/tg_avatar.dart';
import '../common/wallpaper.dart';
import 'widgets/composer_bar.dart';
import 'widgets/message_bubble.dart';

/// One conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final int chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();

  List<TgMessage> _messages = const [];
  TgMessage? _replyTo;
  TgMessage? _editing;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    final client = AppScope.read(context).client;
    _messages = client.currentMessagesOf(widget.chatId);
    client.messagesOf(widget.chatId).listen((messages) {
      if (!mounted) return;
      final wasAtBottom = _isNearBottom;
      setState(() => _messages = messages);
      if (wasAtBottom) _scrollToBottom();
    });
    client.openChat(widget.chatId);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
  }

  @override
  void dispose() {
    AppScope.read(context).client.closeChat(widget.chatId);
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 220;
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _onScroll() async {
    if (_loadingMore || !_scrollController.hasClients) return;
    if (_scrollController.position.pixels > 80) return;
    setState(() => _loadingMore = true);
    await AppScope.read(context).client.loadMoreMessages(widget.chatId);
    if (mounted) setState(() => _loadingMore = false);
  }

  void _send() {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    final client = AppScope.read(context).client;

    if (_editing != null) {
      client.editMessage(widget.chatId, _editing!.id, text);
    } else {
      client.sendText(widget.chatId, text, replyTo: _replyTo);
    }

    _composerController.clear();
    setState(() {
      _replyTo = null;
      _editing = null;
    });
    _scrollToBottom();
  }

  Future<void> _openAttachments() async {
    final client = AppScope.read(context).client;
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.42,
      settings: GlassTokens.panel(context),
      quality: GlassQuality.premium,
      builder: (sheetContext) => _AttachmentSheet(
        onPhoto: () {
          Navigator.of(sheetContext).pop();
          client.sendPhoto(widget.chatId);
          _scrollToBottom();
        },
        onFile: () {
          Navigator.of(sheetContext).pop();
          client.sendFile(widget.chatId, 'liquid-glass-spec.pdf', '2.4 MB');
          _scrollToBottom();
        },
        onLocation: () {
          Navigator.of(sheetContext).pop();
          GlassToast.show(
            context,
            message: 'Location sharing is not wired up yet',
            type: GlassToastType.info,
          );
        },
      ),
    );
  }

  Future<void> _openChatInfo(TgChat chat) async {
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.55,
      settings: GlassTokens.panel(context),
      quality: GlassQuality.premium,
      builder: (_) => _ChatInfoSheet(chat: chat),
    );
  }

  Future<void> _confirmClearHistory() async {
    await GlassDialog.show<void>(
      context: context,
      title: 'Clear history?',
      message: 'All messages in this chat will be removed on this device.',
      settings: GlassTokens.menu(context),
      quality: GlassQuality.premium,
      actions: [
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: 'Clear',
          isDestructive: true,
          onPressed: () {
            Navigator.of(context).pop();
            final client = AppScope.read(context).client;
            for (final message in List<TgMessage>.from(_messages)) {
              client.deleteMessage(widget.chatId, message.id);
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final chat = state.chatById(widget.chatId);
    if (chat == null) return const SizedBox.shrink();

    final isTyping = state.typingChatId == widget.chatId;

    return GlassScaffold(
      background: GlassWallpaper(
        variant: state.wallpaper,
        animate: !state.reduceTransparency,
      ),
      settings: GlassTokens.chrome(context),
      statusBarStyle: GlassStatusBarStyle.auto,
      appBarHeight: 56,
      resizeToAvoidBottomInset: true,
      appBar: _ChatAppBar(
        chat: chat,
        isTyping: isTyping,
        onBack: () => Navigator.of(context).maybePop(),
        onInfo: () => _openChatInfo(chat),
        onClearHistory: _confirmClearHistory,
        onToggleMute: () => state.client.toggleMute(chat.id),
      ),
      bottomBar: ComposerBar(
        controller: _composerController,
        replyTo: _replyTo,
        editing: _editing,
        onCancelReply: () => setState(() {
          _replyTo = null;
          _editing = null;
          _composerController.clear();
        }),
        onSend: _send,
        onAttach: _openAttachments,
        onVoice: () {
          HapticFeedback.mediumImpact();
          state.client.sendVoice(widget.chatId, 8);
          _scrollToBottom();
        },
      ),
      body: _MessageList(
        chat: chat,
        messages: _messages,
        scrollController: _scrollController,
        fontSize: state.messageFontSize.toDouble(),
        isTyping: isTyping,
        loadingMore: _loadingMore,
        onReply: (message) => setState(() {
          _editing = null;
          _replyTo = message;
        }),
        onEdit: (message) => setState(() {
          _replyTo = null;
          _editing = message;
          _composerController.text = message.text;
        }),
        onDelete: (message) =>
            state.client.deleteMessage(widget.chatId, message.id),
        onReact: (message, emoji) =>
            state.client.toggleReaction(widget.chatId, message.id, emoji),
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget {
  const _ChatAppBar({
    required this.chat,
    required this.isTyping,
    required this.onBack,
    required this.onInfo,
    required this.onClearHistory,
    required this.onToggleMute,
  });

  final TgChat chat;
  final bool isTyping;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback onClearHistory;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return GlassAppBar(
      toolbarHeight: 56,
      centerTitle: false,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      leading: GlassIconButton(
        icon: const Icon(CupertinoIcons.back, size: 22),
        size: 42,
        settings: GlassTokens.chrome(context),
        quality: GlassQuality.premium,
        onPressed: onBack,
      ),
      title: GestureDetector(
        onTap: onInfo,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TgAvatar(
              seed: chat.id,
              initials: chat.initials,
              size: 36,
              isOnline: chat.isOnline,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TgText.navTitle(context),
                ),
                Text(
                  isTyping ? 'typing…' : chat.presence,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isTyping || chat.isOnline
                        ? TgColors.accent.resolveFrom(context)
                        : TgColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        GlassMenu(
          menuWidth: 235,
          menuBorderRadius: 26,
          quality: GlassQuality.premium,
          settings: GlassTokens.menu(context),
          menuAlignment: GlassMenuAlignment.bottomRight,
          triggerBuilder: (context, toggleMenu) => GlassIconButton(
            icon: const Icon(CupertinoIcons.ellipsis, size: 20),
            size: 42,
            settings: GlassTokens.chrome(context),
            quality: GlassQuality.premium,
            onPressed: toggleMenu,
          ),
          items: [
            GlassMenuItem(
              title: 'Chat info',
              icon: const Icon(CupertinoIcons.info_circle),
              onTap: onInfo,
            ),
            GlassMenuItem(
              title: chat.isMuted ? 'Unmute' : 'Mute',
              icon: Icon(chat.isMuted
                  ? CupertinoIcons.bell
                  : CupertinoIcons.bell_slash),
              onTap: onToggleMute,
            ),
            GlassMenuItem(
              title: 'Search in chat',
              icon: const Icon(CupertinoIcons.search),
              onTap: () {},
            ),
            const GlassMenuDivider(),
            GlassMenuItem(
              title: 'Clear history',
              icon: const Icon(CupertinoIcons.trash),
              isDestructive: true,
              onTap: onClearHistory,
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.chat,
    required this.messages,
    required this.scrollController,
    required this.fontSize,
    required this.isTyping,
    required this.loadingMore,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReact,
  });

  final TgChat chat;
  final List<TgMessage> messages;
  final ScrollController scrollController;
  final double fontSize;
  final bool isTyping;
  final bool loadingMore;
  final ValueChanged<TgMessage> onReply;
  final ValueChanged<TgMessage> onEdit;
  final ValueChanged<TgMessage> onDelete;
  final void Function(TgMessage, String) onReact;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top + 56;

    return GlassScrollEdgeEffect(
      fadeTop: true,
      fadeBottom: false,
      topFadeHeight: topPad,
      style: GlassScrollEdgeStyle.blur,
      child: ListView.builder(
        controller: scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 16),
        itemCount: messages.length + (isTyping ? 1 : 0) + (loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          var cursor = index;

          if (loadingMore) {
            if (cursor == 0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: GlassProgressIndicator.circular(size: 22, strokeWidth: 2.5),
                ),
              );
            }
            cursor -= 1;
          }

          if (cursor >= messages.length) {
            return _TypingBubble(name: chat.title);
          }

          final message = messages[cursor];
          final previous = cursor > 0 ? messages[cursor - 1] : null;
          final next =
              cursor + 1 < messages.length ? messages[cursor + 1] : null;

          final needsSeparator = previous == null ||
              !_sameDay(previous.date, message.date);
          final showTail = next == null ||
              next.isOutgoing != message.isOutgoing ||
              next.date.difference(message.date).inMinutes > 4;
          final showSender = chat.kind == TgChatKind.group &&
              (previous == null || previous.isOutgoing != message.isOutgoing);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (needsSeparator) _DaySeparator(date: message.date),
              MessageBubble(
                message: message,
                fontSize: fontSize,
                showTail: showTail,
                showSender: showSender,
                onReply: onReply,
                onEdit: onEdit,
                onDelete: onDelete,
                onReact: onReact,
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: GlassContainer(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const LiquidRoundedRectangle(borderRadius: 14),
          settings: GlassTokens.chrome(context),
          child: Center(
            child: Text(
              TgFormat.daySeparator(date),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: TgColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 56, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlassContainer(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const LiquidRoundedRectangle(
            borderRadius: GlassTokens.bubbleRadius,
          ),
          settings: GlassTokens.incomingBubble(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TypingDots(),
              const SizedBox(width: 8),
              Text('typing…', style: TgText.timestamp(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value * 3 - index).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TgColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({
    required this.onPhoto,
    required this.onFile,
    required this.onLocation,
  });

  final VoidCallback onPhoto;
  final VoidCallback onFile;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Send',
            textAlign: TextAlign.center,
            style: TgText.rowTitle(context),
          ),
          const SizedBox(height: 18),
          GlassButtonGroup.icons(
            direction: Axis.horizontal,
            quality: GlassQuality.premium,
            settings: GlassTokens.chrome(context),
            iconSize: 22,
            items: [
              GlassButtonGroupItem(
                icon: const Icon(CupertinoIcons.photo),
                label: 'Photo',
                onTap: onPhoto,
              ),
              GlassButtonGroupItem(
                icon: const Icon(CupertinoIcons.doc),
                label: 'File',
                onTap: onFile,
              ),
              GlassButtonGroupItem(
                icon: const Icon(CupertinoIcons.location),
                label: 'Location',
                onTap: onLocation,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassGroupedSection(
            header: const Text('Recent'),
            settings: GlassTokens.panel(context),
            children: [
              GlassListTile(
                leading: const Icon(CupertinoIcons.photo_on_rectangle),
                title: const Text('Camera roll'),
                subtitle: const Text('248 items'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: onPhoto,
              ),
              GlassListTile(
                leading: const Icon(CupertinoIcons.folder),
                title: const Text('Documents'),
                subtitle: const Text('Browse files'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: onFile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatInfoSheet extends StatelessWidget {
  const _ChatInfoSheet({required this.chat});

  final TgChat chat;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: TgAvatar(
              seed: chat.id,
              initials: chat.initials,
              size: 84,
              isOnline: chat.isOnline,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            chat.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: TgColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chat.presence,
            textAlign: TextAlign.center,
            style: TgText.rowPreview(context),
          ),
          const SizedBox(height: 20),
          GlassButtonGroup.icons(
            direction: Axis.horizontal,
            quality: GlassQuality.premium,
            settings: GlassTokens.chrome(context),
            items: [
              GlassButtonGroupItem(
                icon: const Icon(CupertinoIcons.phone),
                label: 'Call',
                onTap: () {},
              ),
              GlassButtonGroupItem(
                icon: const Icon(CupertinoIcons.videocam),
                label: 'Video',
                onTap: () {},
              ),
              GlassButtonGroupItem(
                icon: const Icon(CupertinoIcons.search),
                label: 'Search',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            header: const Text('Info'),
            settings: GlassTokens.panel(context),
            children: [
              GlassListTile(
                leading: const Icon(CupertinoIcons.bell),
                title: const Text('Notifications'),
                trailing: Text(
                  chat.isMuted ? 'Off' : 'On',
                  style: TgText.rowPreview(context),
                ),
              ),
              GlassListTile(
                leading: const Icon(CupertinoIcons.photo_on_rectangle),
                title: const Text('Media, links and docs'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: () {},
              ),
              GlassListTile(
                leading: const Icon(CupertinoIcons.paintbrush),
                title: const Text('Chat wallpaper'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
