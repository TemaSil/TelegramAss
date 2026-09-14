import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'diagnostics.dart';
import 'models.dart';
import 'telegram_client.dart';

/// Shows a system notification for every incoming message, and keeps the
/// process alive so they arrive while the app is closed.
///
/// TDLib only delivers updates while it is running, and Android will reclaim a
/// backgrounded process at will — so without a foreground service messages
/// only appear when the app is open. This is the route that needs no Firebase
/// project: a service holds the connection, and each new message becomes a
/// local notification.
class TgNotifications {
  TgNotifications._();

  static final instance = TgNotifications._();

  static const _channelId = 'messages';
  static const _serviceChannelId = 'connection';

  final _plugin = FlutterLocalNotificationsPlugin();

  StreamSubscription<TgMessage>? _subscription;
  TelegramClient? _client;

  /// Chat the user is looking at; its messages are not announced.
  int? _openChatId;

  bool _enabled = true;
  bool _started = false;

  /// Called when the user taps a notification, with the chat it belongs to.
  void Function(int chatId)? onOpenChat;

  /// Tells the service which conversation is on screen. Its pending
  /// notification is dismissed — the user has just read it.
  void setOpenChat(int? chatId) {
    _openChatId = chatId;
    if (chatId != null) _plugin.cancel(id: chatId.hashCode);
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) _plugin.cancelAll();
  }

  /// Wires everything up. Safe to call when the platform cannot support it —
  /// on the web, or when the user refuses the permission — in which case the
  /// app simply runs without notifications.
  Future<void> start(TelegramClient client) async {
    if (kIsWeb || _started) return;
    _started = true;
    _client = client;

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final chatId = int.tryParse(response.payload ?? '');
          if (chatId != null) onOpenChat?.call(chatId);
        },
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();

      await _startService();
    } on Object catch (error) {
      TgDiagnostics.instance.error('Notifications unavailable: $error');
      return;
    }

    _listen(client);
    TgDiagnostics.instance.info('Notifications ready.');
  }

  Future<void> _startService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _serviceChannelId,
        channelName: 'Connection',
        channelDescription: 'Keeps Telegram connected while the app is closed.',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );

    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      notificationTitle: 'Telegram Liquid',
      notificationText: 'Connected',
    );
  }

  /// Announces messages from every chat at once: a per-chat stream would only
  /// cover conversations the user has already opened.
  void _listen(TelegramClient client) {
    _subscription?.cancel();
    _subscription = client.incomingMessages.listen(_announce);
  }

  Future<void> _announce(TgMessage message) async {
    if (!_enabled) return;
    if (message.isOutgoing) return;
    if (message.chatId == _openChatId) return;
    if (message.kind == TgMessageKind.service) return;

    TgChat? chat;
    for (final candidate in _client?.currentChats ?? const <TgChat>[]) {
      if (candidate.id == message.chatId) {
        chat = candidate;
        break;
      }
    }
    if (chat == null || chat.isMuted) return;

    final trimmed = message.text.trim();
    final body = trimmed.isEmpty ? _placeholderFor(message.kind) : trimmed;

    await _plugin.show(
      // One notification per chat, replaced as newer messages arrive, so a
      // busy group cannot bury the rest of the shade.
      id: message.chatId.hashCode,
      title: chat.title,
      body: message.senderName == null ? body : '${message.senderName}: $body',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Messages',
          channelDescription: 'New messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: '${message.chatId}',
    );
  }

  static String _placeholderFor(TgMessageKind kind) {
    switch (kind) {
      case TgMessageKind.photo:
        return '📷 Photo';
      case TgMessageKind.video:
        return '🎬 Video';
      case TgMessageKind.voice:
        return '🎤 Voice message';
      case TgMessageKind.audio:
        return '🎵 Audio';
      case TgMessageKind.file:
        return '📎 File';
      case TgMessageKind.sticker:
        return '🎨 Sticker';
      case TgMessageKind.service:
      case TgMessageKind.text:
        return '';
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!kIsWeb) await FlutterForegroundTask.stopService();
  }
}
