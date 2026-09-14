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

  /// TDLib's last `authorizationState`, or null for backends that have none.
  String? get authorizationState => null;

  /// TDLib's last `connectionState`, or null.
  String? get connectionState => null;

  /// False while a live backend is still handshaking and cannot accept a
  /// phone number yet.
  bool get isReadyForPhone => true;

  Future<void> start();

  Future<void> dispose();

  /// Authorization state as it advances through the login flow.
  Stream<TgAuthStage> get authStage;

  TgAuthStage get currentStage;

  Future<TgAuthResult> submitPhone(String phone);

  Future<TgAuthResult> submitCode(String code);

  Future<TgAuthResult> submitPassword(String password);

  Future<void> logOut();

  /// Routes the connection through [proxy], or direct when null.
  Future<void> applyProxy(TgProxy? proxy) async {}

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

  /// Sends a recorded voice note. [path] is the file the recorder produced;
  /// [isOpus] says whether it is OGG/Opus, which is the only format Telegram
  /// accepts as a true voice note — anything else goes as an audio file.
  Future<void> sendVoice(
    int chatId,
    int seconds, {
    String? path,
    bool isOpus = true,
  });

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

  /// Pulls the media behind a message onto the device, so it can be played or
  /// opened. The message's `localPath` appears on its stream once it lands.
  ///
  /// Voice notes arrive on their own — they are small enough that waiting for
  /// a tap would only add latency — so this is for music and documents.
  Future<void> downloadMessageMedia(int chatId, int messageId) async {}

  /// Messages of [chatId] whose text matches [query], newest first.
  List<TgMessage> searchMessages(int chatId, String query);

  Future<void> toggleMute(int chatId);

  Future<void> togglePin(int chatId);

  /// Moves a chat into the archive, or back out of it.
  Future<void> toggleArchive(int chatId);

  /// Typing indicator for the currently open chat.
  Stream<int?> get typingChatId;

  /// Every message the server delivers, from every chat.
  ///
  /// [messagesOf] only covers conversations the UI has opened, so it cannot
  /// drive notifications; this is the firehose that can.
  Stream<TgMessage> get incomingMessages;
}
