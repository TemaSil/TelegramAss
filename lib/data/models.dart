/// Transport-agnostic view models.
///
/// Both the demo backend and the TDLib backend map onto these, so the UI never
/// touches a raw TDLib JSON object.
library;

enum TgChatKind { private, group, channel, bot, saved }

enum TgMessageStatus { sending, sent, delivered, read, failed }

enum TgMessageKind { text, photo, voice, file, sticker, service }

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
    String? draft,
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
      isOnline: isOnline,
      isVerified: isVerified,
      memberCount: memberCount,
      subtitle: subtitle,
      hasStory: hasStory,
      draft: draft ?? this.draft,
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

class TgReaction {
  const TgReaction({required this.emoji, required this.count, this.chosen = false});

  final String emoji;
  final int count;
  final bool chosen;

  TgReaction toggled() => TgReaction(
        emoji: emoji,
        count: chosen ? count - 1 : count + 1,
        chosen: !chosen,
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
    this.mediaSeed,
    this.voiceSeconds,
    this.fileName,
    this.fileSize,
    this.uploadProgress,
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

  /// Deterministic seed used to paint a placeholder for photo messages.
  final int? mediaSeed;
  final int? voiceSeconds;
  final String? fileName;
  final String? fileSize;

  /// 0..1 while an outgoing attachment is uploading, null when complete.
  final double? uploadProgress;

  TgMessage copyWith({
    String? text,
    TgMessageStatus? status,
    List<TgReaction>? reactions,
    bool? isEdited,
    double? uploadProgress,
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
      mediaSeed: mediaSeed,
      voiceSeconds: voiceSeconds,
      fileName: fileName,
      fileSize: fileSize,
      uploadProgress: uploadProgress,
    );
  }
}

class TgFolder {
  const TgFolder({required this.id, required this.title, this.unreadCount = 0});

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
