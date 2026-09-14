import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../diagnostics.dart';
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
  final _incomingController = StreamController<TgMessage>.broadcast();
  final _messageControllers = <int, StreamController<List<TgMessage>>>{};
  final _messages = <int, List<TgMessage>>{};
  final _chatIndex = <int, TgChat>{};
  final _pending = <int, Completer<Map<String, dynamic>>>{};

  /// TDLib hands out files by id and downloads them asynchronously, so these
  /// remember what a finished download belongs to.
  /// Supergroup/basic-group id → the chat that shows its member count, and
  /// the counts themselves once TDLib reports them. A `chat` object carries
  /// neither the member count nor a user's last-seen time; both arrive
  /// separately.
  final _chatOfGroup = <int, int>{};
  final _chatOfBasicGroup = <int, int>{};

  final _chatOfFile = <int, int>{};
  final _messageOfFile = <int, (int chatId, int messageId)>{};

  /// Link-preview images are tracked apart from the message's own media, so a
  /// resolved thumbnail cannot be mistaken for a photo attachment.
  final _previewOfFile = <int, (int chatId, int messageId)>{};

  /// File behind a message's music or document, remembered so a tap can start
  /// the download without re-reading the message from TDLib.
  final _playableOfMessage = <(int, int), int>{};

  /// Playable media awaiting download, kept apart from thumbnails so a
  /// finished video does not overwrite its own poster frame.
  final _playablePathOfFile = <int, (int chatId, int messageId)>{};

  /// Everyone TDLib has told us about, by user id.
  final _userIndex = <int, TgUser>{};

  /// The account's own folders, filled in by updateChatFolders.
  List<TgFolder> _folders = const [];

  TdJsonBindings? _bindings;
  Isolate? _receiveIsolate;
  ReceivePort? _receivePort;
  int _clientId = 0;
  int _queryId = 1;
  TgAuthStage _stage = TgAuthStage.splash;
  TgUser? _me;

  /// The last states TDLib reported, shown on the login screen so a stall is
  /// visible instead of looking like a dead button.
  String? _authorizationState;
  String? _connectionState;
  TgProxy? _proxy;

  /// True when the native library was found and the client is usable.
  bool get isAvailable => _bindings != null;

  @override
  String? get authorizationState => _authorizationState;

  @override
  String? get connectionState => _connectionState;

  @override
  bool get isReadyForPhone =>
      _authorizationState == 'authorizationStateWaitPhoneNumber';

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

  @override
  Stream<TgMessage> get incomingMessages => _incomingController.stream;

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
    bindings.execute(
      jsonEncode({'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 1}),
    );
    _clientId = bindings.createClientId();
    TgDiagnostics.instance.info('TDLib client $_clientId created.');

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
    TgDiagnostics.instance.info('Waiting for the authorization state…');
  }

  @override
  Future<void> dispose() async {
    _receiveIsolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    await _authController.close();
    await _chatsController.close();
    await _typingController.close();
    await _incomingController.close();
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
  }

  static void _receiveLoop(_ReceiveConfig config) {
    // Quiet: the main isolate already reported whether the library loaded, and
    // this isolate cannot reach that log anyway.
    final bindings = TdJsonBindings.open(quiet: true);
    if (bindings == null) {
      config.port.send('{"@type":"tdlibUnavailableInIsolate"}');
      return;
    }
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
        final name = request['@type'];
        TgDiagnostics.instance.error(
          '$name timed out after 30s — TDLib never answered.',
        );
        return {'@type': 'error', 'message': 'No answer from TDLib (timeout)'};
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

    final type = update['@type'] as String?;

    if (type == 'tdlibUnavailableInIsolate') {
      TgDiagnostics.instance.error(
        'The receive isolate could not load libtdjson, so no updates will '
        'ever arrive.',
      );
      return;
    }

    if (type == 'error') {
      TgDiagnostics.instance.error(
        'TDLib error ${update['code']}: ${update['message']}',
      );
    }

    final extra = update['@extra'];
    if (extra is int) {
      _pending.remove(extra)?.complete(update);
    }

    switch (type) {
      case 'updateAuthorizationState':
        _onAuthorizationState(
          update['authorization_state'] as Map<String, dynamic>,
        );
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
      case 'updateFile':
        _onFile(update['file'] as Map<String, dynamic>);
      case 'updateSupergroupFullInfo':
        _onGroupFullInfo(
          _chatOfGroup[(update['supergroup_id'] as num?)?.toInt()],
          update['supergroup_full_info'] as Map<String, dynamic>?,
        );
      case 'updateBasicGroupFullInfo':
        _onBasicGroupFullInfo(
          _chatOfBasicGroup[(update['basic_group_id'] as num?)?.toInt()],
          update['basic_group_full_info'] as Map<String, dynamic>?,
        );
      case 'updateUserStatus':
        _onUserStatus(
          (update['user_id'] as num?)?.toInt(),
          update['status'] as Map<String, dynamic>?,
        );
      case 'updateChatPosition':
        _onChatPosition(update);
      case 'updateChatFolders':
        _onChatFolders(update);
      case 'updateConnectionState':
        final state =
            (update['state'] as Map<String, dynamic>?)?['@type'] as String?;
        _connectionState = state;
        TgDiagnostics.instance.info('Connection: ${state ?? 'unknown'}');
    }
  }

  void _onAuthorizationState(Map<String, dynamic> state) {
    final name = state['@type'] as String?;
    _authorizationState = name;
    TgDiagnostics.instance.info('Authorization: ${name ?? 'unknown'}');

    switch (name) {
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
        // A proxy has to be in place before the first network call, which is
        // the phone number.
        applyProxy(_proxy);
        _setStage(TgAuthStage.phone);
      case 'authorizationStateWaitCode':
        _setStage(TgAuthStage.code);
      case 'authorizationStateWaitPassword':
        _setStage(TgAuthStage.password);
      case 'authorizationStateReady':
        _setStage(TgAuthStage.ready);
        _loadMe();
        _send({'@type': 'loadChats', 'limit': 40});
        // The archive is a separate list; without this the folder shows empty
        // until something in it moves.
        _send({
          '@type': 'loadChats',
          'chat_list': {'@type': 'chatListArchive'},
          'limit': 40,
        });
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
      isOnline:
          (json['status'] as Map<String, dynamic>?)?['@type'] ==
          'userStatusOnline',
    );
  }

  void _onUser(Map<String, dynamic> json) {
    final user = _userFrom(json);
    // Kept whether or not there is a chat with them: group member lists are
    // full of people the account has never written to.
    _userIndex[user.id] = user;
    final chat = _chatIndex[user.id];
    if (chat == null) return;
    _chatIndex[user.id] = chat.copyWith();
    _chatsController.add(currentChats);
  }

  /// Returns the file's local path when it is already on disk, and asks TDLib
  /// to fetch it otherwise. Returns null until the download reports back.
  String? _resolveFile(Map<String, dynamic>? file, {required int priority}) {
    if (file == null) return null;
    final local = file['local'] as Map<String, dynamic>?;
    final path = local?['path'] as String?;
    if ((local?['is_downloading_completed'] as bool?) == true &&
        path != null &&
        path.isNotEmpty) {
      return path;
    }

    final id = (file['id'] as num?)?.toInt();
    if (id == null) return null;
    _send({
      '@type': 'downloadFile',
      'file_id': id,
      'priority': priority,
      'synchronous': false,
    });
    return null;
  }

  /// The local path of a file TDLib already has, without starting a download.
  static String? _readyPath(Map<String, dynamic>? file) {
    final local = file?['local'] as Map<String, dynamic>?;
    if ((local?['is_downloading_completed'] as bool?) != true) return null;
    final path = local?['path'] as String?;
    return path == null || path.isEmpty ? null : path;
  }

  void _onFile(Map<String, dynamic> file) {
    final local = file['local'] as Map<String, dynamic>?;
    if ((local?['is_downloading_completed'] as bool?) != true) return;
    final path = local?['path'] as String?;
    if (path == null || path.isEmpty) return;

    final id = (file['id'] as num?)?.toInt();
    if (id == null) return;

    final chatId = _chatOfFile.remove(id);
    if (chatId != null) {
      final chat = _chatIndex[chatId];
      if (chat != null) {
        _chatIndex[chatId] = chat.copyWith(photoPath: path);
        _chatsController.add(currentChats);
      }
    }

    final preview = _previewOfFile.remove(id);
    if (preview != null) {
      final (previewChatId, previewMessageId) = preview;
      final list = _messages[previewChatId];
      final index = list?.indexWhere((m) => m.id == previewMessageId) ?? -1;
      final existing = index == -1 ? null : list![index].linkPreview;
      if (list != null && existing != null) {
        list[index] = list[index].copyWith(
          linkPreview: existing.withImage(path),
        );
        _controllerFor(previewChatId).add(currentMessagesOf(previewChatId));
      }
    }

    final playable = _playablePathOfFile.remove(id);
    if (playable != null) {
      final (playableChatId, playableMessageId) = playable;
      final list = _messages[playableChatId];
      final index = list?.indexWhere((m) => m.id == playableMessageId) ?? -1;
      if (list != null && index != -1) {
        list[index] = list[index].copyWith(playablePath: path);
        _controllerFor(playableChatId).add(currentMessagesOf(playableChatId));
      }
    }

    final message = _messageOfFile.remove(id);
    if (message != null) {
      final (messageChatId, messageId) = message;
      final list = _messages[messageChatId];
      final index = list?.indexWhere((m) => m.id == messageId) ?? -1;
      if (list != null && index != -1) {
        list[index] = list[index].copyWith(localPath: path);
        _controllerFor(messageChatId).add(currentMessagesOf(messageChatId));
      }
    }
  }

  void _onGroupFullInfo(int? chatId, Map<String, dynamic>? info) {
    if (chatId == null || info == null) return;
    final count = (info['member_count'] as num?)?.toInt();
    if (count == null) return;
    final chat = _chatIndex[chatId];
    if (chat == null) return;
    _chatIndex[chatId] = chat.copyWith(memberCount: count);
    _chatsController.add(currentChats);
  }

  void _onBasicGroupFullInfo(int? chatId, Map<String, dynamic>? info) {
    if (chatId == null || info == null) return;
    final members = (info['members'] as List?)?.length;
    if (members == null) return;
    final chat = _chatIndex[chatId];
    if (chat == null) return;
    _chatIndex[chatId] = chat.copyWith(memberCount: members);
    _chatsController.add(currentChats);
  }

  /// Private chats carry the user's id as the chat id, which is what lets a
  /// status update find its row.
  void _onUserStatus(int? userId, Map<String, dynamic>? status) {
    if (userId == null) return;
    final chat = _chatIndex[userId];
    if (chat == null) return;
    _chatIndex[userId] = chat.copyWith(
      isOnline: status?['@type'] == 'userStatusOnline',
      subtitle: _lastSeenFrom(status),
    );
    _chatsController.add(currentChats);
  }

  /// TDLib reports presence in buckets rather than a timestamp, except for
  /// `userStatusOffline`, which carries when the user was last online.
  static String? _lastSeenFrom(Map<String, dynamic>? status) {
    switch (status?['@type'] as String?) {
      case 'userStatusOnline':
        return 'online';
      case 'userStatusRecently':
        return 'last seen recently';
      case 'userStatusLastWeek':
        return 'last seen within a week';
      case 'userStatusLastMonth':
        return 'last seen within a month';
      case 'userStatusEmpty':
        return 'last seen a long time ago';
      case 'userStatusOffline':
        final was = (status?['was_online'] as num?)?.toInt();
        if (was == null || was == 0) return null;
        final at = DateTime.fromMillisecondsSinceEpoch(was * 1000);
        final diff = DateTime.now().difference(at);
        if (diff.inMinutes < 1) return 'last seen just now';
        if (diff.inHours < 1) return 'last seen ${diff.inMinutes} min ago';
        if (diff.inDays < 1) return 'last seen ${diff.inHours} h ago';
        return 'last seen ${diff.inDays} d ago';
      default:
        return null;
    }
  }

  void _onChat(Map<String, dynamic> json) {
    final id = (json['id'] as num).toInt();
    final type = json['type'] as Map<String, dynamic>?;
    final positions = json['positions'] as List?;
    final pinned =
        positions != null &&
        positions.any((p) => (p as Map)['is_pinned'] == true);
    final lists = _listsFrom(positions);

    // Avatars are small; give them a high priority so the list fills in fast.
    final photo =
        (json['photo'] as Map<String, dynamic>?)?['small']
            as Map<String, dynamic>?;
    final photoPath = _resolveFile(photo, priority: 32);
    final photoFileId = (photo?['id'] as num?)?.toInt();
    if (photoPath == null && photoFileId != null) {
      _chatOfFile[photoFileId] = id;
    }

    final typeName = type?['@type'] as String?;
    if (typeName == 'chatTypeSupergroup') {
      final groupId = (type?['supergroup_id'] as num?)?.toInt();
      if (groupId != null) {
        _chatOfGroup[groupId] = id;
        _send({'@type': 'getSupergroupFullInfo', 'supergroup_id': groupId});
      }
    } else if (typeName == 'chatTypeBasicGroup') {
      final groupId = (type?['basic_group_id'] as num?)?.toInt();
      if (groupId != null) {
        _chatOfBasicGroup[groupId] = id;
        _send({'@type': 'getBasicGroupFullInfo', 'basic_group_id': groupId});
      }
    }

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
      lists: lists,
    );
    _chatsController.add(currentChats);
  }

  /// Which lists a chat sits in, read from the positions TDLib reports.
  ///
  /// A chat with no position at all has been removed from every list; calling
  /// that `main` would resurrect it in the chat list, so it gets an empty set.
  static Set<String> _listsFrom(List? positions) {
    if (positions == null) return const {'main'};
    final lists = <String>{};
    for (final entry in positions.cast<Map<String, dynamic>>()) {
      final list = entry['list'] as Map<String, dynamic>?;
      switch (list?['@type'] as String?) {
        case 'chatListMain':
          lists.add('main');
        case 'chatListArchive':
          lists.add('archive');
        case 'chatListFolder':
          final folderId = (list?['chat_folder_id'] as num?)?.toInt();
          if (folderId != null) lists.add('folder:$folderId');
      }
    }
    return lists;
  }

  /// A single position changing — a chat archived, unarchived, or added to a
  /// folder. TDLib sends one position at a time, so the rest are kept.
  void _onChatPosition(Map<String, dynamic> update) {
    final id = (update['chat_id'] as num?)?.toInt();
    final chat = id == null ? null : _chatIndex[id];
    if (id == null || chat == null) return;

    final position = update['position'] as Map<String, dynamic>?;
    // No position at all says nothing about any list; _listsFrom would read
    // that as "main", which would put archived chats back in the chat list.
    if (position == null) return;
    final named = _listsFrom([position]);
    if (named.isEmpty) return;
    final name = named.first;

    // order "0" means the chat left that list.
    final present = (position['order'] as String?) != '0';
    final lists = Set<String>.from(chat.lists);
    if (present) {
      lists.add(name);
    } else {
      lists.remove(name);
    }

    _chatIndex[id] = chat.copyWith(
      lists: lists,
      isPinned: position['is_pinned'] as bool? ?? chat.isPinned,
    );
    _chatsController.add(currentChats);
  }

  /// The account's own folders, as the user arranged them.
  void _onChatFolders(Map<String, dynamic> update) {
    final raw = update['chat_folders'] as List?;
    if (raw == null) return;
    _folders = [
      for (final entry in raw.cast<Map<String, dynamic>>())
        if ((entry['id'] as num?) != null)
          TgFolder(
            id: 'folder:${(entry['id'] as num).toInt()}',
            // Newer TDLib wraps the title in a formattedText.
            title: entry['title'] is Map
                ? ((entry['title'] as Map)['text'] as String? ?? 'Folder')
                : (entry['title'] as String? ?? 'Folder'),
          ),
    ];
    _chatsController.add(currentChats);
  }

  static bool _isMuted(Map<String, dynamic> chat) {
    final settings = chat['notification_settings'] as Map<String, dynamic>?;
    final muteFor = (settings?['mute_for'] as num?)?.toInt() ?? 0;
    return muteFor > 0;
  }

  /// Supergroups and channels share a TDLib chat type; `is_channel` is what
  /// separates a broadcast channel from a group.
  static TgChatKind _kindFrom(Map<String, dynamic>? type) {
    switch (type?['@type'] as String?) {
      case 'chatTypeBasicGroup':
        return TgChatKind.group;
      case 'chatTypeSupergroup':
        return (type?['is_channel'] as bool?) ?? false
            ? TgChatKind.channel
            : TgChatKind.group;
      case 'chatTypeSecret':
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
    if (!_incomingController.isClosed) _incomingController.add(message);
  }

  TgMessage _messageFrom(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>?;
    final type = content?['@type'] as String?;
    final sender = json['sender_id'] as Map<String, dynamic>?;
    final chatId = (json['chat_id'] as num).toInt();
    final messageId = (json['id'] as num).toInt();

    // Photos arrive as a list of sizes; the largest one the list carries is
    // what a bubble should eventually show.
    final sizes =
        (content?['photo'] as Map<String, dynamic>?)?['sizes'] as List?;
    final largest = sizes == null || sizes.isEmpty
        ? null
        : (sizes.last as Map<String, dynamic>)['photo']
              as Map<String, dynamic>?;
    // Stickers are a file too. WebP ones are an image; TGS ones are gzipped
    // Lottie and are played. WebM video stickers would need a video decoder,
    // so those still fall back to the emoji they stand for.
    final sticker = content?['sticker'] as Map<String, dynamic>?;
    final stickerFormat =
        (sticker?['format'] as Map<String, dynamic>?)?['@type'] as String?;
    final isAnimatedSticker = stickerFormat == 'stickerFormatTgs';
    final isDrawableSticker =
        stickerFormat == 'stickerFormatWebp' || isAnimatedSticker;
    final stickerFile = isDrawableSticker
        ? (sticker?['sticker'] as Map<String, dynamic>?)
        : null;

    // A video shows its thumbnail rather than the video itself, which is far
    // too big to fetch just to draw a bubble.
    final video =
        (content?['video'] ?? content?['animation']) as Map<String, dynamic>?;
    final videoThumb =
        (video?['thumbnail'] as Map<String, dynamic>?)?['file']
            as Map<String, dynamic>?;
    final document = content?['document'] as Map<String, dynamic>?;
    final audio = content?['audio'] as Map<String, dynamic>?;

    final linkPreview = _linkPreviewFrom(
      content?['link_preview'] ?? content?['web_page'],
      chatId,
      messageId,
    );

    // Voice notes are a few tens of kilobytes; fetching them up front costs
    // nothing and means a tap plays immediately. Music, video and documents
    // wait to be asked for — see downloadMessageMedia.
    final voice =
        (content?['voice_note'] as Map<String, dynamic>?)?['voice']
            as Map<String, dynamic>?;
    final playable =
        (voice ?? audio?['audio'] ?? video?['video'] ?? document?['document'])
            as Map<String, dynamic>?;
    final playablePath = voice != null
        ? _resolveFile(voice, priority: 24)
        : _readyPath(playable);
    final playableId = (playable?['id'] as num?)?.toInt();
    if (playableId != null) {
      _playableOfMessage[(chatId, messageId)] = playableId;
      if (playablePath == null) {
        _playablePathOfFile[playableId] = (chatId, messageId);
      }
    }

    final previewFile = largest ?? stickerFile ?? videoThumb;
    final mediaPath = _resolveFile(previewFile, priority: 16);
    final mediaFileId = (previewFile?['id'] as num?)?.toInt();
    if (mediaPath == null && mediaFileId != null) {
      _messageOfFile[mediaFileId] = (chatId, messageId);
    }

    return TgMessage(
      id: messageId,
      chatId: chatId,
      text: sticker == null
          ? _textOf(content)
          : (sticker['emoji'] as String? ?? ''),
      date: DateTime.fromMillisecondsSinceEpoch(
        ((json['date'] as num?) ?? 0).toInt() * 1000,
      ),
      isOutgoing: (json['is_outgoing'] as bool?) ?? false,
      kind: _messageKindFrom(type),
      status: TgMessageStatus.read,
      senderId: (sender?['user_id'] as num?)?.toInt(),
      isEdited: ((json['edit_date'] as num?) ?? 0) > 0,
      reactions: _reactionsFrom(json['interaction_info']),
      entities: _entitiesOf(content),
      localPath: mediaPath,
      playablePath: playablePath,
      isAnimatedSticker: isAnimatedSticker,
      linkPreview: linkPreview,
      voiceSeconds:
          ((content?['voice_note'] as Map<String, dynamic>?)?['duration']
                  as num?)
              ?.toInt() ??
          (video?['duration'] as num?)?.toInt() ??
          (audio?['duration'] as num?)?.toInt(),
      audioTitle: audio?['title'] as String?,
      audioPerformer: audio?['performer'] as String?,
      fileName:
          document?['file_name'] as String? ??
          audio?['file_name'] as String? ??
          video?['file_name'] as String?,
      fileSize: _humanSize(
        ((document?['document'] ?? audio?['audio'] ?? video?['video'])
                as Map<String, dynamic>?)?['size']
            as int?,
      ),
    );
  }

  /// Unfurls the card TDLib attaches to a text message. Older builds call it
  /// `web_page`, newer ones `link_preview`; both carry the same fields.
  TgLinkPreview? _linkPreviewFrom(dynamic raw, int chatId, int messageId) {
    final page = raw as Map<String, dynamic>?;
    final url = page?['url'] as String?;
    if (page == null || url == null || url.isEmpty) return null;

    // Prefer the smallest size that is still legible: a preview is a thumbnail,
    // and the full-size photo is not worth the bytes.
    final sizes = (page['photo'] as Map<String, dynamic>?)?['sizes'] as List?;
    final thumb = sizes == null || sizes.isEmpty
        ? null
        : (sizes.first as Map<String, dynamic>)['photo']
              as Map<String, dynamic>?;
    final path = _resolveFile(thumb, priority: 8);
    final fileId = (thumb?['id'] as num?)?.toInt();
    if (path == null && fileId != null) {
      _previewOfFile[fileId] = (chatId, messageId);
    }

    final description = page['description'] as Map<String, dynamic>?;
    return TgLinkPreview(
      url: url,
      siteName: (page['site_name'] as String?)?.trim(),
      title: (page['title'] as String?)?.trim(),
      description: (description?['text'] as String?)?.trim(),
      imagePath: path,
    );
  }

  static List<TgReaction> _reactionsFrom(dynamic interactionInfo) {
    final reactions = (interactionInfo as Map<String, dynamic>?)?['reactions'];
    final list = (reactions as Map<String, dynamic>?)?['reactions'] as List?;
    if (list == null) return const [];
    return [
      for (final entry in list.cast<Map<String, dynamic>>())
        TgReaction(
          emoji:
              (entry['type'] as Map<String, dynamic>?)?['emoji'] as String? ??
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
      case 'messageVideo':
      case 'messageAnimation':
        return TgMessageKind.video;
      case 'messageVoiceNote':
        return TgMessageKind.voice;
      case 'messageAudio':
        return TgMessageKind.audio;
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

  /// Bytes as Telegram writes them next to a file name.
  static String _humanSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  /// Formatting ranges attached to a message's text.
  static List<TgTextEntity> _entitiesOf(Map<String, dynamic>? content) {
    final formatted =
        (content?['text'] ?? content?['caption']) as Map<String, dynamic>?;
    final raw = formatted?['entities'] as List?;
    if (raw == null || raw.isEmpty) return const [];

    final entities = <TgTextEntity>[];
    for (final item in raw.cast<Map<String, dynamic>>()) {
      final type = (item['type'] as Map<String, dynamic>?)?['@type'] as String?;
      final kind = switch (type) {
        'textEntityTypeBold' => TgEntityKind.bold,
        'textEntityTypeItalic' => TgEntityKind.italic,
        'textEntityTypeUnderline' => TgEntityKind.underline,
        'textEntityTypeStrikethrough' => TgEntityKind.strikethrough,
        'textEntityTypeSpoiler' => TgEntityKind.spoiler,
        'textEntityTypeCode' => TgEntityKind.code,
        'textEntityTypePre' || 'textEntityTypePreCode' => TgEntityKind.pre,
        'textEntityTypeUrl' || 'textEntityTypeTextUrl' => TgEntityKind.link,
        'textEntityTypeEmailAddress' ||
        'textEntityTypePhoneNumber' => TgEntityKind.link,
        'textEntityTypeMention' ||
        'textEntityTypeMentionName' => TgEntityKind.mention,
        'textEntityTypeHashtag' ||
        'textEntityTypeCashtag' => TgEntityKind.hashtag,
        'textEntityTypeCustomEmoji' => TgEntityKind.customEmoji,
        _ => null,
      };
      if (kind == null) continue;

      entities.add(
        TgTextEntity(
          kind: kind,
          offset: ((item['offset'] as num?) ?? 0).toInt(),
          length: ((item['length'] as num?) ?? 0).toInt(),
          url: (item['type'] as Map<String, dynamic>?)?['url'] as String?,
        ),
      );
    }
    return entities;
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
      case 'messageVideo':
        return '🎬 Video';
      case 'messageAnimation':
        return '🎬 GIF';
      case 'messageVoiceNote':
        return '🎤 Voice message';
      case 'messageAudio':
        final audio = content?['audio'] as Map<String, dynamic>?;
        final title = audio?['title'] as String?;
        return '🎵 ${title == null || title.isEmpty ? 'Audio' : title}';
      case 'messageDocument':
        final document = content?['document'] as Map<String, dynamic>?;
        final name = document?['file_name'] as String?;
        return '📎 ${name == null || name.isEmpty ? 'Document' : name}';
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
  Future<void> applyProxy(TgProxy? proxy) async {
    _proxy = proxy;
    if (_bindings == null) return;

    if (proxy == null || !proxy.enabled || !proxy.isValid) {
      _send({'@type': 'disableProxy'});
      TgDiagnostics.instance.info('Proxy disabled — connecting directly.');
      return;
    }

    _send({
      '@type': 'addProxy',
      'server': proxy.server.trim(),
      'port': proxy.port,
      'enable': true,
      'type': proxy.type == 'socks5'
          ? {
              '@type': 'proxyTypeSocks5',
              'username': proxy.username,
              'password': proxy.password,
            }
          : {'@type': 'proxyTypeMtproto', 'secret': proxy.secret.trim()},
    });
    TgDiagnostics.instance.info(
      'Proxy ${proxy.type} ${proxy.server}:${proxy.port} enabled.',
    );
  }

  @override
  Future<void> downloadMessageMedia(int chatId, int messageId) async {
    final fileId = _playableOfMessage[(chatId, messageId)];
    if (fileId == null) return;
    _playablePathOfFile[fileId] = (chatId, messageId);
    _send({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 32,
      'synchronous': false,
    });
  }

  @override
  Future<void> logOut() async {
    await _request({'@type': 'logOut'});
  }

  @override
  List<TgFolder> get folders => [
    const TgFolder(id: 'all', title: 'All Chats'),
    ..._folders,
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
  Future<void> sendPhoto(int chatId, {String? path, String? caption}) async {
    if (path == null) return;
    _send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessagePhoto',
        'photo': {'@type': 'inputFileLocal', 'path': path},
        if (caption != null)
          'caption': {'@type': 'formattedText', 'text': caption},
      },
    });
  }

  @override
  Future<void> sendVoice(
    int chatId,
    int seconds, {
    String? path,
    bool isOpus = true,
  }) async {
    if (path == null) return;
    final file = {'@type': 'inputFileLocal', 'path': path};
    _send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': isOpus
          ? {
              '@type': 'inputMessageVoiceNote',
              'voice_note': file,
              'duration': seconds,
            }
          : {'@type': 'inputMessageAudio', 'audio': file, 'duration': seconds},
    });
  }

  @override
  Future<void> sendFile(
    int chatId,
    String name,
    String size, {
    String? path,
  }) async {
    if (path == null) return;
    _send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageDocument',
        'document': {'@type': 'inputFileLocal', 'path': path},
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
  Future<void> deleteChat(int chatId) async {
    _send({
      '@type': 'deleteChatHistory',
      'chat_id': chatId,
      'remove_from_chat_list': true,
      'revoke': false,
    });
    _chatIndex.remove(chatId);
    _messages.remove(chatId);
    _chatsController.add(currentChats);
  }

  @override
  Future<void> setDraft(int chatId, String text) async {
    _send({
      '@type': 'setChatDraftMessage',
      'chat_id': chatId,
      'draft_message': text.isEmpty
          ? null
          : {
              '@type': 'draftMessage',
              'input_message_text': {
                '@type': 'inputMessageText',
                'text': {'@type': 'formattedText', 'text': text},
              },
            },
    });
    final chat = _chatIndex[chatId];
    if (chat != null) _chatIndex[chatId] = chat.copyWith(draft: text);
  }

  @override
  List<TgMessage> searchMessages(int chatId, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    // Local pass over what is already loaded; `searchChatMessages` would take
    // this server-side once the UI needs paging.
    return (_messages[chatId] ?? const <TgMessage>[])
        .where((message) => message.text.toLowerCase().contains(needle))
        .toList()
        .reversed
        .toList();
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
  Future<void> forwardMessages(
    int fromChatId,
    int toChatId,
    List<int> messageIds, {
    bool asCopy = false,
  }) async {
    if (messageIds.isEmpty) return;
    _send({
      '@type': 'forwardMessages',
      'chat_id': toChatId,
      'from_chat_id': fromChatId,
      // TDLib requires these in increasing order.
      'message_ids': [...messageIds]..sort(),
      'send_copy': asCopy,
      'remove_caption': false,
    });
  }

  @override
  Future<List<TgUser>> chatMembers(int chatId) async {
    // Basic groups carry their members in full info; supergroups and channels
    // need a paged request, and often refuse it outright for a channel the
    // account does not administer.
    final basicGroupId = _chatOfBasicGroup.entries
        .where((entry) => entry.value == chatId)
        .map((entry) => entry.key)
        .firstOrNull;
    if (basicGroupId != null) {
      final info = await _request({
        '@type': 'getBasicGroupFullInfo',
        'basic_group_id': basicGroupId,
      });
      final members = info['members'] as List?;
      return [
        for (final raw in (members ?? const []).cast<Map<String, dynamic>>())
          if (_userIndex[_memberUserId(raw)] != null)
            _userIndex[_memberUserId(raw)]!,
      ];
    }

    final supergroupId = _chatOfGroup.entries
        .where((entry) => entry.value == chatId)
        .map((entry) => entry.key)
        .firstOrNull;
    if (supergroupId == null) return const [];

    final response = await _request({
      '@type': 'getSupergroupMembers',
      'supergroup_id': supergroupId,
      'offset': 0,
      'limit': 200,
    });
    final members = response['members'] as List?;
    if (members == null) return const [];

    final users = <TgUser>[];
    for (final raw in members.cast<Map<String, dynamic>>()) {
      final userId = _memberUserId(raw);
      if (userId == null) continue;
      final known = _userIndex[userId];
      if (known != null) {
        users.add(known);
      } else {
        // Not seen yet; ask, and it fills in for the next open.
        _send({'@type': 'getUser', 'user_id': userId});
      }
    }
    return users;
  }

  static int? _memberUserId(Map<String, dynamic> member) {
    final sender = member['member_id'] as Map<String, dynamic>?;
    return (sender?['user_id'] as num?)?.toInt();
  }

  @override
  Future<void> leaveChat(int chatId) async {
    await _request({'@type': 'leaveChat', 'chat_id': chatId});
  }

  @override
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? username,
  }) async {
    if (firstName != null || lastName != null) {
      await _request({
        '@type': 'setName',
        'first_name': firstName ?? _me?.name.split(' ').first ?? '',
        'last_name': lastName ?? '',
      });
    }
    if (bio != null) {
      await _request({'@type': 'setBio', 'bio': bio});
    }
    if (username != null) {
      await _request({'@type': 'setUsername', 'username': username});
    }
    await _loadMe();
  }

  @override
  Future<int?> addContact(
    String phone,
    String firstName,
    String lastName,
  ) async {
    final response = await _request({
      '@type': 'importContacts',
      'contacts': [
        {
          '@type': 'contact',
          'phone_number': phone,
          'first_name': firstName,
          'last_name': lastName,
        },
      ],
    });

    // Telegram answers with a user id of 0 for a number nobody is registered
    // on, which is not an error — just nobody to write to.
    final ids = response['user_ids'] as List?;
    final userId = ids == null || ids.isEmpty ? 0 : (ids.first as num).toInt();
    if (userId == 0) return null;

    final chat = await _request({
      '@type': 'createPrivateChat',
      'user_id': userId,
      'force': false,
    });
    final chatId = (chat['id'] as num?)?.toInt();
    return chatId;
  }

  @override
  Future<List<TgSession>> activeSessions() async {
    final response = await _request({'@type': 'getActiveSessions'});
    final sessions = response['sessions'] as List?;
    if (sessions == null) return const [];

    final list = [
      for (final raw in sessions.cast<Map<String, dynamic>>())
        TgSession(
          id: raw['id'] as String? ?? '',
          deviceModel: raw['device_model'] as String? ?? 'Device',
          platform: [
            if ((raw['platform'] as String?)?.isNotEmpty ?? false)
              raw['platform'] as String,
            if ((raw['system_version'] as String?)?.isNotEmpty ?? false)
              raw['system_version'] as String,
          ].join(' '),
          appName: [
            if ((raw['application_name'] as String?)?.isNotEmpty ?? false)
              raw['application_name'] as String,
            if ((raw['application_version'] as String?)?.isNotEmpty ?? false)
              raw['application_version'] as String,
          ].join(' '),
          isCurrent: raw['is_current'] as bool? ?? false,
          ip: raw['ip_address'] as String?,
          location: raw['location'] as String?,
          lastActive: (raw['last_active_date'] as num?) == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  (raw['last_active_date'] as num).toInt() * 1000,
                ),
        ),
    ];

    // This device first, then most recently seen.
    list.sort((a, b) {
      if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
      final at = a.lastActive ?? DateTime(1970);
      final bt = b.lastActive ?? DateTime(1970);
      return bt.compareTo(at);
    });
    return list;
  }

  @override
  Future<void> terminateSession(String sessionId) async {
    await _request({'@type': 'terminateSession', 'session_id': sessionId});
  }

  @override
  Future<List<TgMessage>> pinnedMessages(int chatId) async {
    // Recent TDLib has no pinned_message_id on the chat; the pinned set is a
    // filtered search, which also covers chats with several of them.
    final response = await _request({
      '@type': 'searchChatMessages',
      'chat_id': chatId,
      'query': '',
      'limit': 20,
      'filter': {'@type': 'searchMessagesFilterPinned'},
    });
    final messages = response['messages'] as List?;
    if (messages == null) return const [];
    return [
      for (final raw in messages.cast<Map<String, dynamic>>())
        _messageFrom(raw),
    ];
  }

  @override
  Future<void> setMessagePinned(
    int chatId,
    int messageId, {
    required bool pinned,
  }) async {
    _send(
      pinned
          ? {
              '@type': 'pinChatMessage',
              'chat_id': chatId,
              'message_id': messageId,
              'disable_notification': false,
            }
          : {
              '@type': 'unpinChatMessage',
              'chat_id': chatId,
              'message_id': messageId,
            },
    );
  }

  @override
  Future<TgSearchResults> searchGlobal(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return TgSearchResults.empty;

    // Three questions at once: chats already known, public chats by name, and
    // message text across every conversation.
    final responses = await Future.wait([
      _request({'@type': 'searchChats', 'query': trimmed, 'limit': 30}),
      _request({'@type': 'searchPublicChats', 'query': trimmed}),
      _request({
        '@type': 'searchMessages',
        'query': trimmed,
        'offset': '',
        'limit': 40,
      }),
    ]);

    final chats = <int, TgChat>{};
    for (final response in responses.take(2)) {
      final ids = response['chat_ids'] as List?;
      if (ids == null) continue;
      for (final raw in ids) {
        final id = (raw as num).toInt();
        final known = _chatIndex[id];
        if (known != null) {
          chats[id] = known;
        } else {
          // A public chat the account has never opened: ask for it, and it
          // arrives as an updateNewChat for the next search.
          _send({'@type': 'getChat', 'chat_id': id});
        }
      }
    }

    final found = responses[2];
    final messages = <TgMessage>[
      if (found['messages'] is List)
        for (final raw
            in (found['messages'] as List).cast<Map<String, dynamic>>())
          _messageFrom(raw),
    ];

    return TgSearchResults(chats: chats.values.toList(), messages: messages);
  }

  @override
  Future<void> toggleArchive(int chatId) async {
    final chat = _chatIndex[chatId];
    if (chat == null) return;
    _send({
      '@type': 'addChatToList',
      'chat_id': chatId,
      'chat_list': {
        '@type': chat.isArchived ? 'chatListMain' : 'chatListArchive',
      },
    });
  }

  @override
  Future<void> togglePin(int chatId) async {
    final chat = _chatIndex[chatId];
    if (chat == null) return;
    _send({
      '@type': 'toggleChatIsPinned',
      // Pinning is per list: pinning an archived chat into the main list is
      // not what the row means, and TDLib would refuse it.
      'chat_list': {
        '@type': chat.isArchived ? 'chatListArchive' : 'chatListMain',
      },
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
