import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Debug-mode NDJSON logger for session 12ae67.
class DebugSessionLog {
  static const sessionId = '12ae67';
  static const logFileName = 'debug-12ae67.log';

  static void log({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
  }) {
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final line = jsonEncode(payload);
    debugPrint('[DEBUG-$sessionId] $line');
    _appendToHostLog(line);
  }

  static void _appendToHostLog(String line) {
    try {
      final candidates = [
        if (Platform.environment['CURSOR_WORKSPACE'] != null)
          '${Platform.environment['CURSOR_WORKSPACE']}/$logFileName',
        r'C:\Users\himan\Desktop\Prism clone\Prism\debug-12ae67.log',
        if (Platform.environment['USERPROFILE'] != null)
          '${Platform.environment['USERPROFILE']}/Desktop/Prism clone/Prism/$logFileName',
      ];
      for (final path in candidates) {
        if (path.isEmpty) continue;
        final file = File(path);
        if (file.parent.existsSync()) {
          file.writeAsStringSync('$line\n', mode: FileMode.append);
          return;
        }
      }
    } catch (_) {
      // Mobile may only reach terminal via debugPrint.
    }
  }
}
