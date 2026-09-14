import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_client.dart';
import 'diagnostics.dart';
import 'notifications.dart';
import 'models.dart';
import 'tdlib/tdlib_backend.dart';
import 'telegram_client.dart';

/// Single source of truth for the UI.
///
/// Picks the backend at startup: TDLib when `--dart-define=TELEGRAM_API_ID`
/// carries real credentials *and* the native library is present, demo data
/// otherwise. Every screen listens to this notifier.
class AppState extends ChangeNotifier {
  AppState._(this.client, this._prefs);

  static const _apiId = int.fromEnvironment('TELEGRAM_API_ID');
  static const _apiHash = String.fromEnvironment('TELEGRAM_API_HASH');

  /// `--dart-define=DEMO_AUTOLOGIN=true` starts the demo backend signed in.
  static const _demoAutoLogin = bool.fromEnvironment('DEMO_AUTOLOGIN');

  final TelegramClient client;

  /// Null when the platform channel is unavailable (plain `dart test` runs),
  /// in which case preferences stay in memory for the session.
  final SharedPreferences? _prefs;

  final _subscriptions = <StreamSubscription<Object?>>[];

  List<TgChat> _chats = const [];
  TgAuthStage _stage = TgAuthStage.splash;
  String _activeFolder = 'all';
  String _searchQuery = '';
  int? _typingChatId;

  // User preferences, surfaced on the Settings screen.
  bool _reduceTransparency = false;
  bool _readReceipts = true;
  bool _autoNightMode = true;
  bool _darkMode = true;
  bool _notifications = true;
  double _glassIntensity = 1.0;
  int _messageFontSize = 16;

  /// Applies to open conversations only; the tab screens use the system
  /// background, as they do on iOS.
  String _wallpaper = 'aurora';

  /// 'system', 'en' or 'ru'.
  String _language = 'system';

  TgProxy? _proxy;

  List<TgChat> get chats => _chats;
  TgAuthStage get stage => _stage;
  String get activeFolder => _activeFolder;
  String get searchQuery => _searchQuery;
  int? get typingChatId => _typingChatId;
  TgUser? get me => client.me;
  List<TgFolder> get folders => client.folders;
  List<TgStory> get stories => client.stories;
  List<TgUser> get contacts => client.contacts;
  List<TgCall> get calls => client.calls;

  bool get reduceTransparency => _reduceTransparency;
  bool get readReceipts => _readReceipts;
  bool get autoNightMode => _autoNightMode;
  bool get notifications => _notifications;

  /// Used only when [autoNightMode] is off.
  bool get darkMode => _darkMode;
  double get glassIntensity => _glassIntensity;
  int get messageFontSize => _messageFontSize;
  String get wallpaper => _wallpaper;

  String get language => _language;

  TgProxy? get proxy => _proxy;

  int get totalUnread => _chats.fold(
    0,
    (sum, chat) => sum + (chat.isMuted ? 0 : chat.unreadCount),
  );

  /// Builds the state with whichever backend the environment allows.
  static Future<AppState> create({
    String databaseDirectory = '',
    String filesDirectory = '',
  }) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on Object catch (error) {
      // No platform channel (unit tests) — run with in-memory preferences.
      debugPrint('Preferences unavailable: $error');
    }

    TelegramClient client = DemoTelegramClient(autoLogin: _demoAutoLogin);

    if (_apiId == 0 || _apiHash.isEmpty) {
      TgDiagnostics.instance.warn(
        'No API credentials compiled in — running the demo backend. Build with '
        '--dart-define=TELEGRAM_API_ID and TELEGRAM_API_HASH for live mode.',
      );
    } else {
      TgDiagnostics.instance.info(
        'API id $_apiId compiled in; starting TDLib.',
      );
    }

    if (_apiId != 0 && _apiHash.isNotEmpty) {
      final live = TdlibTelegramClient(
        apiId: _apiId,
        apiHash: _apiHash,
        databaseDirectory: databaseDirectory,
        filesDirectory: filesDirectory,
      );
      try {
        await live.start();
        client = live;
      } on Object catch (error) {
        // Anything that stops TDLib from starting — a missing library, a bad
        // directory, a failed isolate — falls back to demo rather than
        // presenting a dead login screen, but it is never silent.
        TgDiagnostics.instance.error('TDLib did not start: $error');
        debugPrint('TDLib unavailable, falling back to demo: $error');
        client = DemoTelegramClient(autoLogin: _demoAutoLogin);
        await client.start();
      }
    } else {
      await client.start();
    }

    final state = AppState._(client, prefs);
    state._restore();
    state._attach();
    if (state._proxy != null) await client.applyProxy(state._proxy);

    TgNotifications.instance.setEnabled(state._notifications);
    // Not awaited: it asks for a runtime permission, and the chat list should
    // not sit behind that dialog.
    unawaited(TgNotifications.instance.start(client));
    return state;
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  static const _kReduceTransparency = 'reduce_transparency';
  static const _kReadReceipts = 'read_receipts';
  static const _kAutoNightMode = 'auto_night_mode';
  static const _kNotifications = 'notifications';
  static const _kDarkMode = 'dark_mode';
  static const _kGlassIntensity = 'glass_intensity';
  static const _kMessageFontSize = 'message_font_size';
  static const _kWallpaper = 'wallpaper';
  static const _kLanguage = 'language';
  static const _kProxy = 'proxy';

