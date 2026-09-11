import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../models.dart';
import '../telegram_client.dart';
import 'tdlib_ffi.dart';

/// Live backend speaking the official TDLib JSON protocol.
///
/// Protocol reference: https://core.telegram.org/tdlib/getting-started
///
/// `td_receive` blocks the calling thread, so the receive loop lives in its own
/// isolate and forwards raw JSON back over a port. TDLib client ids are
/// process-global, which is what makes sending from the main isolate and
/// receiving from the worker isolate safe.
class TdlibTelegramClient implements TelegramClient {
  TdlibTelegramClient({
    required this.apiId,
    required this.apiHash,
    required this.databaseDirectory,
    required this.filesDirectory,
    this.systemLanguageCode = 'en',
    this.deviceModel = 'Android',
    this.applicationVersion = '1.0.0',
  });

  final int apiId;
  final String apiHash;
  final String databaseDirectory;
  final String filesDirectory;
  final String systemLanguageCode;
  final String deviceModel;
  final String applicationVersion;

  final _authController = StreamController<TgAuthStage>.broadcast();
  final _chatsController = StreamController<List<TgChat>>.broadcast();
  final _typingController = StreamController<int?>.broadcast();
  final _messageControllers = <int, StreamController<List<TgMessage>>>{};
  final _messages = <int, List<TgMessage>>{};
  final _chatIndex = <int, TgChat>{};
  final _pending = <int, Completer<Map<String, dynamic>>>{};

  TdJsonBindings? _bindings;
  Isolate? _receiveIsolate;
  ReceivePort? _receivePort;
  int _clientId = 0;
  int _queryId = 1;
  TgAuthStage _stage = TgAuthStage.splash;
  TgUser? _me;

  /// True when the native library was found and the client is usable.
  bool get isAvailable => _bindings != null;

  @override
  String get backendName => 'TDLib';

  @override
  bool get isLive => true;

  @override
  TgAuthStage get currentStage => _stage;

  @override
  TgUser? get me => _me;

  @override
  Stream<TgAuthStage> get authStage => _authController.stream;

  @override
  Stream<List<TgChat>> get chats => _chatsController.stream;

