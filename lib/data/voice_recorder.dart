import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'diagnostics.dart';

/// What a finished recording produced.
typedef TgRecording = ({String path, int seconds, bool isOpus});

/// Records a voice message.
///
/// Telegram's own voice notes are OGG/Opus, which is what TDLib's
/// `inputMessageVoiceNote` expects. Not every Android build can encode it —
/// the platform only gained an OGG container at API 29 — so the encoder is
/// probed once and the recording falls back to AAC, which is then sent as an
/// audio file rather than a voice note. A slightly different bubble beats a
/// button that does nothing.
class TgVoiceRecorder {
  TgVoiceRecorder._();

  static final instance = TgVoiceRecorder._();

  final _recorder = AudioRecorder();

  DateTime? _startedAt;
  String? _path;
  bool _isOpus = false;

  bool get isRecording => _startedAt != null;

  /// How long the take has been running, for the composer's timer.
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Returns false when the microphone permission was refused, or when the
  /// device has no usable encoder.
  Future<bool> start() async {
    if (isRecording) return true;
    try {
      if (!await _recorder.hasPermission()) return false;

      _isOpus = await _recorder.isEncoderSupported(AudioEncoder.opus);
      final directory = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/voice_$stamp.${_isOpus ? 'ogg' : 'm4a'}';

      await _recorder.start(
        RecordConfig(
          encoder: _isOpus ? AudioEncoder.opus : AudioEncoder.aacLc,
          // Voice, not music: mono at 48k is what Telegram itself sends, and
          // it keeps a minute-long note well under a megabyte.
          bitRate: 32000,
          sampleRate: 48000,
          numChannels: 1,
          noiseSuppress: true,
          echoCancel: true,
        ),
        path: path,
      );

      _path = path;
      _startedAt = DateTime.now();
      return true;
    } on Object catch (error) {
      TgDiagnostics.instance.error('Could not start recording: $error');
      await _reset();
      return false;
    }
  }

  /// Ends the take. Returns null if it was too short to be meant, in which
  /// case the file is discarded.
  Future<TgRecording?> stop() async {
    if (!isRecording) return null;
    final seconds = elapsed.inSeconds;
    final isOpus = _isOpus;

    String? path;
    try {
      path = await _recorder.stop();
    } on Object catch (error) {
      TgDiagnostics.instance.error('Could not stop recording: $error');
    }
    path ??= _path;
    await _reset();

    if (path == null) return null;
    if (seconds < 1) {
      await _discard(path);
      return null;
    }
    return (path: path, seconds: seconds, isOpus: isOpus);
  }

  /// Abandons the take and deletes the file — the slide-to-cancel gesture.
  Future<void> cancel() async {
    if (!isRecording) return;
    final path = _path;
    try {
      await _recorder.stop();
    } on Object catch (_) {
      // Nothing to salvage; the file is going away either way.
    }
    await _reset();
    if (path != null) await _discard(path);
  }

  Future<void> _reset() async {
    _startedAt = null;
    _path = null;
  }

  static Future<void> _discard(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on Object catch (_) {
      // A leftover file in the cache directory is not worth reporting.
    }
  }
}
