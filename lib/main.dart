// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'controllers/sensor_controller.dart';
import 'models/sensor_window.dart';
import 'services/websocket_service.dart';
import 'services/user_prefs.dart';
import 'screens/auth_screen.dart';

// Diálogo de inicio que devuelve (String label, String? reason)
import 'widgets/session_dialog.dart';
import 'widgets/profile_photo_dialog.dart';
import 'widgets/feedback_dialog.dart'; // <-- FEEDBACK DIALOG

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

  String? _currentActivity; // etiqueta a mostrar y enviar
  String _status = 'Sin sesión activa';
  DateTime? _lastSentAt;
  int? _activeIntervalId; // intervalos_label.id
  String? _avatarUrl;

  // Polling de reason
  Timer? _reasonTimer;
  bool _askingFeedback = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.avatarUrl;

    _controller.onWindowReady = (SensorWindow window) async {
      if (_activeIntervalId == null) {
        setState(() => _status = 'No hay sesión activa. Pulsa Start.');
        return;
      }
      try {
        await _ws.sendWindow(
          windowJson: window.toJson(),
          idUsuario: widget.userId,
          sessionId: _activeIntervalId,
        );
        setState(() {
          _lastSentAt = DateTime.now();
          _status =
          'Ventana enviada (${window.sampleCount}) | etiqueta: ${_currentActivity ?? "—"} | ID de sesión: $_activeIntervalId';
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
    _reasonTimer?.cancel();
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

  // ---------- Polling de reason ----------
  void _startReasonPolling() {
    _reasonTimer?.cancel();
    _reasonTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final id = _activeIntervalId;
      if (id == null || !_ws.isConnected) return;
      if (_askingFeedback) return;

      try {
        final resp = await _ws.getIntervalReason(id);
        if (resp['ok'] == true) {
          final reason = (resp['reason'] ?? '').toString().toLowerCase();
          if (reason == 'budget' ||
              reason == 'switch' ||
              reason == 'keep_alive' ||
              reason == 'uncertainty') {
            _askingFeedback = true;

            final (String, int)? ans = await showFeedbackDialog(
              context,
              initialLabel: (resp['label'] ?? '').toString(),
            );

            if (ans != null) {
              final String newLabel = ans.$1;
              final int durSeg = ans.$2;

              // Optimistic UI: poner la nueva etiqueta en la UI,
              // y revertir solo si el RPC falla.
              final prevActivity = _currentActivity;
              setState(() {
                _currentActivity = newLabel;
                _status = 'Aplicando feedback… ($newLabel, ${durSeg}s)';
              });

              try {
                final apply = await _ws.applyIntervalFeedback(
                  intervalId: id,
                  label: newLabel,
                  duracionSeg: durSeg,
                );
                if (apply['ok'] == true) {
                  // Mantener nueva etiqueta. No sobrescribir con lecturas que puedan llegar desfasadas.
                  setState(() {
                    _status = 'Feedback aplicado: $newLabel (${durSeg}s).';
                  });
                } else {
                  // Falló en servidor: revertir
                  setState(() {
                    _currentActivity = prevActivity;
                    _status =
                    'No se pudo aplicar feedback: ${apply['message'] ?? apply['error'] ?? 'Error'}';
                  });
                }
              } catch (e) {
                // Error de red: revertir
                setState(() {
                  _currentActivity = prevActivity;
                  _status = 'Error feedback: $e';
                });
              }
            }

            _askingFeedback = false;
          }
        }
      } catch (_) {
        // ignorar errores de red del polling
      }
    });
  }

  void _stopReasonPolling() {
    _reasonTimer?.cancel();
    _reasonTimer = null;
  }

  // ---------- Sesiones ----------
  Future<void> _startSession() async {
    // Pedimos actividad (label) y devolvemos reason='initial'
    final res = await showSessionDialog(context);
    if (res == null) return;

    final String label = res.$1 as String;
    final String? reason = res.$2 as String?;

    setState(() {
      _status = 'Creando sesión…';
      _currentActivity = label;
    });

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
          _startReasonPolling();
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
        _stopReasonPolling();
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
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Estado
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
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
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
                          Text(widget.email ?? '',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
    final tiles = <_StatTile>[
      _StatTile(
        icon: Icons.confirmation_number_outlined,
        label: 'ID de sesión',
        value: sessionId?.toString() ?? '—',
      ),
      _StatTile(
        icon: Icons.label_outline,
        label: 'Etiqueta',
        value: activity ?? '—',
      ),
      _StatTile(
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Estado',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (ctx, cns) {
                final isWide = cns.maxWidth >= 640;
                final crossCount = isWide ? 3 : 1;
                return GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: isWide ? 3.4 : 3.2,
                  children: tiles,
                );
              },
            ),
            const SizedBox(height: 10),
            Container(
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
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
