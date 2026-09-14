import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'diagnostics.dart';

/// The app's single audio player.
///
/// Telegram plays one voice note or track at a time, and starting a second one
/// stops the first — so there is one player, and every bubble asks this object
/// whether it is the one currently sounding.
class TgAudio extends ChangeNotifier {
  TgAudio._() {
    _player.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Leave the bubble showing a full bar for a moment, then reset it the
        // way the official clients do.
        _player.pause();
        _player.seek(Duration.zero);
      }
      notifyListeners();
    });
    _player.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });
  }

  static final instance = TgAudio._();

  final _player = AudioPlayer();

  int? _messageId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// The message whose audio is loaded, playing or paused.
  int? get currentMessageId => _messageId;

  bool get isPlaying => _player.playing;

  Duration get position => _position;

  /// Length of the loaded track. Falls back to zero before it is known.
  Duration get duration => _duration;

  /// 0..1 through the loaded track, for the message that owns it.
  double progressFor(int messageId) {
    if (_messageId != messageId) return 0;
    final total = _duration.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  bool isPlayingMessage(int messageId) =>
      _messageId == messageId && _player.playing;

  /// Plays [path] for [messageId], or pauses it if it is already sounding.
  Future<void> toggle(int messageId, String path) async {
    try {
      if (_messageId == messageId) {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }
        notifyListeners();
        return;
      }

      _messageId = messageId;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();

      await _player.setFilePath(path);
      await _player.play();
    } on Object catch (error) {
      // A codec the device cannot decode, or a file that vanished. Say so in
      // the log rather than leaving a bubble stuck mid-tap.
      TgDiagnostics.instance.error('Playback failed: $error');
      _messageId = null;
      notifyListeners();
    }
  }

  /// Seeks within the loaded track, as a 0..1 fraction of its length.
  Future<void> seekFraction(int messageId, double fraction) async {
    if (_messageId != messageId || _duration == Duration.zero) return;
    await _player.seek(_duration * fraction.clamp(0.0, 1.0));
  }

  Future<void> stop() async {
    await _player.stop();
    _messageId = null;
    _position = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
