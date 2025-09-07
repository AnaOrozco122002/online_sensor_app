// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Servicio WebSocket con:
/// - Conexión persistente y reintentos
/// - RPC simple (cola de requests -> responses)
/// - Envío de ventanas con id_usuario (int) y session_id (int?)
/// - Callback onConnectionChange(bool) para la UI
class WebSocketService {
  final Uri _uri = Uri.parse('wss://online-sensor-backend.onrender.com');
  late WebSocketChannel _channel;

  // Cola de completers: cada sendRpc espera el próximo mensaje como respuesta.
  final List<Completer<dynamic>> _pending = [];

  bool _connected = false;
  bool get isConnected => _connected;

  /// Callback opcional para notificar cambios de conexión
  void Function(bool connected)? onConnectionChange;

  WebSocketService() {
    _connect();
  }

  void _setConnected(bool c) {
    _connected = c;
    if (onConnectionChange != null) {
      onConnectionChange!(c);
    }
  }

  void _connect() {
    _channel = WebSocketChannel.connect(_uri);
    _setConnected(true);

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
        _setConnected(false);
        // Reintento simple
        Future.delayed(const Duration(seconds: 2), () {
          if (!_connected) _connect();
        });
      },
      onError: (e, st) {
        _setConnected(false);
        // Completa cualquier RPC pendiente con error
        while (_pending.isNotEmpty) {
          final c = _pending.removeAt(0);
          if (!c.isCompleted) c.completeError(e, st);
        }
        // Reintento
        Future.delayed(const Duration(seconds: 2), () {
          if (!_connected) _connect();
        });
      },
      cancelOnError: true,
    );
  }

  /// Envía un RPC y espera una única respuesta del servidor.
  Future<dynamic> sendRpc(Map<String, dynamic> payload) {
    if (!_connected) {
      return Future.error('WS no conectado');
    }
    // Validar que 'type' sea String (evita "type is not a subtype of String")
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

  /// Envía una ventana ya serializada (windowJson) con tipos correctos.
  /// - idUsuario: debe ser INT (no string)
  /// - sessionId: INT o null
  /// - activity: opcional
  Future<void> sendWindow({
    required Map<String, dynamic> windowJson,
    required int idUsuario,
    int? sessionId,
    String? activity,
  }) async {
    if (!_connected) throw StateError('WS no conectado');

    final payload = Map<String, dynamic>.from(windowJson);
    payload['id_usuario'] = idUsuario; // int (CORRECTO)
    if (sessionId != null) payload['session_id'] = sessionId; // int
    if (activity != null) payload['activity'] = activity;

    _channel.sink.add(jsonEncode(payload));
  }

  Future<void> close() async {
    try {
      await _channel.sink.close();
    } catch (_) {}
    _setConnected(false);
  }
}
