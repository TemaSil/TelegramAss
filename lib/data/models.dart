/// Transport-agnostic view models.
///
/// Both the demo backend and the TDLib backend map onto these, so the UI never
/// touches a raw TDLib JSON object.
library;

enum TgChatKind { private, group, channel, bot, saved }

enum TgMessageStatus { sending, sent, delivered, read, failed }

enum TgMessageKind { text, photo, video, voice, audio, file, sticker, service }

enum TgAuthStage { splash, phone, code, password, ready }

class TgUser {
  const TgUser({
    required this.id,
    required this.name,
    this.username,
    this.phone,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
    this.isVerified = false,
    this.isPremium = false,
  });

  final int id;
  final String name;
  final String? username;
  final String? phone;
  final String? bio;
  final bool isOnline;
  final String? lastSeen;
  final bool isVerified;
  final bool isPremium;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters1;
    return '${parts.first.characters1}${parts[1].characters1}';
  }
}

extension on String {
  String get characters1 => isEmpty ? '' : substring(0, 1).toUpperCase();
}

class TgChat {
  const TgChat({
    required this.id,
    required this.title,
    required this.kind,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageOutgoing = false,
    this.lastMessageStatus = TgMessageStatus.read,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.isOnline = false,
    this.isVerified = false,
    this.memberCount,
    this.subtitle,
    this.hasStory = false,
    this.draft,
    this.photoPath,
    this.lists = const {'main'},
  });

  final int id;
  final String title;
  final TgChatKind kind;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool lastMessageOutgoing;
  final TgMessageStatus lastMessageStatus;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final bool isOnline;
  final bool isVerified;
  final int? memberCount;
  final String? subtitle;
  final bool hasStory;
  final String? draft;

  /// Local path of the downloaded chat photo, once TDLib has it on disk.
  final String? photoPath;

  /// Which chat lists this conversation belongs to: `main`, `archive`, or
  /// `folder:<id>` for one of the account's own folders. A chat can be in
  /// several at once, which is exactly how Telegram's folders work.
  final Set<String> lists;

  bool get isArchived => lists.contains('archive');

  String get initials {
    final parts = title.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters1;
    return '${parts.first.characters1}${parts[1].characters1}';
  }

  /// Presence line shown under the title inside a conversation.
  String get presence {
    switch (kind) {
      case TgChatKind.private:
        return isOnline ? 'online' : (subtitle ?? 'last seen recently');
      case TgChatKind.bot:
        return subtitle ?? 'bot';
      case TgChatKind.saved:
        return subtitle ?? 'your cloud storage';
      case TgChatKind.group:
        return '${memberCount ?? 0} members';
      case TgChatKind.channel:
        return '${_compact(memberCount ?? 0)} subscribers';
    }
  }

