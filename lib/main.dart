// lib/main.dart
import 'package:flutter/material.dart';
import 'controllers/sensor_controller.dart';
import 'models/sensor_window.dart';
import 'services/websocket_service.dart';
import 'widgets/activity_dialog.dart';
import 'services/user_prefs.dart';
import 'screens/login_screen.dart';

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
      home: const Bootstrap(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  String? _userId;
  String? _userName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await UserPrefs.getUserId();
    final name = await UserPrefs.getUserName();
    setState(() {
      _userId = id;
      _userName = name;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_userId == null) {
      return LoginScreen(onLoggedIn: () async { await _load(); });
    }
    return SensorApp(userId: _userId!, userName: _userName);
  }
}

class SensorApp extends StatefulWidget {
  const SensorApp({super.key, required this.userId, this.userName});
  final String userId;
  final String? userName;

  @override
  State<SensorApp> createState() => _SensorAppState();
}

class _SensorAppState extends State<SensorApp> {
  final SensorController _controller = SensorController();
  final WebSocketService _wsService = WebSocketService();

  String _status = 'Esperando ventanas...';
  String? _currentActivity;
  DateTime? _lastSentAt;
  bool _isChoosing = false;

  @override
  void initState() {
    super.initState();

    _controller.onWindowReady = (SensorWindow window) async {
      if (_currentActivity == null) {
        if (_isChoosing) return;
        _isChoosing = true;
        final activity = await showActivityDialog(context);
        _isChoosing = false;
        if (activity == null) return;
        setState(() => _currentActivity = activity);
      }

      _wsService.sendWindow(window, activity: _currentActivity, userId: widget.userId);

      setState(() {
        _lastSentAt = DateTime.now();
        _status = 'Ventana enviada (${window.sampleCount} muestras) | act: ${_currentActivity} | uid: ${widget.userId}';
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
      appBar: AppBar(title: const Text('DataStep - Ventanas 2s'), actions: [
        IconButton(
          onPressed: () async {
            await UserPrefs.logout();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const Bootstrap()),
                    (_) => false,
              );
            }
          },
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar sesión',
        )
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_status),
            const SizedBox(height: 8),
            Text('Usuario: ${widget.userId}${widget.userName != null ? " (${widget.userName})" : ""}'),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Actividad actual: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_currentActivity ?? '— (sin seleccionar)'),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Último envío: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(lastTime),
            ]),
            const Spacer(),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(
                onPressed: () async {
                  final act = await showActivityDialog(context);
                  if (act != null) setState(() => _currentActivity = act);
                },
                child: const Text('Cambiar actividad'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _currentActivity = null),
                child: const Text('Borrar actividad'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