  void _restore() {
    final prefs = _prefs;
    if (prefs == null) return;
    _reduceTransparency =
        prefs.getBool(_kReduceTransparency) ?? _reduceTransparency;
    _readReceipts = prefs.getBool(_kReadReceipts) ?? _readReceipts;
    _autoNightMode = prefs.getBool(_kAutoNightMode) ?? _autoNightMode;
    _notifications = prefs.getBool(_kNotifications) ?? _notifications;
    _darkMode = prefs.getBool(_kDarkMode) ?? _darkMode;
    _glassIntensity = prefs.getDouble(_kGlassIntensity) ?? _glassIntensity;
    _messageFontSize = prefs.getInt(_kMessageFontSize) ?? _messageFontSize;
    _wallpaper = prefs.getString(_kWallpaper) ?? _wallpaper;
    _language = prefs.getString(_kLanguage) ?? _language;

    final storedProxy = prefs.getString(_kProxy);
    if (storedProxy != null && storedProxy.isNotEmpty) {
      try {
        _proxy = TgProxy.fromJson(
          jsonDecode(storedProxy) as Map<String, dynamic>,
        );
      } on FormatException {
        _proxy = null;
      }
    }
  }

  void _attach() {
    _chats = client.currentChats;
    _stage = client.currentStage;
    _subscriptions
      ..add(
        client.authStage.listen((stage) {
          _stage = stage;
          notifyListeners();
        }),
      )
      ..add(
        client.chats.listen((chats) {
          _chats = chats;
          notifyListeners();
        }),
      )
      ..add(
        client.typingChatId.listen((chatId) {
          _typingChatId = chatId;
          notifyListeners();
        }),
      );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    client.dispose();
    super.dispose();
  }

  // ── Chat list ─────────────────────────────────────────────────────────────

  void setFolder(String id) {
    if (_activeFolder == id) return;
    _activeFolder = id;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Chats after folder and search filtering, pinned first.
  List<TgChat> get visibleChats {
    Iterable<TgChat> result = _chats;

    // The archive is a list of its own and never shows in the chat list.
    if (_activeFolder == 'archive') {
      result = result.where((c) => c.isArchived);
    } else {
      result = result.where((c) => !c.isArchived);
    }

    if (_activeFolder.startsWith('folder:')) {
      result = result.where((c) => c.lists.contains(_activeFolder));
    }

    switch (_activeFolder) {
      case 'personal':
        result = result.where(
          (c) => c.kind == TgChatKind.private || c.kind == TgChatKind.saved,
        );
      case 'groups':
        result = result.where((c) => c.kind == TgChatKind.group);
      case 'channels':
        result = result.where((c) => c.kind == TgChatKind.channel);
      case 'bots':
        result = result.where((c) => c.kind == TgChatKind.bot);
      case 'unread':
        result = result.where((c) => c.unreadCount > 0);
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where(
        (c) =>
            c.title.toLowerCase().contains(query) ||
            (c.lastMessage ?? '').toLowerCase().contains(query),
      );
    }

    return result.toList();
  }

  int unreadInFolder(String id) {
    final previous = _activeFolder;
    _activeFolder = id;
    final count = visibleChats.fold<int>(
      0,
      (sum, chat) => sum + (chat.isMuted ? 0 : chat.unreadCount),
    );
    _activeFolder = previous;
    return count;
  }

  /// Chats the account has archived, newest first. Shown on their own screen,
  /// reached from the row above the chat list.
  List<TgChat> get archivedChats =>
      _chats.where((chat) => chat.isArchived).toList();

  TgChat? chatById(int id) {
    for (final chat in _chats) {
      if (chat.id == id) return chat;
    }
    return null;
  }

  // ── Preferences ───────────────────────────────────────────────────────────

  void setReduceTransparency(bool value) {
    _reduceTransparency = value;
    _prefs?.setBool(_kReduceTransparency, value);
    notifyListeners();
  }

  void setReadReceipts(bool value) {
    _readReceipts = value;
    _prefs?.setBool(_kReadReceipts, value);
    notifyListeners();
  }

  void setNotifications(bool value) {
    _notifications = value;
    _prefs?.setBool(_kNotifications, value);
    TgNotifications.instance.setEnabled(value);
    notifyListeners();
  }

  void setAutoNightMode(bool value) {
    _autoNightMode = value;
    _prefs?.setBool(_kAutoNightMode, value);
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _darkMode = value;
    _prefs?.setBool(_kDarkMode, value);
    notifyListeners();
  }

  void setGlassIntensity(double value) {
    _glassIntensity = value;
    _prefs?.setDouble(_kGlassIntensity, value);
    notifyListeners();
  }

  void setMessageFontSize(int value) {
    _messageFontSize = value.clamp(12, 22);
    _prefs?.setInt(_kMessageFontSize, _messageFontSize);
    notifyListeners();
  }

  void setWallpaper(String value) {
    _wallpaper = value;
    _prefs?.setString(_kWallpaper, value);
    notifyListeners();
  }

  /// Stores the proxy and hands it to the backend straight away.
  void setProxy(TgProxy? value) {
    _proxy = value;
    if (value == null) {
      _prefs?.remove(_kProxy);
    } else {
      _prefs?.setString(_kProxy, jsonEncode(value.toJson()));
    }
    client.applyProxy(value);
    notifyListeners();
  }

  void setLanguage(String value) {
    _language = value;
    _prefs?.setString(_kLanguage, value);
    notifyListeners();
  }

  /// Saves a draft locally and pushes it to the backend.
  void setDraft(int chatId, String text) {
    client.setDraft(chatId, text);
  }
}
