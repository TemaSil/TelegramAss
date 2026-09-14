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
import '../../data/notifications.dart';
import '../common/tg_avatar.dart';
import '../common/wallpaper.dart';
import '../common/wallpaper_picker.dart';
import 'widgets/attachment_sheet.dart';
import 'widgets/bubble_entrance.dart';
import 'widgets/composer_bar.dart';
import 'widgets/attachment_image.dart';
import 'widgets/message_bubble.dart';
import 'widgets/photo_viewer.dart';
import '../../core/tg_icons.dart';
import '../../l10n/app_localizations.dart';

/// One conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId, this.unreadCount});

  final int chatId;

  /// How many messages were unread when the row was tapped.
  ///
  /// The chat list marks the chat read before pushing this screen, so by the
  /// time it builds the badge is already gone — the count has to be carried in
  /// or the unread divider could never be placed.
  final int? unreadCount;

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

  /// Id of the first message the user has not read, fixed when the chat opens
  /// so the divider does not jump as the badge clears behind it.
  int? _unreadAnchorId;
  bool _unreadAnchorResolved = false;

  /// Drives the jump-to-latest button, which only shows once the thread is
  /// scrolled away from the newest message.
  bool _showJumpToLatest = false;

  /// Keys of the message rows currently built, so a search hit or a pinned
  /// message can be scrolled to.
  final _messageKeys = <int, GlobalKey>{};

  /// Message flashed after a jump, the way Telegram marks where it landed.
  int? _highlighted;

  /// Pinned messages, newest first, and which one the bar is showing. Tapping
  /// the bar walks through them, as the official clients do.
  List<TgMessage> _pinned = const [];
  int _pinnedIndex = 0;

  /// Messages picked in selection mode. Non-empty means the thread is in that
  /// mode: the composer becomes an action bar and taps toggle instead of open.
  final _selected = <int>{};

  @override
  void initState() {
    super.initState();
    final client = AppScope.read(context).client;
    _messages = client.currentMessagesOf(widget.chatId);
    _settled.addAll(_messages.map((message) => message.id));

    // Restore the draft the last visit left behind.
    final draft = AppScope.read(context).chatById(widget.chatId)?.draft;
    if (draft != null && draft.isNotEmpty) _composerController.text = draft;
    _resolveUnreadAnchor();
    _loadPinned();
    client.messagesOf(widget.chatId).listen((messages) {
      if (!mounted) return;
      final wasAtBottom = _isNearBottom;
      setState(() => _messages = messages);
      _resolveUnreadAnchor();
      if (wasAtBottom) _scrollToBottom();
    });
    client.openChat(widget.chatId);
    // While this chat is on screen its messages are read, not announced.
    TgNotifications.instance.setOpenChat(widget.chatId);
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
    TgNotifications.instance.setOpenChat(null);
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

  /// Places the "unread messages" divider once, from the badge the chat list
  /// was showing. TDLib clears that count the moment the chat opens, so it is
  /// read before anything else and never recomputed.
  void _resolveUnreadAnchor() {
    if (_unreadAnchorResolved) return;
    final unread =
        widget.unreadCount ??
        AppScope.read(context).chatById(widget.chatId)?.unreadCount;
    if (unread == null) return;
    _unreadAnchorResolved = true;
    if (unread <= 0) return;

    final incoming = _messages.where((m) => !m.isOutgoing).toList();
    if (incoming.isEmpty) return;
    final index = incoming.length - unread;
    _unreadAnchorId = incoming[index < 0 ? 0 : index].id;
  }

  /// Scrolls to a message and flashes it.
  ///
  /// Only rows the list has actually built carry a context, so a message far
  /// up the thread is first approached by proportion and then settled on
  /// exactly once it exists.
  Future<void> _jumpTo(int messageId) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    if (_messageKeys[messageId]?.currentContext == null &&
        _scrollController.hasClients) {
      final extent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(
        (extent * index / _messages.length).clamp(0.0, extent),
      );
      await WidgetsBinding.instance.endOfFrame;
    }

    final target = _messageKeys[messageId]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.4,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }

    if (!mounted) return;
    setState(() => _highlighted = messageId);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _highlighted = null);
  }

  void _toggleSelected(TgMessage message) {
    setState(() {
      if (!_selected.remove(message.id)) _selected.add(message.id);
    });
  }

  void _deleteSelected() {
    final client = AppScope.read(context).client;
    for (final id in _selected) {
      client.deleteMessage(widget.chatId, id);
    }
    setState(_selected.clear);
  }

  Future<void> _loadPinned() async {
    final pinned = await AppScope.read(context).client
        .pinnedMessages(widget.chatId);
    if (!mounted) return;
    setState(() {
      _pinned = pinned;
      _pinnedIndex = 0;
    });
  }

  void _tapPinnedBar() {
    if (_pinned.isEmpty) return;
    final message = _pinned[_pinnedIndex];
    setState(() => _pinnedIndex = (_pinnedIndex + 1) % _pinned.length);
    _jumpTo(message.id);
  }

  Future<void> _togglePinned(TgMessage message) async {
    final isPinned = _pinned.any((pinned) => pinned.id == message.id);
    await AppScope.read(context).client
        .setMessagePinned(widget.chatId, message.id, pinned: !isPinned);
    // TDLib reports the change as a service message rather than an update we
    // track, so the list is simply re-read.
    await _loadPinned();
  }

  Future<void> _onScroll() async {
    final shouldShow = !_isNearBottom;
    if (shouldShow != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = shouldShow);
    }
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
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoPopupSurface(
        isSurfacePainted: true,
        child: AttachmentSheet(
          onPickedAsset: (path) {
            Navigator.of(sheetContext).pop();
            AppScope.read(context).client.sendPhoto(widget.chatId, path: path);
            _scrollToBottom();
          },
          onGallery: () {
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
      quality: GlassTokens.heroQuality(context),
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
        onMembers: () {
          Navigator.of(context).pop();
          _openMembers(chat);
        },
        onLeave: () {
          Navigator.of(context).pop();
          _confirmLeave(chat);
        },
      ),
    );
  }

  /// Who is in the group or channel.
  Future<void> _openMembers(TgChat chat) async {
    final members = await AppScope.read(context).client.chatMembers(chat.id);
    if (!mounted) return;
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.65,
      settings: GlassTokens.panel(context),
      quality: GlassTokens.heroQuality(context),
      builder: (_) => _MembersSheet(members: members),
    );
  }

  Future<void> _confirmLeave(TgChat chat) async {
    final l10n = AppL10n.of(context);
    await GlassDialog.show<void>(
      context: context,
      title: chat.kind == TgChatKind.channel
          ? l10n.leaveChannel
          : l10n.leaveGroup,
      message: chat.title,
      settings: GlassTokens.menu(context),
      actions: [
        GlassDialogAction(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: l10n.leave,
          isDestructive: true,
          onPressed: () {
            Navigator.of(context).pop();
            AppScope.read(context).client.leaveChat(chat.id);
            // Leaving closes the conversation, as it does everywhere else.
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }

  /// In-chat message search, presented as a sheet over the conversation.
  Future<void> _openSearch() async {
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.6,
      settings: GlassTokens.panel(context),
      quality: GlassTokens.heroQuality(context),
      builder: (sheetContext) => _SearchSheet(
        chatId: widget.chatId,
        onOpen: (message) {
          Navigator.of(sheetContext).pop();
          _jumpTo(message.id);
        },
      ),
    );
  }

  /// Picks a destination chat and forwards [message] into it.
  Future<void> _forward(TgMessage message) => _forwardAll([message.id]);

  /// Forwards a set of messages, keeping Telegram's own attribution header —
  /// or, with [asCopy], sending them as if written fresh, which is what the
  /// mods call forwarding without quoting.
  Future<void> _forwardAll(List<int> messageIds, {bool asCopy = false}) async {
    if (messageIds.isEmpty) return;
    final state = AppScope.read(context);
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.55,
      settings: GlassTokens.panel(context),
      quality: GlassTokens.heroQuality(context),
      builder: (sheetContext) => _ForwardSheet(
        chats: state.chats.where((chat) => chat.id != widget.chatId).toList(),
        onPick: (chat) {
          Navigator.of(sheetContext).pop();
          state.client.forwardMessages(
            widget.chatId,
            chat.id,
            messageIds,
            asCopy: asCopy,
          );
          setState(_selected.clear);
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
      quality: GlassTokens.heroQuality(context),
      builder: (_) => _MediaSheet(photos: photos),
    );
  }

  Future<void> _confirmClearHistory() async {
    await GlassDialog.show<void>(
      context: context,
      title: AppL10n.of(context).clearHistoryTitle,
      message: AppL10n.of(context).clearHistoryMessage,
      settings: GlassTokens.menu(context),
      quality: GlassTokens.heroQuality(context),
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
      bottomBar: _selected.isNotEmpty
          ? _SelectionBar(
              count: _selected.length,
              onCancel: () => setState(_selected.clear),
              onForward: () => _forwardAll(_selected.toList()),
              onDelete: _deleteSelected,
            )
          : ComposerBar(
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
              onVoiceRecorded: (path, seconds, isOpus) {
                state.client.sendVoice(
                  widget.chatId,
                  seconds,
                  path: path,
                  isOpus: isOpus,
                );
                _scrollToBottom();
              },
            ),
      body: Stack(
        children: [
          _MessageList(
            chat: chat,
            messages: _messages,
            settled: _settled,
            scrollController: _scrollController,
            fontSize: state.messageFontSize.toDouble(),
            isTyping: isTyping,
            loadingMore: _loadingMore,
            unreadAnchorId: _unreadAnchorId,
            // The pinned bar floats over the thread; the list has to start below
            // it or the newest messages hide behind it.
            extraTopPadding: _pinned.isEmpty ? 0 : 50,
            messageKeys: _messageKeys,
            highlightedId: _highlighted,
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
            onForwardCopy: (message) => _forwardAll([message.id], asCopy: true),
            onTogglePin: _togglePinned,
            pinnedIds: {for (final message in _pinned) message.id},
            selected: _selected,
            onToggleSelected: _toggleSelected,
            onReact: (message, emoji) =>
                state.client.toggleReaction(widget.chatId, message.id, emoji),
          ),
          if (_pinned.isNotEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              left: 0,
              right: 0,
              child: _PinnedBar(
                message: _pinned[_pinnedIndex],
                index: _pinnedIndex,
                total: _pinned.length,
                onTap: _tapPinnedBar,
              ),
            ),
          Positioned(
            right: 14,
            bottom: 14,
            child: _JumpToLatest(
              visible: _showJumpToLatest,
              unreadCount: chat.unreadCount,
              onPressed: _scrollToBottom,
            ),
          ),
        ],
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
        quality: GlassTokens.quality(context),
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
          autoAdjustToScreen: true,
          menuWidth: 235,
          menuBorderRadius: 26,
          quality: GlassTokens.heroQuality(context),
          settings: GlassTokens.menu(context),
          menuAlignment: GlassMenuAlignment.bottomRight,
          triggerBuilder: (context, toggleMenu) => GlassIconButton(
            icon: const Icon(TgIcons.more, size: 20),
            size: 42,
            settings: GlassTokens.chrome(context),
            quality: GlassTokens.quality(context),
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
    required this.unreadAnchorId,
    required this.messageKeys,
    required this.highlightedId,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onForward,
    required this.onForwardCopy,
    required this.onReact,
    required this.onTogglePin,
    required this.pinnedIds,
    required this.selected,
    required this.onToggleSelected,
    required this.extraTopPadding,
  });

  final TgChat chat;
  final List<TgMessage> messages;
  final Set<int> settled;
  final ScrollController scrollController;
  final double fontSize;
  final bool isTyping;
  final bool loadingMore;

  /// First message the user had not read when the chat opened, or null.
  final int? unreadAnchorId;

  /// Filled in as rows are built, so the screen can scroll to one by id.
  final Map<int, GlobalKey> messageKeys;

  /// Message to flash, just after a jump.
  final int? highlightedId;
  final ValueChanged<TgMessage> onReply;
  final ValueChanged<TgMessage> onEdit;
  final ValueChanged<TgMessage> onDelete;
  final ValueChanged<TgMessage> onForward;
  final ValueChanged<TgMessage> onForwardCopy;
  final void Function(TgMessage, String) onReact;
  final ValueChanged<TgMessage> onTogglePin;

  /// Ids currently pinned, so the menu can offer Unpin instead of Pin.
  final Set<int> pinnedIds;

  /// Ids picked in selection mode, and the callback that toggles one.
  final Set<int> selected;
  final ValueChanged<TgMessage> onToggleSelected;

  /// Room left at the top for the pinned bar.
  final double extraTopPadding;

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
    final topPad =
        MediaQuery.paddingOf(context).top + 56 + widget.extraTopPadding;

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
          // Leave room for the composer, which floats above the list.
          padding: EdgeInsets.fromLTRB(
            0,
            topPad + 8,
            0,
            76 + MediaQuery.paddingOf(context).bottom,
          ),
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
                  child: Center(child: CupertinoActivityIndicator()),
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

            final key = widget.messageKeys.putIfAbsent(
              message.id,
              GlobalKey.new,
            );

            return Column(
              key: key,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (needsSeparator) _DaySeparator(date: message.date),
                if (message.id == widget.unreadAnchorId)
                  const _UnreadSeparator(),
                _RevealRow(
                  reveal: _reveal,
                  extent: _revealExtent,
                  date: message.date,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: widget.selected.contains(message.id)
                        ? TgColors.accent
                              .resolveFrom(context)
                              .withValues(alpha: 0.22)
                        : widget.highlightedId == message.id
                        ? TgColors.accent
                              .resolveFrom(context)
                              .withValues(alpha: 0.16)
                        : const Color(0x00000000),
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
                        onForwardCopy: widget.onForwardCopy,
                        onReact: widget.onReact,
                        onTogglePin: widget.onTogglePin,
                        isPinned: widget.pinnedIds.contains(message.id),
                        onSelect: widget.onToggleSelected,
                        // While picking, a tap anywhere on the row toggles it
                        // rather than opening whatever it holds.
                        selecting: widget.selected.isNotEmpty,
                      ),
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

/// The "unread messages" rule, as the official clients draw it: a full-width
/// line rather than the day separator's pill, so the two never read alike.
class _UnreadSeparator extends StatelessWidget {
  const _UnreadSeparator();

  @override
  Widget build(BuildContext context) {
    final color = TgColors.accent.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Container(
        height: 26,
        color: color.withValues(alpha: 0.14),
        alignment: Alignment.center,
        child: Text(
          AppL10n.of(context).unreadMessages,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Replaces the composer while messages are picked: how many, and what can be
/// done with them.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onForward,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPad > 0 ? bottomPad : 10),
      child: GlassContainer(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: const LiquidRoundedRectangle(borderRadius: 24),
        settings: GlassTokens.composer(context),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              onPressed: onCancel,
              child: Text(l10n.cancel),
            ),
            Expanded(
              child: Text(
                l10n.selectedCount(count),
                textAlign: TextAlign.center,
                style: TgText.body(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            GlassIconButton(
              icon: const Icon(TgIcons.forwardMessage, size: 20),
              size: 40,
              settings: GlassTokens.composer(context),
              onPressed: onForward,
            ),
            const SizedBox(width: 6),
            GlassIconButton(
              icon: Icon(
                TgIcons.delete,
                size: 20,
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
              size: 40,
              settings: GlassTokens.composer(context),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// The pinned-message bar under the app bar. Tapping it walks through the
/// pinned messages and scrolls to each in turn.
class _PinnedBar extends StatelessWidget {
  const _PinnedBar({
    required this.message,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final TgMessage message;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final accent = TgColors.accent.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassContainer(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const LiquidRoundedRectangle(borderRadius: 18),
          settings: GlassTokens.chrome(context),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 26,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      total > 1
                          ? '\${l10n.pinnedMessage} #\${total - index}'
                          : l10n.pinnedMessage,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    Text(
                      message.text.trim().isEmpty
                          ? l10n.attachment
                          : message.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: TgColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                TgIcons.pinFilled,
                size: 16,
                color: TgColors.tertiaryLabel.resolveFrom(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating "back to the newest message" button, carrying the unread badge.
class _JumpToLatest extends StatelessWidget {
  const _JumpToLatest({
    required this.visible,
    required this.unreadCount,
    required this.onPressed,
  });

  final bool visible;
  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0.7,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: GlassBadge(
            count: unreadCount,
            settings: GlassTokens.chrome(context),
            child: GlassIconButton(
              icon: const Icon(TgIcons.chevronDown, size: 20),
              size: 44,
              settings: GlassTokens.chrome(context),
              quality: GlassTokens.quality(context),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
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
  const _SearchSheet({required this.chatId, required this.onOpen});

  final int chatId;

  /// Closes the sheet and scrolls the thread to the chosen message.
  final ValueChanged<TgMessage> onOpen;

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
          CupertinoSearchTextField(
            controller: _controller,
            placeholder: l10n.searchInChat,
            autofocus: true,
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
                      return CupertinoListTile.notched(
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
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => widget.onOpen(message),
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
                return CupertinoListTile.notched(
                  leading: TgAvatar(
                    seed: chat.id,
                    initials: chat.initials,
                    size: 38,
                    photoPath: chat.photoPath,
                  ),
                  title: Text(chat.title, maxLines: 1),
                  subtitle: Text(chat.presence, maxLines: 1),
                  trailing: const CupertinoListTileChevron(),
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

/// Who is in a group or channel.
class _MembersSheet extends StatelessWidget {
  const _MembersSheet({required this.members});

  final List<TgUser> members;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (members.isEmpty) {
      return Center(
        // A channel the account does not administer will not hand over its
        // member list at all, which is Telegram's rule rather than a failure.
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.membersUnavailable,
            textAlign: TextAlign.center,
            style: TgText.rowPreview(context),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.members,
            textAlign: TextAlign.center,
            style: TgText.rowTitle(context),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return CupertinoListTile.notched(
                  leading: TgAvatar(
                    seed: member.id,
                    initials: member.initials,
                    size: 38,
                    isOnline: member.isOnline,
                  ),
                  title: Text(member.name, maxLines: 1),
                  subtitle: Text(
                    member.username != null
                        ? '@\${member.username}'
                        : (member.lastSeen ?? ''),
                    maxLines: 1,
                  ),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => ChatScreen(chatId: member.id),
                    ),
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
                final photo = photos[index];
                final path = photo.localPath;
                final colors = TgColors.avatarGradient(
                  photo.mediaSeed ?? photo.id,
                );

                return GestureDetector(
                  onTap: path == null
                      ? null
                      : () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => PhotoViewerScreen(
                              path: path,
                              heroTag: 'media-${photo.id}',
                            ),
                          ),
                        ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    // The real photo once TDLib has it; the gradient the
                    // bubble uses as a placeholder until then.
                    child: path != null
                        ? Hero(
                            tag: 'media-${photo.id}',
                            child: AttachmentImage(
                              path: path,
                              fit: BoxFit.cover,
                            ),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: colors,
                              ),
                            ),
                            child: const SizedBox.expand(),
                          ),
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

class _ChatInfoSheet extends StatelessWidget {
  static Future<void> _explainCalls(BuildContext context) {
    final l10n = AppL10n.of(context);
    return GlassDialog.show<void>(
      context: context,
      title: l10n.call,
      message: l10n.callsUnavailable,
      settings: GlassTokens.menu(context),
      actions: [
        GlassDialogAction(
          label: l10n.ok,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  const _ChatInfoSheet({
    required this.chat,
    required this.onMedia,
    required this.onWallpaper,
    required this.onSearch,
    required this.onMembers,
    required this.onLeave,
  });

  final TgChat chat;
  final VoidCallback onMedia;
  final VoidCallback onWallpaper;
  final VoidCallback onSearch;
  final VoidCallback onMembers;
  final VoidCallback onLeave;

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
            quality: GlassTokens.quality(context),
            settings: GlassTokens.chrome(context),
            items: [
              // Calls need tgcalls, a second native stack TDLib does not
              // carry. The buttons stay where Telegram puts them and say so
              // rather than doing nothing.
              GlassButtonGroupItem(
                icon: const Icon(TgIcons.calls),
                label: l10n.call,
                onTap: () => _explainCalls(context),
              ),
              GlassButtonGroupItem(
                icon: const Icon(TgIcons.video),
                label: l10n.video,
                onTap: () => _explainCalls(context),
              ),
              GlassButtonGroupItem(
                icon: const Icon(TgIcons.search),
                label: l10n.search,
                onTap: onSearch,
              ),
            ],
          ),
          const SizedBox(height: 20),
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            header: Text(l10n.info),
            children: [
              CupertinoListTile.notched(
                leading: const Icon(TgIcons.unmute),
                title: Text(l10n.notifications),
                trailing: Text(
                  chat.isMuted ? 'Off' : 'On',
                  style: TgText.rowPreview(context),
                ),
              ),
              CupertinoListTile.notched(
                leading: const Icon(TgIcons.media),
                title: Text(l10n.mediaLinksDocs),
                trailing: const CupertinoListTileChevron(),
                onTap: onMedia,
              ),
              CupertinoListTile.notched(
                leading: const Icon(TgIcons.wallpaper),
                title: Text(l10n.chatWallpaper),
                trailing: const CupertinoListTileChevron(),
                onTap: onWallpaper,
              ),
              if (chat.kind == TgChatKind.group ||
                  chat.kind == TgChatKind.channel)
                CupertinoListTile.notched(
                  leading: const Icon(TgIcons.contacts),
                  title: Text(l10n.members),
                  additionalInfo: chat.memberCount == null
                      ? null
                      : Text('${chat.memberCount}'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: onMembers,
                ),
            ],
          ),
          if (chat.kind == TgChatKind.group ||
              chat.kind == TgChatKind.channel) ...[
            const SizedBox(height: 14),
            CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              children: [
                CupertinoListTile.notched(
                  leading: Icon(
                    TgIcons.logOut,
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                  title: Text(
                    chat.kind == TgChatKind.channel
                        ? l10n.leaveChannel
                        : l10n.leaveGroup,
                    style: TextStyle(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                    ),
                  ),
                  onTap: onLeave,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
