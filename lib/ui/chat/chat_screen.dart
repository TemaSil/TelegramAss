import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/glass_tokens.dart';
import '../../core/tg_theme.dart';
import '../../data/models.dart';
import '../common/tg_avatar.dart';
import '../common/wallpaper.dart';
import '../common/wallpaper_picker.dart';
import 'widgets/bubble_entrance.dart';
import 'widgets/composer_bar.dart';
import 'widgets/message_bubble.dart';
import '../../core/tg_icons.dart';
import '../../l10n/app_localizations.dart';

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

  /// Ids rendered at least once; anything outside this set is new and gets the
  /// spring entrance.
  final _settled = <int>{};

  TgMessage? _replyTo;
  TgMessage? _editing;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    final client = AppScope.read(context).client;
    _messages = client.currentMessagesOf(widget.chatId);
    _settled.addAll(_messages.map((message) => message.id));

    // Restore the draft the last visit left behind.
    final draft = AppScope.read(context).chatById(widget.chatId)?.draft;
    if (draft != null && draft.isNotEmpty) _composerController.text = draft;
    client.messagesOf(widget.chatId).listen((messages) {
      if (!mounted) return;
      final wasAtBottom = _isNearBottom;
      setState(() => _messages = messages);
      if (wasAtBottom) _scrollToBottom();
    });
    client.openChat(widget.chatId);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(jump: true),
    );
  }

  @override
  void dispose() {
    final state = AppScope.read(context);
    // Keep whatever is in the composer as a draft, the way Telegram does.
    state.setDraft(widget.chatId, _composerController.text.trim());
    state.client.closeChat(widget.chatId);
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
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.42,
      settings: GlassTokens.panel(context),
      quality: GlassQuality.premium,
      builder: (sheetContext) => _AttachmentSheet(
        onPhoto: () {
          Navigator.of(sheetContext).pop();
          _pickPhoto(ImageSource.gallery);
        },
        onCamera: () {
          Navigator.of(sheetContext).pop();
          _pickPhoto(ImageSource.camera);
        },
        onFile: () {
          Navigator.of(sheetContext).pop();
          _pickFile();
        },
        onLocation: () {
          Navigator.of(sheetContext).pop();
          GlassToast.show(
            context,
            message: AppL10n.of(context).locationNotWired,
            type: GlassToastType.info,
          );
        },
      ),
    );
  }

  /// Picks an image and sends it. A cancelled picker is not an error.
  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 88);
    } on PlatformException catch (error) {
      if (mounted) _reportPickFailure(error.message);
      return;
    }
    if (picked == null || !mounted) return;
    AppScope.read(context).client.sendPhoto(widget.chatId, path: picked.path);
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles();
    } on PlatformException catch (error) {
      if (mounted) _reportPickFailure(error.message);
      return;
    }
    if (picked.isEmpty || !mounted) return;

    final file = picked.first;
    // Native pickers usually report the size; fall back to reading it.
    final bytes = file.lengthSync() ?? await file.length();
    if (!mounted) return;

    AppScope.read(context).client.sendFile(
      widget.chatId,
      file.name,
      bytes == null ? '' : _humanSize(bytes),
      path: file.path,
    );
    _scrollToBottom();
  }

  void _reportPickFailure(String? detail) {
    GlassToast.show(
      context,
      message: detail ?? AppL10n.of(context).attachmentFailed,
      type: GlassToastType.error,
    );
  }

  static String _humanSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  Future<void> _openChatInfo(TgChat chat) async {
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.55,
      settings: GlassTokens.panel(context),
      quality: GlassQuality.premium,
      builder: (_) => _ChatInfoSheet(
        chat: chat,
        onMedia: () {
          Navigator.of(context).pop();
          _openMedia();
        },
        onWallpaper: () {
          Navigator.of(context).pop();
          showWallpaperPicker(context, AppScope.read(context));
        },
        onSearch: () {
          Navigator.of(context).pop();
          _openSearch();
        },
      ),
    );
  }

  /// In-chat message search, presented as a sheet over the conversation.
  Future<void> _openSearch() async {
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.6,
      settings: GlassTokens.panel(context),
      quality: GlassQuality.premium,
      builder: (_) => _SearchSheet(chatId: widget.chatId),
    );
  }

  /// Picks a destination chat and forwards [message] into it.
  Future<void> _forward(TgMessage message) async {
    final state = AppScope.read(context);
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.55,
      settings: GlassTokens.panel(context),
      quality: GlassQuality.premium,
      builder: (sheetContext) => _ForwardSheet(
        chats: state.chats.where((chat) => chat.id != widget.chatId).toList(),
        onPick: (chat) {
          Navigator.of(sheetContext).pop();
          state.client.sendText(chat.id, message.text);
          GlassToast.show(
            context,
            message: AppL10n.of(context).forwardedTo(chat.title),
            type: GlassToastType.success,
          );
        },
      ),
    );
  }

  Future<void> _openMedia() async {
    final photos = _messages
        .where((message) => message.kind == TgMessageKind.photo)
        .toList()
        .reversed
        .toList();
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.55,
      settings: GlassTokens.panel(context),
      quality: GlassQuality.premium,
      builder: (_) => _MediaSheet(photos: photos),
    );
  }

  Future<void> _confirmClearHistory() async {
    await GlassDialog.show<void>(
      context: context,
      title: AppL10n.of(context).clearHistoryTitle,
      message: AppL10n.of(context).clearHistoryMessage,
      settings: GlassTokens.menu(context),
      quality: GlassQuality.premium,
      actions: [
        GlassDialogAction(
          label: AppL10n.of(context).cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: AppL10n.of(context).clear,
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
        onSearch: _openSearch,
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
        settled: _settled,
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
        onForward: _forward,
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
    required this.onSearch,
    required this.onToggleMute,
  });

  final TgChat chat;
  final bool isTyping;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback onClearHistory;
  final VoidCallback onSearch;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return GlassAppBar(
      toolbarHeight: 56,
      centerTitle: false,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      leading: GlassIconButton(
        icon: const Icon(TgIcons.back, size: 22),
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
              photoPath: chat.photoPath,
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
                  isTyping ? l10n.typing : chat.presence,
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
            icon: const Icon(TgIcons.more, size: 20),
            size: 42,
            settings: GlassTokens.chrome(context),
            quality: GlassQuality.premium,
            onPressed: toggleMenu,
          ),
          items: [
            GlassMenuItem(
              title: l10n.chatInfo,
              icon: const Icon(TgIcons.info),
              onTap: onInfo,
            ),
            GlassMenuItem(
              title: chat.isMuted ? l10n.unmute : l10n.mute,
              icon: Icon(chat.isMuted ? TgIcons.unmute : TgIcons.mute),
              onTap: onToggleMute,
            ),
            GlassMenuItem(
              title: l10n.searchInChat,
              icon: const Icon(TgIcons.search),
              onTap: onSearch,
            ),
            const GlassMenuDivider(),
            GlassMenuItem(
              title: l10n.clearHistory,
              icon: const Icon(TgIcons.delete),
              isDestructive: true,
              onTap: onClearHistory,
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.chat,
    required this.messages,
    required this.settled,
    required this.scrollController,
    required this.fontSize,
    required this.isTyping,
    required this.loadingMore,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onForward,
    required this.onReact,
  });

  final TgChat chat;
  final List<TgMessage> messages;
  final Set<int> settled;
  final ScrollController scrollController;
  final double fontSize;
  final bool isTyping;
  final bool loadingMore;
  final ValueChanged<TgMessage> onReply;
  final ValueChanged<TgMessage> onEdit;
  final ValueChanged<TgMessage> onDelete;
  final ValueChanged<TgMessage> onForward;
  final void Function(TgMessage, String) onReact;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList>
    with SingleTickerProviderStateMixin {
  /// How far the thread is dragged left, revealing per-message timestamps —
  /// the iMessage gesture.
  static const _revealExtent = 64.0;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _reveal.value = (_reveal.value - details.primaryDelta! / _revealExtent)
        .clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    // Fling left holds the timestamps open; anything else springs back.
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -220 || (_reveal.value > 0.6 && velocity <= 0)) {
      _reveal.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      _reveal.animateTo(0, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final messages = widget.messages;
    final topPad = MediaQuery.paddingOf(context).top + 56;

    return GlassScrollEdgeEffect(
      fadeTop: true,
      fadeBottom: false,
      topFadeHeight: topPad,
      style: GlassScrollEdgeStyle.blur,
      child: GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: ListView.builder(
          controller: widget.scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 16),
          itemCount:
              messages.length +
              (widget.isTyping ? 1 : 0) +
              (widget.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            var cursor = index;

            if (widget.loadingMore) {
              if (cursor == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: GlassProgressIndicator.circular(
                      size: 22,
                      strokeWidth: 2.5,
                    ),
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
            final next = cursor + 1 < messages.length
                ? messages[cursor + 1]
                : null;

            final needsSeparator =
                previous == null || !_sameDay(previous.date, message.date);
            final showTail =
                next == null ||
                next.isOutgoing != message.isOutgoing ||
                next.date.difference(message.date).inMinutes > 4;
            final showSender =
                chat.kind == TgChatKind.group &&
                (previous == null || previous.isOutgoing != message.isOutgoing);

            // Only the very last outgoing message carries the status line.
            final isLastOutgoing =
                message.isOutgoing &&
                messages.skip(cursor + 1).every((m) => !m.isOutgoing);
            final isNew = !widget.settled.contains(message.id);
            widget.settled.add(message.id);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (needsSeparator) _DaySeparator(date: message.date),
                _RevealRow(
                  reveal: _reveal,
                  extent: _revealExtent,
                  date: message.date,
                  child: BubbleEntrance(
                    enabled: isNew,
                    fromRight: message.isOutgoing,
                    child: MessageBubble(
                      message: message,
                      fontSize: widget.fontSize,
                      showTail: showTail,
                      showSender: showSender,
                      onReply: widget.onReply,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                      onForward: widget.onForward,
                      onReact: widget.onReact,
                    ),
                  ),
                ),
                if (isLastOutgoing)
                  DeliveryFootnote(
                    label: _statusLabel(message.status, AppL10n.of(context)),
                    color: TgColors.tertiaryLabel.resolveFrom(context),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _statusLabel(TgMessageStatus status, AppL10n l10n) {
    switch (status) {
      case TgMessageStatus.sending:
        return l10n.statusSending;
      case TgMessageStatus.failed:
        return l10n.statusFailed;
      case TgMessageStatus.sent:
        return l10n.statusSent;
      case TgMessageStatus.delivered:
        return l10n.statusDelivered;
      case TgMessageStatus.read:
        return l10n.statusRead;
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Slides a bubble left as the thread is dragged, revealing its timestamp in
/// the gutter behind it.
class _RevealRow extends StatelessWidget {
  const _RevealRow({
    required this.reveal,
    required this.extent,
    required this.date,
    required this.child,
  });

  final Animation<double> reveal;
  final double extent;
  final DateTime date;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, child) {
        final t = reveal.value;
        return Stack(
          children: [
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: t,
                child: Center(
                  child: Text(
                    TgFormat.time(date),
                    style: TgText.timestamp(context),
                  ),
                ),
              ),
            ),
            Transform.translate(offset: Offset(-extent * t, 0), child: child),
          ],
        );
      },
      child: child,
    );
  }
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
            final scale =
                0.6 + 0.4 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
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

/// Search over the messages of one conversation.
class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.chatId});

  final int chatId;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();
  List<TgMessage> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassSearchBar(
            controller: _controller,
            placeholder: l10n.searchInChat,
            autofocus: true,
            settings: GlassTokens.chrome(context),
            onChanged: (query) => setState(() {
              _results = AppScope.read(context).client
                  .searchMessages(widget.chatId, query);
            }),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _controller.text.isEmpty
                          ? l10n.searchInChatHint
                          : l10n.noMatches,
                      style: TgText.rowPreview(context),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final message = _results[index];
                      return GlassListTile.standalone(
                        leading: Icon(
                          message.isOutgoing ? TgIcons.sent : TgIcons.chats,
                          size: 18,
                        ),
                        title: Text(
                          message.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${TgFormat.daySeparator(message.date)} · '
                          '${TgFormat.time(message.date)}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Chat picker used when forwarding a message.
class _ForwardSheet extends StatelessWidget {
  const _ForwardSheet({required this.chats, required this.onPick});

  final List<TgChat> chats;
  final ValueChanged<TgChat> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.forwardTo,
            textAlign: TextAlign.center,
            style: TgText.rowTitle(context),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return GlassListTile.standalone(
                  leading: TgAvatar(
                    seed: chat.id,
                    initials: chat.initials,
                    size: 38,
                    photoPath: chat.photoPath,
                  ),
                  title: Text(chat.title, maxLines: 1),
                  subtitle: Text(chat.presence, maxLines: 1),
                  trailing: const Icon(TgIcons.forwardMessage, size: 17),
                  onTap: () => onPick(chat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo grid for the chat's shared media.
class _MediaSheet extends StatelessWidget {
  const _MediaSheet({required this.photos});

  final List<TgMessage> photos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (photos.isEmpty) {
      return Center(
        child: Text(l10n.noMediaYet, style: TgText.rowPreview(context)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.photosCount(photos.length),
            textAlign: TextAlign.center,
            style: TgText.rowTitle(context),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final colors = TgColors.avatarGradient(
                  photos[index].mediaSeed ?? photos[index].id,
                );
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({
    required this.onPhoto,
    required this.onCamera,
    required this.onFile,
    required this.onLocation,
  });

  final VoidCallback onPhoto;
  final VoidCallback onCamera;
  final VoidCallback onFile;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.send,
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
                icon: const Icon(TgIcons.photo),
                label: l10n.photo,
                onTap: onPhoto,
              ),
              GlassButtonGroupItem(
                icon: const Icon(TgIcons.camera),
                label: l10n.camera,
                onTap: onCamera,
              ),
              GlassButtonGroupItem(
                icon: const Icon(TgIcons.document),
                label: l10n.file,
                onTap: onFile,
              ),
              GlassButtonGroupItem(
                icon: const Icon(TgIcons.location),
                label: l10n.location,
                onTap: onLocation,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassGroupedSection(
            header: Text(l10n.recent),
            settings: GlassTokens.panel(context),
            children: [
              GlassListTile(
                leading: const Icon(TgIcons.media),
                title: Text(l10n.cameraRoll),
                subtitle: Text(l10n.chooseFromGallery),
                trailing: const Icon(TgIcons.forward, size: 16),
                onTap: onPhoto,
              ),
              GlassListTile(
                leading: const Icon(TgIcons.folder),
                title: Text(l10n.documents),
                subtitle: Text(l10n.browseFiles),
                trailing: const Icon(TgIcons.forward, size: 16),
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
  const _ChatInfoSheet({
    required this.chat,
    required this.onMedia,
    required this.onWallpaper,
    required this.onSearch,
  });

  final TgChat chat;
  final VoidCallback onMedia;
  final VoidCallback onWallpaper;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
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
              photoPath: chat.photoPath,
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
                icon: const Icon(TgIcons.calls),
                label: l10n.call,
                onTap: () {},
              ),
              GlassButtonGroupItem(
                icon: const Icon(TgIcons.video),
                label: l10n.video,
                onTap: () {},
              ),
              GlassButtonGroupItem(
                icon: const Icon(TgIcons.search),
                label: l10n.search,
                onTap: onSearch,
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            header: Text(l10n.info),
            settings: GlassTokens.panel(context),
            children: [
              GlassListTile(
                leading: const Icon(TgIcons.unmute),
                title: Text(l10n.notifications),
                trailing: Text(
                  chat.isMuted ? 'Off' : 'On',
                  style: TgText.rowPreview(context),
                ),
              ),
              GlassListTile(
                leading: const Icon(TgIcons.media),
                title: Text(l10n.mediaLinksDocs),
                trailing: const Icon(TgIcons.forward, size: 16),
                onTap: onMedia,
              ),
              GlassListTile(
                leading: const Icon(TgIcons.wallpaper),
                title: Text(l10n.chatWallpaper),
                trailing: const Icon(TgIcons.forward, size: 16),
                onTap: onWallpaper,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