  TgChat copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? lastMessageOutgoing,
    TgMessageStatus? lastMessageStatus,
    int? unreadCount,
    bool? isMuted,
    bool? isPinned,
    bool? isOnline,
    int? memberCount,
    String? subtitle,
    String? draft,
    String? photoPath,
    Set<String>? lists,
  }) {
    return TgChat(
      id: id,
      title: title,
      kind: kind,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageOutgoing: lastMessageOutgoing ?? this.lastMessageOutgoing,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified,
      memberCount: memberCount ?? this.memberCount,
      subtitle: subtitle ?? this.subtitle,
      hasStory: hasStory,
      draft: draft ?? this.draft,
      photoPath: photoPath ?? this.photoPath,
      lists: lists ?? this.lists,
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

/// A styled range inside a message, as TDLib reports it.
///
/// Offsets are UTF-16 code units, which is what a Dart string indexes by, so
/// they can be used directly.
enum TgEntityKind {
  bold,
  italic,
  underline,
  strikethrough,
  spoiler,
  code,
  pre,
  link,
  mention,
  hashtag,
  customEmoji,
}

class TgTextEntity {
  const TgTextEntity({
    required this.kind,
    required this.offset,
    required this.length,
    this.url,
    this.customEmojiId,
  });

  final TgEntityKind kind;
  final int offset;
  final int length;

  /// For a `customEmoji` entity: the sticker to draw in place of the
  /// characters it covers. TDLib reports it as an int64 string.
  final String? customEmojiId;

  /// Where a link points. For `link` entities TDLib either gives an explicit
  /// url or the covered text is the url itself.
  final String? url;

  int get end => offset + length;
}

class TgReaction {
  const TgReaction({
    required this.emoji,
    required this.count,
    this.chosen = false,
  });

  final String emoji;
  final int count;
  final bool chosen;

  TgReaction toggled() => TgReaction(
    emoji: emoji,
    count: chosen ? count - 1 : count + 1,
    chosen: !chosen,
  );
}

/// The card Telegram unfurls under a link.
class TgLinkPreview {
  const TgLinkPreview({
    required this.url,
    this.siteName,
    this.title,
    this.description,
    this.imagePath,
  });

  final String url;
  final String? siteName;
  final String? title;
  final String? description;

  /// Local path of the preview image, once TDLib has fetched it.
  final String? imagePath;

  TgLinkPreview withImage(String path) => TgLinkPreview(
    url: url,
    siteName: siteName,
    title: title,
    description: description,
    imagePath: path,
  );
}

class TgMessage {
  const TgMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.date,
    required this.isOutgoing,
    this.kind = TgMessageKind.text,
    this.status = TgMessageStatus.read,
    this.senderName,
    this.senderId,
    this.replyToText,
    this.replyToSender,
    this.reactions = const [],
    this.isEdited = false,
    this.entities = const [],
    this.mediaSeed,
    this.voiceSeconds,
    this.audioTitle,
    this.audioPerformer,
    this.fileName,
    this.fileSize,
    this.uploadProgress,
    this.localPath,
    this.playablePath,
    this.isAnimatedSticker = false,
    this.linkPreview,
  });

  final int id;
  final int chatId;
  final String text;
  final DateTime date;
  final bool isOutgoing;
  final TgMessageKind kind;
  final TgMessageStatus status;
  final String? senderName;
  final int? senderId;
  final String? replyToText;
  final String? replyToSender;
  final List<TgReaction> reactions;
  final bool isEdited;

  /// Formatting ranges over [text].
  final List<TgTextEntity> entities;

  /// Deterministic seed used to paint a placeholder for photo messages.
  final int? mediaSeed;
  final int? voiceSeconds;

  /// Music metadata, for `messageAudio`.
  final String? audioTitle;
  final String? audioPerformer;
  final String? fileName;
  final String? fileSize;

  /// 0..1 while an outgoing attachment is uploading, null when complete.
  final double? uploadProgress;

  /// Where the attachment came from on this device. Set for anything the user
  /// picked, so the bubble can show the real image instead of a placeholder.
  final String? localPath;

  /// The media itself, once it is on disk: the voice note, the track, the
  /// video file. Kept apart from [localPath] because a video's [localPath] is
  /// its poster frame, not something that can be played.
  final String? playablePath;

  /// True when [localPath] is a `.tgs`: gzipped Lottie, which is played
  /// rather than drawn as an image.
  final bool isAnimatedSticker;

  /// Unfurled link card, for text messages that carry one.
  final TgLinkPreview? linkPreview;

  TgMessage copyWith({
    String? text,
    TgMessageStatus? status,
    List<TgReaction>? reactions,
    bool? isEdited,
    double? uploadProgress,
    String? localPath,
    String? playablePath,
    TgLinkPreview? linkPreview,
  }) {
    return TgMessage(
      id: id,
      chatId: chatId,
      text: text ?? this.text,
      date: date,
      isOutgoing: isOutgoing,
      kind: kind,
      status: status ?? this.status,
      senderName: senderName,
      senderId: senderId,
      replyToText: replyToText,
      replyToSender: replyToSender,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      entities: entities,
      mediaSeed: mediaSeed,
      voiceSeconds: voiceSeconds,
      audioTitle: audioTitle,
      audioPerformer: audioPerformer,
      fileName: fileName,
      fileSize: fileSize,
      uploadProgress: uploadProgress,
      localPath: localPath ?? this.localPath,
      playablePath: playablePath ?? this.playablePath,
      isAnimatedSticker: isAnimatedSticker,
      linkPreview: linkPreview ?? this.linkPreview,
    );
  }
}

