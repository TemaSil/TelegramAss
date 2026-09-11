/// Date and size helpers shared by the chat list and the conversation view.
class TgFormat {
  TgFormat._();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `14:05` — used inside bubbles and next to a chat row.
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  /// Chat-list stamp: time today, weekday this week, date beyond that.
  static String listStamp(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) return time(date);

    final difference = now.difference(date);
    if (difference.inDays < 7) return _weekdays[date.weekday - 1];
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.'
        '${date.year % 100}';
  }

  /// Day separator inside a conversation.
  static String daySeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return _weekdays[date.weekday - 1];
    return '${_months[date.month - 1]} ${date.day}';
  }

  /// `2:31` for a voice message or a call duration.
  static String duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String callStamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 24) return time(date);
    if (diff.inDays == 1) return 'Yesterday';
    return '${_months[date.month - 1]} ${date.day}';
  }
}
