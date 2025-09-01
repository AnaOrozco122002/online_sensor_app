import 'package:flutter/material.dart';
import 'controllers/sensor_controller.dart';
import 'models/sensor_window.dart';
import 'services/websocket_service.dart';
import 'widgets/activity_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataStep',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SensorApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SensorApp extends StatefulWidget {
  const SensorApp({super.key});

  @override
  State<SensorApp> createState() => _SensorAppState();
}

class _SensorAppState extends State<SensorApp> {
  final SensorController _controller = SensorController();
  final WebSocketService _wsService = WebSocketService();

  String _status = 'Esperando ventanas...';
  String? _currentActivity; // Actividad seleccionada
  DateTime? _lastSentAt;

  bool _isChoosing = false; // evita abrir múltiples diálogos

  @override
  void initState() {
    super.initState();

    _controller.onWindowReady = (SensorWindow window) async {
      // Si aún no hay actividad → preguntar UNA VEZ
      if (_currentActivity == null) {
        if (_isChoosing) return;
        _isChoosing = true;
        final activity = await showActivityDialog(context);
        _isChoosing = false;
        if (activity == null) return; // usuario canceló
        setState(() => _currentActivity = activity);
      }

      // Usar la actividad actual para enviar ventana
      final activityToSend = _currentActivity!;
      _wsService.sendWindow(window, activity: activityToSend);

      setState(() {
        _lastSentAt = DateTime.now();
        _status =
        'Ventana enviada (${window.sampleCount} muestras) | actividad: $activityToSend';
      });
    };

    _controller.startListening();
  }

  @override
  void dispose() {
    _controller.stopListening();
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastTime = _lastSentAt != null
        ? '${_lastSentAt!.hour.toString().padLeft(2, '0')}:${_lastSentAt!.minute.toString().padLeft(2, '0')}:${_lastSentAt!.second.toString().padLeft(2, '0')}'
        : '-';

    return Scaffold(
      appBar: AppBar(title: const Text('DataStep - Ventanas 2s')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_status),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Actividad actual: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_currentActivity ?? '— (sin seleccionar)'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Último envío: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(lastTime),
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () async {
                    final act = await showActivityDialog(context);
                    if (act != null) {
                      setState(() => _currentActivity = act);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Actividad cambiada a "$act"')),
                      );
                    }
                  },
                  child: const Text('Cambiar actividad'),
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _currentActivity = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Actividad borrada')),
                    );
                  },
                  child: const Text('Borrar actividad'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
