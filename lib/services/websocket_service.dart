// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final Uri _uri = Uri.parse('wss://online-sensor-backend.onrender.com');
  late WebSocketChannel _channel;

  final List<Completer<dynamic>> _pending = [];
  bool _connected = false;
  bool get isConnected => _connected;

  WebSocketService() {
    _connect();
  }

  void _connect() {
    _channel = WebSocketChannel.connect(_uri);
    _connected = true;

    _channel.stream.listen(
          (message) {
        dynamic decoded;
        try {
          decoded = jsonDecode(message);
        } catch (_) {
          decoded = message;
        }
        if (_pending.isNotEmpty) {
          final c = _pending.removeAt(0);
          if (!c.isCompleted) c.complete(decoded);
        }
      },
      onDone: () {
        _connected = false;
        Future.delayed(const Duration(seconds: 2), () {
          if (!_connected) _connect();
        });
      },
      onError: (e, st) {
        _connected = false;
        while (_pending.isNotEmpty) {
          final c = _pending.removeAt(0);
          if (!c.isCompleted) c.completeError(e, st);
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (!_connected) _connect();
        });
      },
      cancelOnError: true,
    );
  }

  Future<dynamic> sendRpc(Map<String, dynamic> payload) {
    if (!_connected) {
      return Future.error('WS no conectado');
    }
    final t = payload['type'];
    if (t is! String) {
      return Future.error("RPC 'type' debe ser String");
    }

    final completer = Completer<dynamic>();
    _pending.add(completer);

    try {
      _channel.sink.add(jsonEncode(payload));
    } catch (e, st) {
      _pending.remove(completer);
      completer.completeError(e, st);
    }
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        if (!completer.isCompleted) {
          _pending.remove(completer);
          throw TimeoutException('RPC timeout');
        }
        return null;
      },
    );
  }

  Future<void> sendWindow({
    required Map<String, dynamic> windowJson,
    required int idUsuario,
    int? sessionId,
  }) async {
    if (!_connected) throw StateError('WS no conectado');

    final payload = Map<String, dynamic>.from(windowJson);
    payload['id_usuario'] = idUsuario;
    if (sessionId != null) payload['session_id'] = sessionId;

    _channel.sink.add(jsonEncode(payload));
  }

  Future<void> close() async {
    try {
      await _channel.sink.close();
    } catch (_) {}
    _connected = false;
  }
}
