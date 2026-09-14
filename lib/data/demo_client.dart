import 'dart:async';
import 'dart:math';

import 'models.dart';
import 'telegram_client.dart';

/// Offline backend. Generates a believable Telegram account so the UI — and
/// every glass surface in it — can be exercised without API credentials.
///
/// Login accepts any phone number; the confirmation code is `12345`.
class DemoTelegramClient implements TelegramClient {
  DemoTelegramClient({this.autoLogin = false});

  /// Starts already signed in. Used by the web preview build and by the
  /// screenshot script, so a demo can be clicked through without a login step.
  final bool autoLogin;

  static const demoCode = '12345';
  static const demoPassword = 'telegram';

  final _random = Random(7);
  final _authController = StreamController<TgAuthStage>.broadcast();
  final _chatsController = StreamController<List<TgChat>>.broadcast();
  final _typingController = StreamController<int?>.broadcast();
  final _messageControllers = <int, StreamController<List<TgMessage>>>{};
  final _messages = <int, List<TgMessage>>{};

  /// Every pending delivery/typing/upload timer, so [dispose] can cancel them
  /// instead of leaving them to fire against a closed controller.
  final _timers = <Timer>{};

  List<TgChat> _chats = const [];
  TgAuthStage _stage = TgAuthStage.splash;
  TgUser? _me;
  Timer? _ambientTimer;
  int _nextMessageId = 10000;
  bool _passwordRequired = false;

  @override
  String get backendName => 'Demo';

  @override
  bool get isLive => false;

  @override
  String? get authorizationState => null;

  @override
  String? get connectionState => null;

  @override
  bool get isReadyForPhone => true;

  @override
  TgAuthStage get currentStage => _stage;

  @override
  TgUser? get me => _me;

  @override
  Stream<TgAuthStage> get authStage => _authController.stream;

  @override
  Stream<List<TgChat>> get chats => _chatsController.stream;

  @override
  List<TgChat> get currentChats => _chats;

  @override
  Stream<int?> get typingChatId => _typingController.stream;

  @override
  Future<void> start() async {
    _seed();
    if (autoLogin) {
      _completeLogin();
      return;
    }
    _setStage(TgAuthStage.phone);
  }

