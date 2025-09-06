import 'package:flutter/material.dart';
import 'controllers/sensor_controller.dart';
import 'models/sensor_window.dart';
import 'services/websocket_service.dart';
import 'widgets/activity_dialog.dart';
import 'services/user_prefs.dart';
import 'screens/auth_screen.dart';

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
  String? _userId, _userName, _email;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final id = await UserPrefs.getUserId();
    final name = await UserPrefs.getUserName();
    final email = await UserPrefs.getEmail();
    setState(() { _userId = id; _userName = name; _email = email; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_userId == null) return AuthScreen(onAuthOk: () async { await _load(); });
    return SensorApp(userId: _userId!, userName: _userName, email: _email);
  }
}

class SensorApp extends StatefulWidget {
  const SensorApp({super.key, required this.userId, this.userName, this.email});
  final String userId;
  final String? userName;
  final String? email;

  @override
  State<SensorApp> createState() => _SensorAppState();
}

class _SensorAppState extends State<SensorApp> {
  final SensorController _controller = SensorController();
  final WebSocketService _wsService = WebSocketService();

  String? _currentActivity;
  String _status = 'Esperando ventanas…';
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
        _status = 'Ventana enviada (${window.sampleCount}) | act: ${_currentActivity}';
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

  void _openAccountSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.35,
          minChildSize: 0.25,
          maxChildSize: 0.8,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(widget.userName ?? '(Sin nombre)'),
                  subtitle: Text(widget.email ?? ''),
                  trailing: Chip(label: Text('ID: ${widget.userId.substring(0,6)}…')),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Estado'),
                  subtitle: Text(_status),
                ),
                if (_lastSentAt != null)
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Último envío'),
                    subtitle: Text(_lastSentAt!.toLocal().toString()),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await UserPrefs.logout();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const Bootstrap()),
                          (_) => false,
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DataStep - Ventanas 2s'),
        actions: [
          IconButton(
            tooltip: 'Cuenta',
            onPressed: _openAccountSheet,
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_status),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Actividad: ', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_currentActivity ?? '— (sin seleccionar)'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Usuario: ', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${widget.userId}  ${widget.userName != null ? '(${widget.userName})' : ''}'),
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
            OutlinedButton.icon(
              onPressed: _openAccountSheet,
              icon: const Icon(Icons.keyboard_arrow_up),
              label: const Text('Ver cuenta'),
            ),
          ]),
        ]),
      ),
    );
  }
}
