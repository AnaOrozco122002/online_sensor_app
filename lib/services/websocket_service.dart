// lib/services/websocket_service.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/sensor_window.dart';

class WebSocketService {
  late final WebSocketChannel _channel;
  bool _connected = false;

  WebSocketService() {
    _connect();
  }

  void _connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://online-sensor-backend.onrender.com'),
      // Si tu servidor usara una ruta específica: .../ws
      // Uri.parse('wss://online-sensor-backend.onrender.com/ws'),
    );

    // Escucha mensajes del servidor (ACKs, etc.)
    _channel.stream.listen((event) {
      _connected = true;
      // Log del mensaje recibido del servidor
      // (tu server envía {"ok": true} tras procesar)
      // Puedes reemplazar por print si prefieres
      // debugPrint('WS <- $event');
    }, onError: (e) {
      _connected = false;
      // debugPrint('WS error: $e');
    }, onDone: () {
      _connected = false;
      // debugPrint('WS cerrado (code=${_channel.closeCode}, reason=${_channel.closeReason})');
      // Reintento simple:
      Future.delayed(const Duration(seconds: 2), _connect);
    });
  }

  void sendWindow(SensorWindow window, {String? activity}) {
    final payload = window.toJson(activity: activity);
    final data = jsonEncode(payload);
    if (_connected) {
      _channel.sink.add(data);
    } else {
      // Intento “optimista”: envío igual; si falla, se reintenta por reconexión
      try {
        _channel.sink.add(data);
      } catch (_) {
        // podrías encolar y reintentar en _connect()
      }
    }
  }

  void dispose() {
    _channel.sink.close(status.normalClosure);
  }
}
