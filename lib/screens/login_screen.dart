import 'package:flutter/material.dart';
import '../services/user_prefs.dart';
import '../services/ws_rpc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoggedIn});
  final VoidCallback? onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool _busy = false;
  bool _isRegister = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final id = _idCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      final pwd = _pwdCtrl.text;

      final payload = _isRegister
          ? {"type": "register", "id_usuario": id, "display_name": name, "password": pwd}
          : {"type": "login", "id_usuario": id, "password": pwd};

      final res = await wsRpc(payload);
      if (res["ok"] == true) {
        await UserPrefs.saveUser(userId: id, userName: name, password: pwd);
        if (mounted) widget.onLoggedIn?.call();
      } else {
        final err = res["error"] ?? "error";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fallo de red: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() => setState(() => _isRegister = !_isRegister);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? 'Crear cuenta' : 'Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _idCtrl,
              decoration: const InputDecoration(labelText: 'ID de usuario'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un ID' : null,
            ),
            if (_isRegister) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre (opcional)'),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _pwdCtrl,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty) ? 'Ingresa la contraseña' : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                child: const Text('Cambiar contraseña'),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const CircularProgressIndicator() : Text(_isRegister ? 'Crear y guardar' : 'Entrar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _toggleMode,
              child: Text(_isRegister ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate'),
            ),
          ]),
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _oldCtrl.dispose(); _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final userId = await UserPrefs.getUserId();
      if (userId == null) throw Exception('No hay sesión guardada');

      final res = await wsRpc({
        "type": "change_password",
        "id_usuario": userId,
        "old_password": _oldCtrl.text,
        "new_password": _newCtrl.text,
      });

      if (res["ok"] == true) {
        // Actualiza password local
        await UserPrefs.saveUser(userId: userId, password: _newCtrl.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
        Navigator.of(context).pop();
      } else {
        final err = res["error"] ?? "error";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fallo de red: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _oldCtrl,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              obscureText: true,
              validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const CircularProgressIndicator() : const Text('Actualizar'),
            ),
          ]),
        ),
      ),
    );
  }
}
