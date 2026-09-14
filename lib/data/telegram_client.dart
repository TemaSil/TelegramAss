import 'models.dart';

/// The contract every backend implements.
///
/// [DemoTelegramClient] serves generated data so the UI runs with no keys;
/// [TdlibTelegramClient] speaks the real TDLib JSON protocol over FFI. The UI
/// depends on this interface only.
abstract class TelegramClient {
  /// Human readable backend name, surfaced in Settings.
  String get backendName;

  /// True when the client talks to real Telegram servers.
  bool get isLive;

  Future<void> start();

  Future<void> dispose();

  /// Authorization state as it advances through the login flow.
  Stream<TgAuthStage> get authStage;

  TgAuthStage get currentStage;

  Future<TgAuthResult> submitPhone(String phone);

  Future<TgAuthResult> submitCode(String code);

  Future<TgAuthResult> submitPassword(String password);

  Future<void> logOut();

  /// The signed-in account.
  TgUser? get me;

  Stream<List<TgChat>> get chats;

  List<TgChat> get currentChats;

  List<TgFolder> get folders;

  List<TgStory> get stories;

  List<TgUser> get contacts;

  List<TgCall> get calls;

  /// Messages of one conversation, oldest first.
  Stream<List<TgMessage>> messagesOf(int chatId);

  List<TgMessage> currentMessagesOf(int chatId);

  Future<void> openChat(int chatId);

  Future<void> closeChat(int chatId);

  Future<void> loadMoreMessages(int chatId);

  Future<void> sendText(int chatId, String text, {TgMessage? replyTo});

  /// [path] is a file on this device, from the picker.
  Future<void> sendPhoto(int chatId, {String? path, String? caption});

  Future<void> sendVoice(int chatId, int seconds);

  Future<void> sendFile(int chatId, String name, String size, {String? path});

  Future<void> deleteMessage(int chatId, int messageId);

  Future<void> editMessage(int chatId, int messageId, String text);

  Future<void> toggleReaction(int chatId, int messageId, String emoji);

  Future<void> markChatRead(int chatId);

  /// Removes the chat from the list. On TDLib this clears the history and
  /// drops the chat from the main list; it does not delete the account's
  /// messages for the other side.
  Future<void> deleteChat(int chatId);

  /// Stores the unsent composer text for [chatId]. An empty string clears it.
  Future<void> setDraft(int chatId, String text);

  /// Messages of [chatId] whose text matches [query], newest first.
  List<TgMessage> searchMessages(int chatId, String query);

  Future<void> toggleMute(int chatId);

  Future<void> togglePin(int chatId);

  /// Typing indicator for the currently open chat.
  Stream<int?> get typingChatId;
}