  @override
  List<TgChat> get currentChats {
    final list = _chatIndex.values.toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final at = a.lastMessageTime ?? DateTime(1970);
        final bt = b.lastMessageTime ?? DateTime(1970);
        return bt.compareTo(at);
      });
    return list;
  }

  @override
  Stream<int?> get typingChatId => _typingController.stream;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> start() async {
    final bindings = TdJsonBindings.open();
    if (bindings == null) {
      throw StateError(
        'libtdjson was not found. Drop the TDLib shared libraries into '
        'android/app/src/main/jniLibs/<abi>/ or run in demo mode.',
      );
    }
    _bindings = bindings;
    bindings.execute(jsonEncode({
      '@type': 'setLogVerbosityLevel',
      'new_verbosity_level': 1,
    }));
    _clientId = bindings.createClientId();

    final port = ReceivePort();
    _receivePort = port;
    port.listen(_onRaw);
    _receiveIsolate = await Isolate.spawn(
      _receiveLoop,
      _ReceiveConfig(port.sendPort, _clientId),
      debugName: 'tdlib-receive',
    );

    // The first request is what makes TDLib emit its authorization state.
    _send({'@type': 'getOption', 'name': 'version'});
  }

  @override
  Future<void> dispose() async {
    _receiveIsolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    await _authController.close();
    await _chatsController.close();
    await _typingController.close();
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
  }

  static void _receiveLoop(_ReceiveConfig config) {
    final bindings = TdJsonBindings.open();
    if (bindings == null) return;
    while (true) {
      final event = bindings.receive(1.0);
      if (event != null) config.port.send(event);
    }
  }

  // ── Outgoing ──────────────────────────────────────────────────────────────

  void _send(Map<String, dynamic> request) {
    _bindings?.send(_clientId, jsonEncode(request));
  }

  /// Sends a request and completes when TDLib answers with the matching
  /// `@extra` token.
  Future<Map<String, dynamic>> _request(Map<String, dynamic> request) {
    final id = _queryId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _send({...request, '@extra': id});
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(id);
        return {'@type': 'error', 'message': 'timeout'};
      },
    );
  }

  // ── Incoming ──────────────────────────────────────────────────────────────

  void _onRaw(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> update;
    try {
      update = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return;
    }

    final extra = update['@extra'];
    if (extra is int) {
      _pending.remove(extra)?.complete(update);
    }

    switch (update['@type'] as String?) {
      case 'updateAuthorizationState':
        _onAuthorizationState(
            update['authorization_state'] as Map<String, dynamic>);
      case 'updateNewChat':
        _onChat(update['chat'] as Map<String, dynamic>);
      case 'updateChatLastMessage':
        _onChatLastMessage(update);
      case 'updateChatReadInbox':
        _onReadInbox(update);
      case 'updateNewMessage':
        _onNewMessage(update['message'] as Map<String, dynamic>);
      case 'updateUserChatAction':
        _onChatAction(update);
      case 'updateUser':
        _onUser(update['user'] as Map<String, dynamic>);
    }
  }

  void _onAuthorizationState(Map<String, dynamic> state) {
    switch (state['@type'] as String?) {
      case 'authorizationStateWaitTdlibParameters':
        _send({
          '@type': 'setTdlibParameters',
          'database_directory': databaseDirectory,
          'files_directory': filesDirectory,
          'use_message_database': true,
          'use_secret_chats': false,
          'api_id': apiId,
          'api_hash': apiHash,
          'system_language_code': systemLanguageCode,
          'device_model': deviceModel,
          'application_version': applicationVersion,
        });
      case 'authorizationStateWaitPhoneNumber':
        _setStage(TgAuthStage.phone);
      case 'authorizationStateWaitCode':
        _setStage(TgAuthStage.code);
      case 'authorizationStateWaitPassword':
        _setStage(TgAuthStage.password);
      case 'authorizationStateReady':
        _setStage(TgAuthStage.ready);
        _loadMe();
        _send({'@type': 'loadChats', 'limit': 40});
      case 'authorizationStateClosed':
        _setStage(TgAuthStage.phone);
    }
  }

  void _setStage(TgAuthStage stage) {
    _stage = stage;
    _authController.add(stage);
  }

  Future<void> _loadMe() async {
    final response = await _request({'@type': 'getMe'});
    if (response['@type'] != 'user') return;
    _me = _userFrom(response);
  }

  TgUser _userFrom(Map<String, dynamic> json) {
    final first = (json['first_name'] as String?) ?? '';
    final last = (json['last_name'] as String?) ?? '';
    final usernames = json['usernames'] as Map<String, dynamic>?;
    final active = (usernames?['active_usernames'] as List?)?.cast<String>();
    return TgUser(
      id: (json['id'] as num).toInt(),
      name: '$first $last'.trim().isEmpty ? 'Unknown' : '$first $last'.trim(),
      username: active != null && active.isNotEmpty ? active.first : null,
      phone: json['phone_number'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
      isPremium: (json['is_premium'] as bool?) ?? false,
      isOnline: (json['status'] as Map<String, dynamic>?)?['@type'] ==
          'userStatusOnline',
    );
  }

  void _onUser(Map<String, dynamic> json) {
    final user = _userFrom(json);
    final chat = _chatIndex[user.id];
    if (chat == null) return;
    _chatIndex[user.id] = chat.copyWith();
    _chatsController.add(currentChats);
  }

  void _onChat(Map<String, dynamic> json) {
    final id = (json['id'] as num).toInt();
    final type = (json['type'] as Map<String, dynamic>?)?['@type'] as String?;
    final positions = json['positions'] as List?;
    final pinned = positions != null &&
        positions.any((p) => (p as Map)['is_pinned'] == true);

    _chatIndex[id] = TgChat(
      id: id,
      title: (json['title'] as String?) ?? 'Chat',
      kind: _kindFrom(type),
      unreadCount: ((json['unread_count'] as num?) ?? 0).toInt(),
      isPinned: pinned,
      isMuted: _isMuted(json),
      lastMessage: _previewOf(json['last_message'] as Map<String, dynamic>?),
      lastMessageTime: _dateOf(json['last_message'] as Map<String, dynamic>?),
      lastMessageOutgoing:
          (json['last_message'] as Map<String, dynamic>?)?['is_outgoing'] ==
              true,
    );
    _chatsController.add(currentChats);
  }

  static bool _isMuted(Map<String, dynamic> chat) {
    final settings = chat['notification_settings'] as Map<String, dynamic>?;
    final muteFor = (settings?['mute_for'] as num?)?.toInt() ?? 0;
    return muteFor > 0;
  }

  static TgChatKind _kindFrom(String? type) {
    switch (type) {
      case 'chatTypeBasicGroup':
        return TgChatKind.group;
      case 'chatTypeSupergroup':
        return TgChatKind.group;
      case 'chatTypeSecret':
        return TgChatKind.private;
      default:
        return TgChatKind.private;
    }
  }

  void _onChatLastMessage(Map<String, dynamic> update) {
    final id = (update['chat_id'] as num).toInt();
    final chat = _chatIndex[id];
    if (chat == null) return;
    final last = update['last_message'] as Map<String, dynamic>?;
    _chatIndex[id] = chat.copyWith(
      lastMessage: _previewOf(last),
      lastMessageTime: _dateOf(last),
      lastMessageOutgoing: last?['is_outgoing'] == true,
    );
    _chatsController.add(currentChats);
  }

  void _onReadInbox(Map<String, dynamic> update) {
    final id = (update['chat_id'] as num).toInt();
    final chat = _chatIndex[id];
    if (chat == null) return;
    _chatIndex[id] = chat.copyWith(
      unreadCount: ((update['unread_count'] as num?) ?? 0).toInt(),
    );
    _chatsController.add(currentChats);
  }

  void _onChatAction(Map<String, dynamic> update) {
    final action =
        (update['action'] as Map<String, dynamic>?)?['@type'] as String?;
    final chatId = (update['chat_id'] as num?)?.toInt();
    if (action == 'chatActionTyping') {
      _typingController.add(chatId);
    } else if (action == 'chatActionCancel') {
      _typingController.add(null);
    }
  }

  void _onNewMessage(Map<String, dynamic> json) {
    final message = _messageFrom(json);
    _messages.putIfAbsent(message.chatId, () => []).add(message);
    _controllerFor(message.chatId).add(currentMessagesOf(message.chatId));
  }

  TgMessage _messageFrom(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>?;
    final type = content?['@type'] as String?;
    final sender = json['sender_id'] as Map<String, dynamic>?;
    return TgMessage(
      id: (json['id'] as num).toInt(),
      chatId: (json['chat_id'] as num).toInt(),
      text: _textOf(content),
      date: DateTime.fromMillisecondsSinceEpoch(
          ((json['date'] as num?) ?? 0).toInt() * 1000),
      isOutgoing: (json['is_outgoing'] as bool?) ?? false,
      kind: _messageKindFrom(type),
      status: TgMessageStatus.read,
      senderId: (sender?['user_id'] as num?)?.toInt(),
      isEdited: ((json['edit_date'] as num?) ?? 0) > 0,
      reactions: _reactionsFrom(json['interaction_info']),
    );
  }

  static List<TgReaction> _reactionsFrom(dynamic interactionInfo) {
    final reactions = (interactionInfo as Map<String, dynamic>?)?['reactions'];
    final list = (reactions as Map<String, dynamic>?)?['reactions'] as List?;
    if (list == null) return const [];
    return [
      for (final entry in list.cast<Map<String, dynamic>>())
        TgReaction(
          emoji: (entry['type'] as Map<String, dynamic>?)?['emoji'] as String? ??
              '👍',
          count: ((entry['total_count'] as num?) ?? 0).toInt(),
          chosen: (entry['is_chosen'] as bool?) ?? false,
        ),
    ];
  }

  static TgMessageKind _messageKindFrom(String? type) {
    switch (type) {
      case 'messagePhoto':
        return TgMessageKind.photo;
      case 'messageVoiceNote':
        return TgMessageKind.voice;
      case 'messageDocument':
        return TgMessageKind.file;
      case 'messageSticker':
        return TgMessageKind.sticker;
      case 'messageText':
        return TgMessageKind.text;
      default:
        return TgMessageKind.service;
    }
  }

  static String _textOf(Map<String, dynamic>? content) {
    final text = content?['text'] as Map<String, dynamic>?;
    if (text != null) return (text['text'] as String?) ?? '';
    final caption = content?['caption'] as Map<String, dynamic>?;
    return (caption?['text'] as String?) ?? '';
  }

  static String? _previewOf(Map<String, dynamic>? message) {
    if (message == null) return null;
    final content = message['content'] as Map<String, dynamic>?;
    final text = _textOf(content);
    if (text.isNotEmpty) return text;
    switch (content?['@type'] as String?) {
      case 'messagePhoto':
        return '📷 Photo';
      case 'messageVoiceNote':
        return '🎤 Voice message';
      case 'messageDocument':
        return '📎 Document';
      case 'messageSticker':
        return '🎨 Sticker';
      default:
        return '';
    }
  }

  static DateTime? _dateOf(Map<String, dynamic>? message) {
    final date = (message?['date'] as num?)?.toInt();
    if (date == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(date * 1000);
  }

  StreamController<List<TgMessage>> _controllerFor(int chatId) {
    return _messageControllers.putIfAbsent(
      chatId,
      () => StreamController<List<TgMessage>>.broadcast(),
    );
  }

  // ── TelegramClient ────────────────────────────────────────────────────────

  @override
  Future<TgAuthResult> submitPhone(String phone) async {
    final response = await _request({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phone,
    });
    if (response['@type'] == 'error') {
      return TgAuthResult(
        stage: TgAuthStage.phone,
        error: response['message'] as String?,
      );
    }
    return const TgAuthResult(stage: TgAuthStage.code);
  }

  @override
  Future<TgAuthResult> submitCode(String code) async {
    final response = await _request({
      '@type': 'checkAuthenticationCode',
      'code': code,
    });
    if (response['@type'] == 'error') {
      return TgAuthResult(
        stage: TgAuthStage.code,
        error: response['message'] as String?,
      );
    }
    return TgAuthResult(stage: _stage);
  }

  @override
  Future<TgAuthResult> submitPassword(String password) async {
    final response = await _request({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
    if (response['@type'] == 'error') {
      return TgAuthResult(
        stage: TgAuthStage.password,
        error: response['message'] as String?,
      );
    }
    return const TgAuthResult(stage: TgAuthStage.ready);
  }

  @override
  Future<void> logOut() async {
    await _request({'@type': 'logOut'});
  }

  @override
  List<TgFolder> get folders => const [
        TgFolder(id: 'all', title: 'All Chats'),
        TgFolder(id: 'personal', title: 'Personal'),
        TgFolder(id: 'groups', title: 'Groups'),
        TgFolder(id: 'channels', title: 'Channels'),
        TgFolder(id: 'unread', title: 'Unread'),
        TgFolder(id: 'bots', title: 'Bots'),
      ];

  @override
  List<TgStory> get stories => const [];

  @override
  List<TgUser> get contacts => const [];

  @override
  List<TgCall> get calls => const [];

  @override
  Stream<List<TgMessage>> messagesOf(int chatId) =>
      _controllerFor(chatId).stream;

  @override
  List<TgMessage> currentMessagesOf(int chatId) =>
      List.unmodifiable(_messages[chatId] ?? const []);

  @override
  Future<void> openChat(int chatId) async {
    _send({'@type': 'openChat', 'chat_id': chatId});
    await loadMoreMessages(chatId);
  }

  @override
  Future<void> closeChat(int chatId) async {
    _send({'@type': 'closeChat', 'chat_id': chatId});
  }

  @override
  Future<void> loadMoreMessages(int chatId) async {
    final existing = _messages[chatId];
    final fromId = existing == null || existing.isEmpty ? 0 : existing.first.id;
    final response = await _request({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': fromId,
      'offset': 0,
      'limit': 40,
      'only_local': false,
    });
    final list = response['messages'] as List?;
    if (list == null) return;
    // TDLib returns newest first; the UI renders oldest first.
    final loaded = [
      for (final json in list.cast<Map<String, dynamic>>()) _messageFrom(json),
    ].reversed.toList();
    _messages[chatId] = [...loaded, ...?existing];
    _controllerFor(chatId).add(currentMessagesOf(chatId));
  }

  @override
  Future<void> sendText(int chatId, String text, {TgMessage? replyTo}) async {
    _send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      if (replyTo != null)
        'reply_to': {
          '@type': 'inputMessageReplyToMessage',
          'message_id': replyTo.id,
        },
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
  }

  @override
  Future<void> sendPhoto(int chatId, {String? caption}) async {
    // Wiring a real file picker is out of scope here; the request shape is
    // what a picker would fill in with `inputFileLocal`.
    _send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessagePhoto',
        if (caption != null)
          'caption': {'@type': 'formattedText', 'text': caption},
      },
    });
  }

  @override
  Future<void> sendVoice(int chatId, int seconds) async {
    _send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageVoiceNote',
        'duration': seconds,
      },
    });
  }

  @override
  Future<void> sendFile(int chatId, String name, String size) async {
    _send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageDocument',
        'document': {'@type': 'inputFileLocal', 'path': name},
      },
    });
  }

  @override
  Future<void> deleteMessage(int chatId, int messageId) async {
    _send({
      '@type': 'deleteMessages',
      'chat_id': chatId,
      'message_ids': [messageId],
      'revoke': true,
    });
    _messages[chatId]?.removeWhere((m) => m.id == messageId);
    _controllerFor(chatId).add(currentMessagesOf(chatId));
  }

  @override
  Future<void> editMessage(int chatId, int messageId, String text) async {
    _send({
      '@type': 'editMessageText',
      'chat_id': chatId,
      'message_id': messageId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
  }

  @override
  Future<void> toggleReaction(int chatId, int messageId, String emoji) async {
    _send({
      '@type': 'addMessageReaction',
      'chat_id': chatId,
      'message_id': messageId,
      'reaction_type': {'@type': 'reactionTypeEmoji', 'emoji': emoji},
      'is_big': false,
      'update_recent_reactions': true,
    });
  }

  @override
  Future<void> markChatRead(int chatId) async {
    final ids = _messages[chatId]?.map((m) => m.id).toList() ?? const [];
    if (ids.isEmpty) return;
    _send({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': ids,
      'force_read': true,
    });
  }

  @override
  Future<void> toggleMute(int chatId) async {
    final chat = _chatIndex[chatId];
    if (chat == null) return;
    _send({
      '@type': 'setChatNotificationSettings',
      'chat_id': chatId,
      'notification_settings': {
        '@type': 'chatNotificationSettings',
        'use_default_mute_for': false,
        'mute_for': chat.isMuted ? 0 : 2147483647,
      },
    });
  }

  @override
  Future<void> togglePin(int chatId) async {
    final chat = _chatIndex[chatId];
    if (chat == null) return;
    _send({
      '@type': 'toggleChatIsPinned',
      'chat_list': {'@type': 'chatListMain'},
      'chat_id': chatId,
      'is_pinned': !chat.isPinned,
    });
  }
}

class _ReceiveConfig {
  const _ReceiveConfig(this.port, this.clientId);
  final SendPort port;
  final int clientId;
}