  /// Schedules [action] and forgets the timer once it has fired.
  Timer _schedule(Duration delay, void Function() action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      action();
    });
    _timers.add(timer);
    return timer;
  }

  @override
  Future<void> dispose() async {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _ambientTimer?.cancel();
    await _authController.close();
    await _chatsController.close();
    await _typingController.close();
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
  }

  // ── Authorization ─────────────────────────────────────────────────────────

  @override
  Future<TgAuthResult> submitPhone(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      return const TgAuthResult(
        stage: TgAuthStage.phone,
        error: 'Enter a valid phone number',
      );
    }
    // A number ending in 0 exercises the two-factor branch of the flow.
    _passwordRequired = digits.endsWith('0');
    _setStage(TgAuthStage.code);
    return const TgAuthResult(stage: TgAuthStage.code);
  }

  @override
  Future<TgAuthResult> submitCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (code.trim() != demoCode) {
      return const TgAuthResult(
        stage: TgAuthStage.code,
        error: 'Invalid code — use $demoCode in demo mode',
      );
    }
    if (_passwordRequired) {
      _setStage(TgAuthStage.password);
      return const TgAuthResult(stage: TgAuthStage.password);
    }
    _completeLogin();
    return const TgAuthResult(stage: TgAuthStage.ready);
  }

  @override
  Future<TgAuthResult> submitPassword(String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (password != demoPassword) {
      return const TgAuthResult(
        stage: TgAuthStage.password,
        error: 'Wrong password — use "$demoPassword" in demo mode',
      );
    }
    _completeLogin();
    return const TgAuthResult(stage: TgAuthStage.ready);
  }

  void _completeLogin() {
    _me = const TgUser(
      id: 1,
      name: 'Artem Silinskiy',
      username: 'temasil',
      phone: '+7 900 000-00-00',
      bio: 'Building things with glass.',
      isOnline: true,
      isPremium: true,
    );
    _setStage(TgAuthStage.ready);
    _chatsController.add(_chats);
    _startAmbientTraffic();
  }

  @override
  Future<void> logOut() async {
    _ambientTimer?.cancel();
    _me = null;
    _passwordRequired = false;
    _setStage(TgAuthStage.phone);
  }

  void _setStage(TgAuthStage stage) {
    _stage = stage;
    _authController.add(stage);
  }

  // ── Chats & messages ──────────────────────────────────────────────────────

  @override
  List<TgFolder> get folders => const [
    TgFolder(id: 'all', title: 'All Chats', unreadCount: 12),
    TgFolder(id: 'personal', title: 'Personal', unreadCount: 3),
    TgFolder(id: 'groups', title: 'Groups', unreadCount: 6),
    TgFolder(id: 'channels', title: 'Channels', unreadCount: 3),
    TgFolder(id: 'unread', title: 'Unread'),
    TgFolder(id: 'bots', title: 'Bots'),
  ];

  @override
  List<TgStory> get stories => const [
    TgStory(id: 1, authorId: 1, authorName: 'My Story', seed: 1, isSeen: true),
    TgStory(
      id: 2,
      authorId: 2,
      authorName: 'Nina',
      seed: 2,
      caption: 'Morning run',
    ),
    TgStory(id: 3, authorId: 3, authorName: 'Pavel', seed: 3),
    TgStory(id: 4, authorId: 5, authorName: 'Design', seed: 4),
    TgStory(id: 5, authorId: 7, authorName: 'Marta', seed: 5, isSeen: true),
    TgStory(id: 6, authorId: 9, authorName: 'Ilya', seed: 6),
  ];

  @override
  List<TgUser> get contacts => const [
    TgUser(
      id: 2,
      name: 'Nina Kovalenko',
      username: 'ninak',
      phone: '+7 911 222-33-44',
      isOnline: true,
    ),
    TgUser(
      id: 3,
      name: 'Pavel Durov',
      username: 'durov',
      phone: '+7 911 555-66-77',
      isVerified: true,
    ),
    TgUser(
      id: 4,
      name: 'Sergey Ivanov',
      username: 'sergey',
      phone: '+7 903 111-22-33',
      lastSeen: 'last seen 2 hours ago',
    ),
    TgUser(
      id: 7,
      name: 'Marta Lis',
      username: 'martalis',
      phone: '+48 500 100 200',
      isOnline: true,
    ),
    TgUser(
      id: 9,
      name: 'Ilya Petrov',
      username: 'ilyap',
      phone: '+7 921 777-88-99',
      lastSeen: 'last seen yesterday',
    ),
    TgUser(
      id: 11,
      name: 'Katya Orlova',
      username: 'katya',
      phone: '+7 999 123-45-67',
      lastSeen: 'last seen recently',
    ),
  ];

  @override
  List<TgCall> get calls => [
    TgCall(
      id: 1,
      peerName: 'Nina Kovalenko',
      peerId: 2,
      date: _ago(const Duration(hours: 2)),
      isOutgoing: false,
      isVideo: true,
      duration: const Duration(minutes: 24),
    ),
    TgCall(
      id: 2,
      peerName: 'Marta Lis',
      peerId: 7,
      date: _ago(const Duration(hours: 8)),
      isOutgoing: true,
      isVideo: false,
      duration: const Duration(minutes: 3, seconds: 12),
    ),
    TgCall(
      id: 3,
      peerName: 'Sergey Ivanov',
      peerId: 4,
      date: _ago(const Duration(days: 1)),
      isOutgoing: false,
      isVideo: false,
      isMissed: true,
    ),
    TgCall(
      id: 4,
      peerName: 'Ilya Petrov',
      peerId: 9,
      date: _ago(const Duration(days: 2)),
      isOutgoing: true,
      isVideo: true,
      duration: const Duration(minutes: 47),
    ),
    TgCall(
      id: 5,
      peerName: 'Katya Orlova',
      peerId: 11,
      date: _ago(const Duration(days: 3)),
      isOutgoing: true,
      isVideo: false,
      isMissed: true,
    ),
  ];

  @override
  Stream<List<TgMessage>> messagesOf(int chatId) =>
      _controllerFor(chatId).stream;

  @override
  List<TgMessage> currentMessagesOf(int chatId) =>
      List.unmodifiable(_messages[chatId] ?? const []);

  @override
  Future<void> openChat(int chatId) async {
    _controllerFor(chatId).add(currentMessagesOf(chatId));
  }

  @override
  Future<void> closeChat(int chatId) async {}

  @override
  Future<void> loadMoreMessages(int chatId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final existing = _messages[chatId];
    if (existing == null || existing.isEmpty) return;
    final oldest = existing.first;
    final older = List.generate(6, (i) {
      return TgMessage(
        id: _nextMessageId++,
        chatId: chatId,
        text: _historyLines[(chatId + i) % _historyLines.length],
        date: oldest.date.subtract(Duration(minutes: 12 * (6 - i))),
        isOutgoing: i.isEven,
        status: TgMessageStatus.read,
      );
    });
    _messages[chatId] = [...older, ...existing];
    _controllerFor(chatId).add(currentMessagesOf(chatId));
  }

  @override
  Future<void> sendText(int chatId, String text, {TgMessage? replyTo}) async {
    final message = TgMessage(
      id: _nextMessageId++,
      chatId: chatId,
      text: text,
      date: DateTime.now(),
      isOutgoing: true,
      status: TgMessageStatus.sending,
      replyToText: replyTo?.text,
      replyToSender: replyTo == null
          ? null
          : (replyTo.isOutgoing
                ? 'You'
                : (replyTo.senderName ?? _titleOf(chatId))),
    );
    _append(chatId, message);
    _advanceStatus(chatId, message.id);
    _maybeReply(chatId);
  }

  @override
  Future<void> sendPhoto(int chatId, {String? path, String? caption}) async {
    final message = TgMessage(
      id: _nextMessageId++,
      chatId: chatId,
      text: caption ?? '',
      date: DateTime.now(),
      isOutgoing: true,
      kind: TgMessageKind.photo,
      status: TgMessageStatus.sending,
      mediaSeed: _random.nextInt(1 << 20),
      uploadProgress: 0,
      localPath: path,
    );
    _append(chatId, message);
    _simulateUpload(chatId, message.id);
  }

  @override
  Future<void> sendVoice(int chatId, int seconds) async {
    final message = TgMessage(
      id: _nextMessageId++,
      chatId: chatId,
      text: '',
      date: DateTime.now(),
      isOutgoing: true,
      kind: TgMessageKind.voice,
      status: TgMessageStatus.sending,
      voiceSeconds: seconds,
    );
    _append(chatId, message);
    _advanceStatus(chatId, message.id);
  }

  @override
  Future<void> sendFile(
    int chatId,
    String name,
    String size, {
    String? path,
  }) async {
    final message = TgMessage(
      id: _nextMessageId++,
      chatId: chatId,
      text: '',
      date: DateTime.now(),
      isOutgoing: true,
      kind: TgMessageKind.file,
      status: TgMessageStatus.sending,
      fileName: name,
      fileSize: size,
      uploadProgress: 0,
      localPath: path,
    );
    _append(chatId, message);
    _simulateUpload(chatId, message.id);
  }

  @override
  Future<void> deleteMessage(int chatId, int messageId) async {
    final list = _messages[chatId];
    if (list == null) return;
    list.removeWhere((m) => m.id == messageId);
    _controllerFor(chatId).add(currentMessagesOf(chatId));
    _syncPreview(chatId);
  }

  @override
  Future<void> editMessage(int chatId, int messageId, String text) async {
    _mutate(chatId, messageId, (m) => m.copyWith(text: text, isEdited: true));
    _syncPreview(chatId);
  }

  @override
  Future<void> toggleReaction(int chatId, int messageId, String emoji) async {
    _mutate(chatId, messageId, (m) {
      final reactions = [...m.reactions];
      final index = reactions.indexWhere((r) => r.emoji == emoji);
      if (index == -1) {
        reactions.add(TgReaction(emoji: emoji, count: 1, chosen: true));
      } else {
        final toggled = reactions[index].toggled();
        if (toggled.count <= 0) {
          reactions.removeAt(index);
        } else {
          reactions[index] = toggled;
        }
      }
      return m.copyWith(reactions: reactions);
    });
  }

  @override
  Future<void> markChatRead(int chatId) async {
    _updateChat(chatId, (chat) => chat.copyWith(unreadCount: 0));
  }

  @override
  Future<void> deleteChat(int chatId) async {
    _chats = _chats.where((chat) => chat.id != chatId).toList();
    _messages.remove(chatId);
    _chatsController.add(_chats);
  }

  @override
  Future<void> setDraft(int chatId, String text) async {
    _updateChat(chatId, (chat) => chat.copyWith(draft: text));
  }

  @override
  List<TgMessage> searchMessages(int chatId, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return (_messages[chatId] ?? const <TgMessage>[])
        .where((message) => message.text.toLowerCase().contains(needle))
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<void> toggleMute(int chatId) async {
    _updateChat(chatId, (chat) => chat.copyWith(isMuted: !chat.isMuted));
  }

  @override
  Future<void> togglePin(int chatId) async {
    _updateChat(chatId, (chat) => chat.copyWith(isPinned: !chat.isPinned));
    _sortChats();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  StreamController<List<TgMessage>> _controllerFor(int chatId) {
    return _messageControllers.putIfAbsent(
      chatId,
      () => StreamController<List<TgMessage>>.broadcast(),
    );
  }

  void _append(int chatId, TgMessage message) {
    _messages.putIfAbsent(chatId, () => []).add(message);
    _controllerFor(chatId).add(currentMessagesOf(chatId));
    _syncPreview(chatId);
  }

  void _mutate(
    int chatId,
    int messageId,
    TgMessage Function(TgMessage) update,
  ) {
    final list = _messages[chatId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    list[index] = update(list[index]);
    _controllerFor(chatId).add(currentMessagesOf(chatId));
  }

  /// Walks a just-sent message through sending → sent → delivered → read,
  /// which is what makes the tick animation in the bubble feel alive.
  void _advanceStatus(int chatId, int messageId) {
    _schedule(const Duration(milliseconds: 420), () {
      _mutate(
        chatId,
        messageId,
        (m) => m.copyWith(status: TgMessageStatus.sent),
      );
    });
    _schedule(const Duration(milliseconds: 1100), () {
      _mutate(
        chatId,
        messageId,
        (m) => m.copyWith(status: TgMessageStatus.delivered),
      );
    });
    _schedule(const Duration(milliseconds: 2400), () {
      _mutate(
        chatId,
        messageId,
        (m) => m.copyWith(status: TgMessageStatus.read),
      );
    });
  }

  void _simulateUpload(int chatId, int messageId) {
    var progress = 0.0;
    late final Timer ticker;
    ticker = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      progress += 0.12 + _random.nextDouble() * 0.1;
      if (progress >= 1) {
        timer.cancel();
        _timers.remove(ticker);
        _mutate(
          chatId,
          messageId,
          (m) => m.copyWith(uploadProgress: null, status: TgMessageStatus.sent),
        );
        _advanceStatus(chatId, messageId);
      } else {
        _mutate(chatId, messageId, (m) => m.copyWith(uploadProgress: progress));
      }
    });
    _timers.add(ticker);
  }

  /// A short typing indicator followed by a canned reply, so an open
  /// conversation keeps moving while the user looks at it.
  void _maybeReply(int chatId) {
    final chat = _chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => _chats.first,
    );
    if (chat.kind == TgChatKind.saved || chat.kind == TgChatKind.channel) {
      return;
    }
    if (_random.nextDouble() > 0.75) return;

    _schedule(const Duration(milliseconds: 900), () {
      _typingController.add(chatId);
      _schedule(Duration(milliseconds: 1400 + _random.nextInt(1200)), () {
        _typingController.add(null);
        _append(
          chatId,
          TgMessage(
            id: _nextMessageId++,
            chatId: chatId,
            text: _replyLines[_random.nextInt(_replyLines.length)],
            date: DateTime.now(),
            isOutgoing: false,
            senderName: chat.kind == TgChatKind.group
                ? _groupSenders[_random.nextInt(_groupSenders.length)]
                : null,
          ),
        );
      });
    });
  }

  /// Background chatter in chats the user is not looking at — unread badges
  /// move on their own, which is what the glass badges are there to show.
  void _startAmbientTraffic() {
    _ambientTimer?.cancel();
    _ambientTimer = Timer.periodic(const Duration(seconds: 11), (_) {
      if (_chats.isEmpty) return;
      final chat = _chats[_random.nextInt(_chats.length)];
      if (chat.kind == TgChatKind.saved) return;
      _append(
        chat.id,
        TgMessage(
          id: _nextMessageId++,
          chatId: chat.id,
          text: _ambientLines[_random.nextInt(_ambientLines.length)],
          date: DateTime.now(),
          isOutgoing: false,
          senderName: chat.kind == TgChatKind.private
              ? null
              : _groupSenders[_random.nextInt(_groupSenders.length)],
        ),
      );
      _updateChat(chat.id, (c) => c.copyWith(unreadCount: c.unreadCount + 1));
    });
  }

  void _syncPreview(int chatId) {
    final list = _messages[chatId];
    if (list == null || list.isEmpty) return;
    final last = list.last;
    _updateChat(chatId, (chat) {
      return chat.copyWith(
        lastMessage: _previewOf(last),
        lastMessageTime: last.date,
        lastMessageOutgoing: last.isOutgoing,
        lastMessageStatus: last.status,
      );
    });
    _sortChats();
  }

  String _previewOf(TgMessage message) {
    switch (message.kind) {
      case TgMessageKind.photo:
        return message.text.isEmpty ? '📷 Photo' : '📷 ${message.text}';
      case TgMessageKind.voice:
        return '🎤 Voice message';
      case TgMessageKind.file:
        return '📎 ${message.fileName ?? 'File'}';
      case TgMessageKind.sticker:
        return '🎨 Sticker';
      case TgMessageKind.service:
      case TgMessageKind.text:
        return message.text;
    }
  }

  void _updateChat(int chatId, TgChat Function(TgChat) update) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index == -1) return;
    final next = [..._chats];
    next[index] = update(next[index]);
    _chats = next;
    _chatsController.add(_chats);
  }

  void _sortChats() {
    final next = [..._chats];
    next.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final at = a.lastMessageTime ?? DateTime(1970);
      final bt = b.lastMessageTime ?? DateTime(1970);
      return bt.compareTo(at);
    });
    _chats = next;
    _chatsController.add(_chats);
  }

  String _titleOf(int chatId) => _chats
      .firstWhere((c) => c.id == chatId, orElse: () => _chats.first)
      .title;

  static DateTime _ago(Duration d) => DateTime.now().subtract(d);

  void _seed() {
    _chats = [
      TgChat(
        id: 2,
        title: 'Nina Kovalenko',
        kind: TgChatKind.private,
        lastMessage: 'Sent you the mockups, take a look 👀',
        lastMessageTime: _ago(const Duration(minutes: 4)),
        unreadCount: 2,
        isOnline: true,
        isPinned: true,
        hasStory: true,
      ),
      TgChat(
        id: 100,
        title: 'Design Team',
        kind: TgChatKind.group,
        lastMessage: 'Pavel: the glass blur is finally right',
        lastMessageTime: _ago(const Duration(minutes: 12)),
        unreadCount: 6,
        memberCount: 18,
        isPinned: true,
      ),
      TgChat(
        id: 1,
        title: 'Saved Messages',
        kind: TgChatKind.saved,
        lastMessage: 'Shader reference links',
        lastMessageTime: _ago(const Duration(minutes: 40)),
      ),
      TgChat(
        id: 3,
        title: 'Pavel Durov',
        kind: TgChatKind.private,
        lastMessage: 'Deal. Ship it on Friday.',
        lastMessageTime: _ago(const Duration(hours: 1, minutes: 5)),
        lastMessageOutgoing: false,
        isVerified: true,
        hasStory: true,
      ),
      TgChat(
        id: 200,
        title: 'Telegram Tips',
        kind: TgChatKind.channel,
        lastMessage: 'Five gestures you did not know about',
        lastMessageTime: _ago(const Duration(hours: 2)),
        unreadCount: 3,
        memberCount: 1240000,
        isVerified: true,
        isMuted: true,
      ),
      TgChat(
        id: 7,
        title: 'Marta Lis',
        kind: TgChatKind.private,
        lastMessage: 'Perfect, see you at 8 🙌',
        lastMessageTime: _ago(const Duration(hours: 3)),
        lastMessageOutgoing: true,
        lastMessageStatus: TgMessageStatus.read,
        isOnline: true,
      ),
      TgChat(
        id: 101,
        title: 'Flutter Devs 🇺🇦',
        kind: TgChatKind.group,
        lastMessage: 'Ilya: Impeller shaders on Android are solid now',
        lastMessageTime: _ago(const Duration(hours: 5)),
        memberCount: 4820,
        isMuted: true,
      ),
      TgChat(
        id: 500,
        title: 'GlassBot',
        kind: TgChatKind.bot,
        lastMessage: 'Type /render to preview a shader',
        lastMessageTime: _ago(const Duration(hours: 9)),
        subtitle: 'bot',
      ),
      TgChat(
        id: 4,
        title: 'Sergey Ivanov',
        kind: TgChatKind.private,
        lastMessage: 'Ok, I will send the invoice tomorrow',
        lastMessageTime: _ago(const Duration(days: 1, hours: 2)),
        subtitle: 'last seen 2 hours ago',
      ),
      TgChat(
        id: 9,
        title: 'Ilya Petrov',
        kind: TgChatKind.private,
        lastMessage: 'Voice message',
        lastMessageTime: _ago(const Duration(days: 2)),
        subtitle: 'last seen yesterday',
        hasStory: true,
      ),
      TgChat(
        id: 201,
        title: 'Design Weekly',
        kind: TgChatKind.channel,
        lastMessage: 'Issue #42 — Liquid Glass in the wild',
        lastMessageTime: _ago(const Duration(days: 3)),
        memberCount: 86400,
      ),
      TgChat(
        id: 11,
        title: 'Katya Orlova',
        kind: TgChatKind.private,
        lastMessage: 'Happy birthday! 🎂',
        lastMessageTime: _ago(const Duration(days: 4)),
        lastMessageOutgoing: true,
        subtitle: 'last seen recently',
      ),
    ];

    _messages[2] = _thread(2, const [
      _Line(false, 'Hey! Did you get a chance to look at the new glass spec?'),
      _Line(true, 'Yes — the refraction on the tab bar is exactly right now'),
      _Line(false, 'The specular highlight was the hard part'),
      _Line(true, 'Agreed. Bumping thickness to 18 fixed the flat look'),
      _Line(false, 'Sent you the mockups, take a look 👀'),
    ]);
    _messages[2]!.insert(
      3,
      TgMessage(
        id: _nextMessageId++,
        chatId: 2,
        text: 'Reference shot from the iOS 26 build',
        date: _ago(const Duration(minutes: 18)),
        isOutgoing: false,
        kind: TgMessageKind.photo,
        mediaSeed: 42,
        reactions: const [TgReaction(emoji: '🔥', count: 2, chosen: true)],
      ),
    );

    _messages[100] = _thread(100, const [
      _Line(false, 'Standup in 10 minutes', sender: 'Pavel'),
      _Line(false, 'I pushed the shader warm-up fix', sender: 'Nina'),
      _Line(true, 'Nice — frame 1 was the last blocker'),
      _Line(false, 'the glass blur is finally right', sender: 'Pavel'),
    ]);

    _messages[1] = _thread(1, const [
      _Line(true, 'Shader reference links'),
      _Line(true, 'https://developer.apple.com/design/'),
    ]);

    _messages[3] = _thread(3, const [
      _Line(true, 'Ready for the Friday release?'),
      _Line(false, 'Deal. Ship it on Friday.'),
    ]);

    _messages[7] = _thread(7, const [
      _Line(false, 'Dinner at 8?'),
      _Line(true, 'Perfect, see you at 8 🙌'),
    ]);

    _messages[500] = _thread(500, const [
      _Line(false, 'Welcome to GlassBot 🫧'),
      _Line(false, 'Type /render to preview a shader'),
    ]);

    for (final chat in _chats) {
      _messages.putIfAbsent(
        chat.id,
        () => _thread(chat.id, [_Line(false, chat.lastMessage ?? 'Hello!')]),
      );
    }
  }

  List<TgMessage> _thread(int chatId, List<_Line> lines) {
    final base = DateTime.now().subtract(Duration(minutes: 8 * lines.length));
    return [
      for (var i = 0; i < lines.length; i++)
        TgMessage(
          id: _nextMessageId++,
          chatId: chatId,
          text: lines[i].text,
          date: base.add(Duration(minutes: 8 * i)),
          isOutgoing: lines[i].outgoing,
          senderName: lines[i].sender,
          status: TgMessageStatus.read,
        ),
    ];
  }

  static const _replyLines = [
    'Got it 👍',
    'Makes sense, let me check',
    'Sending it over in a minute',
    'Nice one!',
    'I will take a look tonight',
    'Agreed 🙂',
  ];

  static const _ambientLines = [
    'Quick question about the build',
    'Did anyone see the new release notes?',
    'Pushed a fix, please review',
    'Meeting moved to 16:00',
    'Looks great on device 🔥',
  ];

  static const _historyLines = [
    'That was the plan from the start',
    'Let me pull up the old thread',
    'We tried that last sprint',
    'Numbers looked fine back then',
    'Reposting the link here',
    'Same conclusion as before',
  ];

  static const _groupSenders = ['Pavel', 'Nina', 'Ilya', 'Marta', 'Sergey'];
}

class _Line {
  const _Line(this.outgoing, this.text, {this.sender});
  final bool outgoing;
  final String text;
  final String? sender;
}
