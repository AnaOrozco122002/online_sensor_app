// lib/main.dart
import 'package:flutter/material.dart';
import 'controllers/sensor_controller.dart';
import 'models/sensor_window.dart';
import 'services/websocket_service.dart';
import 'widgets/activity_dialog.dart';
import 'services/user_prefs.dart';
import 'screens/auth_screen.dart';
import 'widgets/session_dialog.dart';
import 'widgets/profile_photo_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final seed = Colors.deepPurple;
    return MaterialApp(
      title: 'DataStep',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        textTheme: Typography.blackMountainView,
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
  String? _userIdStr, _userName, _email, _avatarUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await UserPrefs.getUserId();
    final name = await UserPrefs.getUserName();
    final email = await UserPrefs.getEmail();
    final avatar = await UserPrefs.getAvatarUrl();
    setState(() {
      _userIdStr = id;
      _userName = name;
      _email = email;
      _avatarUrl = avatar;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_userIdStr == null) {
      return AuthScreen(onAuthOk: () async {
        await _load();
      });
    }
    final userId = int.tryParse(_userIdStr!) ?? -1;
    return SensorApp(
      userId: userId,
      userName: _userName,
      email: _email,
      avatarUrl: _avatarUrl,
    );
  }
}

class SensorApp extends StatefulWidget {
  const SensorApp({
    super.key,
    required this.userId,
    this.userName,
    this.email,
    this.avatarUrl,
  });
  final int userId;
  final String? userName;
  final String? email;
  final String? avatarUrl;

  @override
  State<SensorApp> createState() => _SensorAppState();
}

class _SensorAppState extends State<SensorApp> {
  final SensorController _controller = SensorController();
  final WebSocketService _ws = WebSocketService();

  String? _currentActivity;
  String _status = 'Sin sesión activa';
  DateTime? _lastSentAt;
  bool _isChoosingActivity = false;
  int? _activeIntervalId; // intervalos_label.id
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.avatarUrl;

    _controller.onWindowReady = (SensorWindow window) async {
      if (_activeIntervalId == null) {
        setState(() => _status = 'No hay sesión activa. Pulsa Start.');
        return;
      }
      if (_currentActivity == null && !_isChoosingActivity) {
        _isChoosingActivity = true;
        final act = await showActivityDialog(context);
        _isChoosingActivity = false;
        if (act == null) return;
        setState(() => _currentActivity = act);
      }
      try {
        await _ws.sendWindow(
          windowJson: window.toJson(),
          idUsuario: widget.userId,
          sessionId: _activeIntervalId,
          activity: _currentActivity,
        );
        setState(() {
          _lastSentAt = DateTime.now();
          _status =
          'Ventana enviada (${window.sampleCount}) | actividad: $_currentActivity | ID de sesión: $_activeIntervalId';
        });
      } catch (e) {
        setState(() => _status = 'Error enviando ventana: $e');
      }
    };

