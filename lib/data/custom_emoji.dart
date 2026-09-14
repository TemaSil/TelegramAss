import 'package:flutter/foundation.dart';

import 'telegram_client.dart';

/// Keeps the custom-emoji stickers the app has fetched, so text can draw them.
///
/// Emoji resolve asynchronously and appear in many messages at once, so the
/// lookup has to be synchronous from a build and the arrival has to rebuild
/// whoever is showing one. A [ChangeNotifier] does both: [pathFor] answers
/// from the cache and starts a fetch on a miss, and listeners rebuild when
/// the file lands.
class TgCustomEmoji extends ChangeNotifier {
  TgCustomEmoji._();

  static final instance = TgCustomEmoji._();

  TelegramClient? _client;
  final _paths = <String, String>{};
  final _pending = <String>{};

  void attach(TelegramClient client) {
    _client = client;
    _paths.clear();
    _pending.clear();
  }

  /// The sticker file for [id], or null while it is not here yet.
  String? pathFor(String id) {
    final known = _paths[id];
    if (known != null) return known;
    _fetch(id);
    return null;
  }

  Future<void> _fetch(String id) async {
    final client = _client;
    if (client == null || !_pending.add(id)) return;

    final path = await client.customEmojiFile(id);
    if (path == null) {
      // Either the download is still running — in which case the next build
      // asks again — or this emoji is a format we cannot draw.
      _pending.remove(id);
      return;
    }
    _paths[id] = path;
    _pending.remove(id);
    notifyListeners();
  }
}
