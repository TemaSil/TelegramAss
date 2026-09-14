import 'dart:async';
import 'dart:collection';

/// A small in-app log.
///
/// The TDLib backend fails in ways the user cannot otherwise see: the native
/// library may not load, `setTdlibParameters` may be rejected, a request may
/// time out. Without a log, all of that looks identical from the login screen —
/// "nothing happens". This keeps the last few hundred lines so the app can show
/// them, which is far more useful than a silent fallback to demo data.
class TgDiagnostics {
  TgDiagnostics._();

  static final instance = TgDiagnostics._();

  static const _limit = 300;

  final _lines = Queue<TgLogLine>();
  final _controller = StreamController<TgLogLine>.broadcast();

  List<TgLogLine> get lines => List.unmodifiable(_lines);

  Stream<TgLogLine> get stream => _controller.stream;

  /// The most recent failure, for the banner on the login screen.
  TgLogLine? get lastError {
    for (final line in _lines.toList().reversed) {
      if (line.level == TgLogLevel.error) return line;
    }
    return null;
  }

  void info(String message) => _add(TgLogLevel.info, message);

  void warn(String message) => _add(TgLogLevel.warning, message);

  void error(String message) => _add(TgLogLevel.error, message);

  void _add(TgLogLevel level, String message) {
    final line = TgLogLine(level: level, message: message, at: DateTime.now());
    _lines.add(line);
    while (_lines.length > _limit) {
      _lines.removeFirst();
    }
    if (!_controller.isClosed) _controller.add(line);
  }

  void clear() => _lines.clear();

  /// The whole log as text, for sharing or pasting into a bug report.
  String asText() => _lines
      .map(
        (line) =>
            '${line.stamp}  ${line.level.name.toUpperCase()}  '
            '${line.message}',
      )
      .join('\n');
}

enum TgLogLevel { info, warning, error }

class TgLogLine {
  const TgLogLine({
    required this.level,
    required this.message,
    required this.at,
  });

  final TgLogLevel level;
  final String message;
  final DateTime at;

  String get stamp =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}';
}
