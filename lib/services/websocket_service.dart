// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../models/sensor_window.dart';

class WebSocketService {
  static const String _wsUrl = 'wss://online-sensor-backend.onrender.com';
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(seconds: 2);

  WebSocketService() {
    _connect();
  }

  void _log(String m) { if (kDebugMode) print('[WS] $m'); }

  void _connect() {
    if (_isConnecting) return;
    _isConnecting = true;
    _cancelReconnectTimer();

    _log('Conectando a $_wsUrl ...');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _sub = _channel!.stream.listen(
            (event) { _isConnected = true; _log('<- $event'); },
        onError: (e) { _isConnected = false; _log('error: $e'); _scheduleReconnect(); },
        onDone: () { _isConnected = false; _log('cerrado'); _scheduleReconnect(); },
        cancelOnError: true,
      );
      _isConnecting = false;
      _log('Conectado ✅');
    } catch (e) {
      _isConnecting = false; _isConnected = false;
      _log('excepción al conectar: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    final delay = _backoff;
    _backoff = Duration(seconds: (_backoff.inSeconds * 2).clamp(2, 30));
    _log('reintento en ${delay.inSeconds}s ...');
    _reconnectTimer = Timer(delay, () { _reconnectTimer = null; _connect(); });
  }

  void _cancelReconnectTimer() { _reconnectTimer?.cancel(); _reconnectTimer = null; _backoff = const Duration(seconds: 2); }

  bool get isConnected => _isConnected;

  void sendWindow(SensorWindow window, {String? activity, required String userId}) {
    final ch = _channel;
    if (ch == null) { _log('canal nulo; reconectar'); _connect(); return; }
    final payload = window.toJson(activity: activity, userId: userId);
    final data = jsonEncode(payload);
    try {
      ch.sink.add(data);
      _log('-> ventana (${window.sampleCount} muestras, act=$activity, uid=$userId)');
    } catch (e) {
      _isConnected = false; _log('error al enviar: $e'); _scheduleReconnect();
    }
  }

  Future<void> dispose() async {
    _cancelReconnectTimer();
    await _sub?.cancel();
    try { await _channel?.sink.close(ws_status.normalClosure); } catch (_) {}
    _channel = null; _isConnected = false; _log('dispose');
  }
}