/// One signed-in device, as Telegram's own Active Sessions screen lists them.
class TgSession {
  const TgSession({
    required this.id,
    required this.deviceModel,
    required this.platform,
    required this.appName,
    required this.isCurrent,
    this.ip,
    this.location,
    this.lastActive,
  });

  /// TDLib reports session ids as int64 strings.
  final String id;
  final String deviceModel;
  final String platform;
  final String appName;
  final bool isCurrent;
  final String? ip;
  final String? location;
  final DateTime? lastActive;
}

/// What a search of the server came back with.
class TgSearchResults {
  const TgSearchResults({this.chats = const [], this.messages = const []});

  static const empty = TgSearchResults();

  /// Conversations the account already has, plus public chats found by name.
  final List<TgChat> chats;

  /// Matching messages from across every conversation.
  final List<TgMessage> messages;

  bool get isEmpty => chats.isEmpty && messages.isEmpty;
}

class TgFolder {
  const TgFolder({required this.id, required this.title, this.unreadCount = 0});

  /// `all`, `archive`, `folder:<id>` for one of the account's own folders, or
  /// one of the demo backend's fixed kinds.
  final String id;
  final String title;
  final int unreadCount;
}

class TgStory {
  const TgStory({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.seed,
    this.isSeen = false,
    this.caption,
  });

  final int id;
  final int authorId;
  final String authorName;
  final int seed;
  final bool isSeen;
  final String? caption;
}

class TgCall {
  const TgCall({
    required this.id,
    required this.peerName,
    required this.peerId,
    required this.date,
    required this.isOutgoing,
    required this.isVideo,
    this.isMissed = false,
    this.duration,
  });

  final int id;
  final String peerName;
  final int peerId;
  final DateTime date;
  final bool isOutgoing;
  final bool isVideo;
  final bool isMissed;
  final Duration? duration;
}

/// Result of an authorization step.
class TgAuthResult {
  const TgAuthResult({required this.stage, this.error});

  final TgAuthStage stage;
  final String? error;
}

/// Connection proxy.
///
/// TDLib talks MTProto over raw TCP to Telegram's data centres. Where that is
/// filtered, the connection sits in `connectionStateConnecting` forever and no
/// login code is ever sent — which is indistinguishable from a broken app
/// unless the client can route through a proxy, as the official ones do.
class TgProxy {
  const TgProxy({
    required this.type,
    required this.server,
    required this.port,
    this.secret = '',
    this.username = '',
    this.password = '',
    this.enabled = true,
  });

  /// 'mtproto' or 'socks5'.
  final String type;
  final String server;
  final int port;

  /// MTProto only.
  final String secret;

  /// SOCKS5 only.
  final String username;
  final String password;

  final bool enabled;

  bool get isValid => server.trim().isNotEmpty && port > 0 && port < 65536;

  Map<String, dynamic> toJson() => {
    'type': type,
    'server': server,
    'port': port,
    'secret': secret,
    'username': username,
    'password': password,
    'enabled': enabled,
  };

  static TgProxy? fromJson(Map<String, dynamic> json) {
    final server = json['server'] as String?;
    final port = (json['port'] as num?)?.toInt();
    if (server == null || port == null) return null;
    return TgProxy(
      type: (json['type'] as String?) ?? 'mtproto',
      server: server,
      port: port,
      secret: (json['secret'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }

  TgProxy copyWith({
    String? type,
    String? server,
    int? port,
    String? secret,
    String? username,
    String? password,
    bool? enabled,
  }) => TgProxy(
    type: type ?? this.type,
    server: server ?? this.server,
    port: port ?? this.port,
    secret: secret ?? this.secret,
    username: username ?? this.username,
    password: password ?? this.password,
    enabled: enabled ?? this.enabled,
  );
}