    _controller.startListening();
  }

  @override
  void dispose() {
    _controller.stopListening();
    _ws.close();
    super.dispose();
  }

  // ---------- Helpers UI ----------
  String _effectiveUserName(String? displayName, String? email) {
    if (displayName != null && displayName.trim().isNotEmpty) return displayName.trim();
    final em = (email ?? '').trim();
    if (em.contains('@')) return em.split('@').first;
    return '(Sin nombre)';
  }

  ImageProvider? _avatarProvider() {
    final url = _avatarUrl?.trim();
    if (url == null || url.isEmpty) return null;
    return NetworkImage(url);
  }

  String _initialsFrom(String? name, String? email) {
    final n = _effectiveUserName(name, email);
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  Future<void> _editAvatar() async {
    final newUrl = await showProfilePhotoDialog(context, initialUrl: _avatarUrl);
    if (newUrl == null) return;
    await UserPrefs.setAvatarUrl(newUrl);
    setState(() => _avatarUrl = newUrl);
  }

  // ---------- Sesiones ----------
  Future<void> _startSession() async {
    final res = await showSessionDialog(context);
    if (res == null) return;
    final (label, reason) = res;

    setState(() => _status = 'Creando sesión…');
    try {
      final rpcResp = await _ws.sendRpc({
        "type": "start_session",
        "id_usuario": widget.userId,
        "label": label,
        "reason": reason,
      });

      if (rpcResp is Map && rpcResp['ok'] == true) {
        final sid = rpcResp['interval_id'];
        if (sid is int) {
          setState(() {
            _activeIntervalId = sid;
            _status = 'Sesión #$sid iniciada: $label';
          });
        } else {
          setState(() => _status = 'Respuesta inválida del servidor (interval_id no int)');
        }
      } else {
        final msg = (rpcResp is Map)
            ? (rpcResp['message'] ?? rpcResp['error'] ?? 'Error')
            : 'Error';
        setState(() => _status = 'No se pudo iniciar sesión: $msg');
      }
    } catch (e) {
      setState(() => _status = 'Fallo de red: $e');
    }
  }

  Future<void> _stopSession() async {
    final id = _activeIntervalId;
    if (id == null) return;
    setState(() => _status = 'Deteniendo sesión…');
    try {
      final rpcResp = await _ws.sendRpc({
        "type": "stop_session",
        "interval_id": id,
      });

      if (rpcResp is Map && rpcResp['ok'] == true) {
        setState(() {
          _status = 'Sesión #$id detenida';
          _activeIntervalId = null;
          _currentActivity = null;
        });
      } else {
        final msg = (rpcResp is Map)
            ? (rpcResp['message'] ?? rpcResp['error'] ?? 'Error')
            : 'Error';
        setState(() => _status = 'No se pudo detener: $msg');
      }
    } catch (e) {
      setState(() => _status = 'Fallo de red: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _effectiveUserName(widget.userName, widget.email);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 6),
            Icon(Icons.directions_walk, color: cs.primary),
            const SizedBox(width: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Data',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: 'Step',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const TextSpan(text: '  ·  '),
                  TextSpan(
                    text: 'Ventanas 2s',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: Icon(
                _ws.isConnected ? Icons.wifi : Icons.wifi_off,
                color: _ws.isConnected ? Colors.green : cs.error,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cuenta',
            onPressed: _openAccountSheet,
            icon: CircleAvatar(
              radius: 14,
              backgroundImage: _avatarProvider(),
              child: _avatarProvider() == null
                  ? Text(
                _initialsFrom(widget.userName, widget.email),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              )
                  : null,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header usuario + acciones
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: _avatarProvider(),
                                  child: _avatarProvider() == null
                                      ? Text(
                                    _initialsFrom(widget.userName, widget.email),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 240),
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _activeIntervalId == null ? _startSession : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _activeIntervalId != null ? _stopSession : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                            ),
                            if (isWide)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final act = await showActivityDialog(context);
                                  if (act != null) setState(() => _currentActivity = act);
                                },
                                icon: const Icon(Icons.label_outline),
                                label: Text(_currentActivity == null
                                    ? 'Seleccionar actividad'
                                    : 'Actividad: $_currentActivity'),
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (!isWide) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final act = await showActivityDialog(context);
                          if (act != null) setState(() => _currentActivity = act);
                        },
                        icon: const Icon(Icons.label_outline),
                        label: Text(_currentActivity == null
                            ? 'Seleccionar actividad'
                            : 'Actividad: $_currentActivity'),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Estado (mejorado)
                    _EstadoCard(
                      status: _status,
                      isConnected: _ws.isConnected,
                      sessionId: _activeIntervalId,
                      activity: _currentActivity,
                      lastSentAt: _lastSentAt,
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Tip: inicia una sesión para que las ventanas se asocien a tu intervalo y etiqueta.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
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
        final name = _effectiveUserName(widget.userName, widget.email);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.36,
          minChildSize: 0.28,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: _avatarProvider(),
                      child: _avatarProvider() == null
                          ? Text(
                        _initialsFrom(widget.userName, widget.email),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(widget.email ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _editAvatar,
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar foto'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Estado'),
                  subtitle: Text(_status),
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
}

class _EstadoCard extends StatelessWidget {
  const _EstadoCard({
    required this.status,
    required this.isConnected,
    required this.sessionId,
    required this.activity,
    required this.lastSentAt,
  });

  final String status;
  final bool isConnected;
  final int? sessionId;
  final String? activity;
  final DateTime? lastSentAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final items = <_StatItem>[
      _StatItem(
        icon: isConnected ? Icons.wifi : Icons.wifi_off,
        label: 'Conexión',
        value: isConnected ? 'Conectado' : 'Desconectado',
        color: isConnected ? Colors.green : cs.error,
      ),
      _StatItem(
        icon: Icons.confirmation_number_outlined,
        label: 'ID de sesión',
        value: sessionId?.toString() ?? '—',
      ),
      _StatItem(
        icon: Icons.label_outline,
        label: 'Actividad',
        value: activity ?? '—',
      ),
      _StatItem(
        icon: Icons.schedule,
        label: 'Último envío',
        value: lastSentAt != null ? lastSentAt!.toLocal().toString() : '—',
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceVariant.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final cols = isWide ? 3 : 2;
            const gap = 12.0;

            final totalGapsWidth = gap * (cols - 1);
            final tileWidth = (constraints.maxWidth - totalGapsWidth) / cols;
            const tileHeight = 86.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Estado'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: items.map((it) {
                    return SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: _StatTile(
                        icon: it.icon,
                        label: it.label,
                        value: it.value,
                        color: it.color,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primaryContainer,
                  cs.outlineVariant.withOpacity(0.0),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
