import 'dart:async';

import '../models.dart';
import '../telegram_client.dart';

/// Web stand-in for [TelegramClient]'s TDLib implementation.
///
/// The web target exists for UI previews and screenshots; TDLib is a native
/// shared library and cannot run there. [start] throws the same [StateError]
/// the native client throws when `libtdjson.so` is missing, which is what
/// makes `AppState` fall back to the demo backend on both platforms.
class TdlibTelegramClient implements TelegramClient {
  TdlibTelegramClient({
    required this.apiId,
    required this.apiHash,
    required this.databaseDirectory,
    required this.filesDirectory,
    this.systemLanguageCode = 'en',
    this.deviceModel = 'Web',
    this.applicationVersion = '1.0.0',
  });

  final int apiId;
  final String apiHash;
  final String databaseDirectory;
  final String filesDirectory;
  final String systemLanguageCode;
  final String deviceModel;
  final String applicationVersion;

  Never _unsupported() =>
      throw StateError('TDLib is not available on the web target.');

  @override
  String get backendName => 'TDLib (unavailable on web)';

  @override
  bool get isLive => false;

  @override
  bool get isReadyForPhone => false;

  @override
  String? get authorizationState => null;

  @override
  String? get connectionState => null;

  @override
  Future<void> start() async => _unsupported();

  @override
  Future<void> dispose() async {}

  @override
  Stream<TgAuthStage> get authStage => const Stream.empty();

  @override
  TgAuthStage get currentStage => TgAuthStage.phone;

  @override
  TgUser? get me => null;

  @override
  Future<TgAuthResult> submitPhone(String phone) async => _unsupported();

  @override
  Future<TgAuthResult> submitCode(String code) async => _unsupported();

  @override
  Future<TgAuthResult> submitPassword(String password) async => _unsupported();

  @override
  Future<void> logOut() async {}

  @override
  Future<void> applyProxy(TgProxy? proxy) async {}

  @override
  Stream<List<TgChat>> get chats => const Stream.empty();

  @override
  List<TgChat> get currentChats => const [];

  @override
  List<TgFolder> get folders => const [];

  @override
  List<TgStory> get stories => const [];

  @override
  List<TgUser> get contacts => const [];

  @override
  List<TgCall> get calls => const [];

  @override
  Stream<List<TgMessage>> messagesOf(int chatId) => const Stream.empty();

  @override
  List<TgMessage> currentMessagesOf(int chatId) => const [];

  @override
  Future<void> openChat(int chatId) async {}

  @override
  Future<void> closeChat(int chatId) async {}

  @override
  Future<void> loadMoreMessages(int chatId) async {}

  @override
  Future<void> sendText(int chatId, String text, {TgMessage? replyTo}) async {}

  @override
  Future<void> sendPhoto(int chatId, {String? path, String? caption}) async {}

  @override
  Future<void> sendVoice(
    int chatId,
    int seconds, {
    String? path,
    bool isOpus = true,
  }) async {}

  @override
  Future<void> sendFile(
    int chatId,
    String name,
    String size, {
    String? path,
  }) async {}

  @override
  Future<void> deleteMessage(int chatId, int messageId) async {}

  @override
  Future<void> editMessage(int chatId, int messageId, String text) async {}

  @override
  Future<void> toggleReaction(int chatId, int messageId, String emoji) async {}

  @override
  Future<void> markChatRead(int chatId) async {}

  @override
  Future<void> deleteChat(int chatId) async {}

  @override
  Future<void> setDraft(int chatId, String text) async {}

  @override
  Future<void> downloadMessageMedia(int chatId, int messageId) async {}

  @override
  List<TgMessage> searchMessages(int chatId, String query) => const [];

  @override
  Future<void> toggleMute(int chatId) async {}

  @override
  Future<void> togglePin(int chatId) async {}

  @override
  Stream<int?> get typingChatId => const Stream.empty();

  @override
  Stream<TgMessage> get incomingMessages => const Stream.empty();
}
