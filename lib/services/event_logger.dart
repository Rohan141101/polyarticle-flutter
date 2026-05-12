import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'session_storage.dart';

const _apiUrl = 'https://polyarticle-app.onrender.com';
const _maxBatch = 5;
const _batchIntervalMs = 5000;
const _minDwellMs = 300;

typedef EventType = String;

class _Event {
  final String type;
  final String articleId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _Event({
    required this.type,
    required this.articleId,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type,
        'articleId': articleId,
        'timestamp': timestamp.toIso8601String(),
        ...data,
      };
}

class EventLogger {
  final List<_Event> _queue = [];
  String _sessionId = _generateSessionId();
  String? _token;
  Timer? _timer;
  bool _isSending = false;

  static String _generateSessionId() {
    final rand = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${rand.nextInt(999999)}';
  }

  void setToken(String? token) {
    if (token == null) {
      _queue.clear();
      _sessionId = _generateSessionId();
    }
    _token = token;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: _batchIntervalMs),
      (_) => _flush(),
    );
  }

  void log(
    EventType type,
    String articleId, {
    Map<String, dynamic> extra = const {},
  }) {
    if (type == 'impression') {
      final dwell = extra['dwellMs'] as int? ?? 0;
      if (dwell < _minDwellMs) return;
    }

    _queue.add(_Event(type: type, articleId: articleId, data: extra));
    _startTimer();

    if (_queue.length >= _maxBatch) {
      _flush();
    }
  }

  Future<void> _flush() async {
    if (_queue.isEmpty || _isSending) return;

    final authToken = _token ?? await getSession();
    if (authToken == null || authToken.isEmpty) return;

    final batch = List<_Event>.from(_queue);
    _queue.clear();
    _isSending = true;

    try {
      await http
          .post(
            Uri.parse('$_apiUrl/events'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: json.encode({
              'sessionId': _sessionId,
              'events': batch.map((e) => e.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      _queue.insertAll(0, batch);
    } finally {
      _isSending = false;
    }
  }

  Future<void> forceFlush() => _flush();

  void dispose() {
    _timer?.cancel();
  }
}

final eventLogger = EventLogger();
