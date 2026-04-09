import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final timeStr = DateFormat('HH:mm:ss.SSS').format(timestamp);
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag.padRight(20);
    return '[$timeStr] $levelStr [$tagStr] $message';
  }
}

class AppLogger {
  static final List<LogEntry> _logs = [];
  static const int _maxLogs = 500;

  static List<LogEntry> get logs => List.unmodifiable(_logs);

  static void i(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  static void w(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  static void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, tag, message, error: error?.toString(), stackTrace: stackTrace?.toString());
  }

  static void _log(LogLevel level, String tag, String message, {String? error, String? stackTrace}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.insert(0, entry);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }

    debugPrint(entry.toString());
    if (error != null) debugPrint('Error: $error');
    if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
  }

  static String copyableText() {
    return _logs.reversed.map((e) {
      var text = e.toString();
      if (e.error != null) text += '\nError: ${e.error}';
      if (e.stackTrace != null) text += '\nStackTrace: ${e.stackTrace}';
      return text;
    }).join('\n');
  }

  static void clear() {
    _logs.clear();
  }
}
