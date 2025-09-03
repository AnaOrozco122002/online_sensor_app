// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../models/sensor_window.dart';

class WebSocketService {
  // ---- Config ----
  static const String _wsUrl = 'wss://online-sensor-backend.onrender.com';
  // Si tu server expone ruta, usa '/ws':  'wss://.../ws'

  // ---- Estado ----
  WebSocketChannel? _channel;   // ya NO es final
  StreamSubscription? _sub;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(seconds: 2);

  WebSocketService() {
    _connect();
  }

  void _connect() {
    if (_isConnecting) return;
    _isConnecting = true;

    // Limpia un intento previo
    _cancelReconnectTimer();

    try {
      // Abre el canal
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      // Escucha el stream del servidor (ACKs / mensajes)
      _sub = _channel!.stream.listen(
            (event) {
          _isConnected = true;
          // Prints de diagnóstico, puedes cambiar por debugPrint
          // print('WS <- $event');
        },
        onError: (e) {
          _isConnected = false;
          // print('WS error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          // print('WS closed: code=${_channel?.closeCode}, reason=${_channel?.closeReason}');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _isConnecting = false;
      // print('WS connected: $_wsUrl');

    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      // print('WS connect exception: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return; // ya hay uno programado

    // Backoff exponencial simple (max ~30s)
    final delay = _backoff;
    _backoff = Duration(seconds: (_backoff.inSeconds * 2).clamp(2, 30));

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _connect();
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _backoff = const Duration(seconds: 2);
  }

  bool get isConnected => _isConnected;

  void sendWindow(SensorWindow window, {String? activity}) {
    final ch = _channel;
    if (ch == null) {
      // Canal no inicializado aún → intenta conectar
      _connect();
      return;
    }

    final payload = window.toJson(activity: activity);
    final data = jsonEncode(payload);

    try {
      ch.sink.add(data);
      // print('WS -> window sent (${window.sampleCount} samples, act=$activity)');
    } catch (e) {
      // print('WS send error: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  Future<void> dispose() async {
    _cancelReconnectTimer();
    await _sub?.cancel();
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
    _isConnected = false;
  }
}
