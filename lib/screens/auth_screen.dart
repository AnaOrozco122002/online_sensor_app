import 'package:flutter/material.dart';
import '../services/user_prefs.dart';
import '../services/ws_rpc.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onAuthOk});
  final VoidCallback? onAuthOk;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _loginKey = GlobalKey<FormState>();
  final _regKey = GlobalKey<FormState>();

  // login
  final _loginEmail = TextEditingController();
  final _loginPwd = TextEditingController();

  // register
  final _regEmail = TextEditingController();
  final _regName = TextEditingController();
  DateTime? _regBirthday;
  final _regPwd = TextEditingController();
  final _regPwd2 = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPwd.dispose();
    _regEmail.dispose();
    _regName.dispose();
    _regPwd.dispose();
    _regPwd2.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 100);
    final last = DateTime(now.year - 5);
    final d = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: DateTime(now.year - 20),
    );
    if (d != null) setState(() => _regBirthday = d);
  }

  Future<void> _doLogin() async {
    if (!_loginKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final res = await wsRpc({"type": "login", "email": _loginEmail.text.trim(), "password": _loginPwd.text});
      if (res["ok"] == true) {
        await UserPrefs.saveSession(
          userId: res["id_usuario"],
          email: res["email"],
          password: _loginPwd.text,
        );
        if (mounted) widget.onAuthOk?.call();
      } else {
        final msg = res["message"] ?? res["error"] ?? "Error";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo iniciar sesión: $msg')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fallo de red: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doRegister() async {
    if (!_regKey.currentState!.validate()) return;
    if (_regPwd.text != _regPwd2.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }
    setState(() => _busy = true);
    try {
      final bdayStr = _regBirthday != null
          ? "${_regBirthday!.year.toString().padLeft(4,'0')}-${_regBirthday!.month.toString().padLeft(2,'0')}-${_regBirthday!.day.toString().padLeft(2,'0')}"
          : null;

      final res = await wsRpc({
        "type": "register",
        "email": _regEmail.text.trim(),
        "display_name": _regName.text.trim(),
        "birthday": bdayStr,
        "password": _regPwd.text,
      });

      if (res["ok"] == true) {
        await UserPrefs.saveSession(
          userId: res["id_usuario"],
          email: res["email"],
          userName: res["display_name"],
          password: _regPwd.text,
        );
        if (mounted) widget.onAuthOk?.call();
      } else {
        final msg = res["message"] ?? res["error"] ?? "Error";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo registrar: $msg')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fallo de red: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _gotoChangePassword() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('DataStep'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: cs.primary,
          tabs: const [Tab(text: 'Iniciar sesión'), Tab(text: 'Crear cuenta')],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            TabBarView(
              controller: _tab,
              children: [
                // LOGIN
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _loginKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('¡Hola de nuevo!', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _loginEmail,
                                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _loginPwd,
                                  decoration: const InputDecoration(labelText: 'Contraseña'),
                                  obscureText: true,
                                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _gotoChangePassword,
                                    child: const Text('Cambiar contraseña'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: _doLogin,
                                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                  child: const Text('Entrar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // REGISTER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _regKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Crear cuenta', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _regEmail,
                                  decoration: const InputDecoration(labelText: 'Correo electrónico *'),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _regName,
                                  decoration: const InputDecoration(labelText: 'Nombre (opcional)'),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: _pickBirthday,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(labelText: 'Fecha de nacimiento (opcional)'),
                                    child: Text(_regBirthday != null
                                        ? "${_regBirthday!.day.toString().padLeft(2,'0')}/${_regBirthday!.month.toString().padLeft(2,'0')}/${_regBirthday!.year}"
                                        : 'Seleccionar…'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _regPwd,
                                  decoration: const InputDecoration(labelText: 'Contraseña *'),
                                  obscureText: true,
                                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _regPwd2,
                                  decoration: const InputDecoration(labelText: 'Confirmar contraseña *'),
                                  obscureText: true,
                                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _doRegister,
                                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                  child: const Text('Crear cuenta'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_busy)
              const Center(child: CircularProgressIndicator()),
          ],
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
  void dispose() { _oldCtrl.dispose(); _newCtrl.dispose(); super.dispose(); }

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
        Navigator.of(context).pop();
      } else {
        final msg = res["message"] ?? res["error"] ?? "Error";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $msg')));
      }
    } catch (e) {
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
