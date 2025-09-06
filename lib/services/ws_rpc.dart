import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<Map<String, dynamic>> wsRpc(Map<String, dynamic> payload,
    {String url = 'wss://online-sensor-backend.onrender.com', Duration timeout = const Duration(seconds: 12)}) async {
  final ch = WebSocketChannel.connect(Uri.parse(url));
  final c = Completer<Map<String, dynamic>>();
  late StreamSubscription sub;

  sub = ch.stream.listen((event) {
    try {
      final obj = json.decode(event);
      if (obj is Map<String, dynamic>) {
        if (!c.isCompleted) c.complete(obj);
      } else if (obj is List && obj.isNotEmpty && obj[0] is Map) {
        if (!c.isCompleted) c.complete(obj[0] as Map<String, dynamic>);
      }
    } catch (_) {}
  }, onError: (e) {
    if (!c.isCompleted) c.completeError(e);
  }, onDone: () {
    if (!c.isCompleted) c.completeError(TimeoutException('WS closed'));
  });

  ch.sink.add(json.encode(payload));

  try {
    final res = await c.future.timeout(timeout);
    await sub.cancel();
    await ch.sink.close();
    return res;
  } catch (e) {
    await sub.cancel();
    try { await ch.sink.close(); } catch (_) {}
    rethrow;
  }
}
