import 'package:flutter/material.dart';

/// Devuelve (label, reason) o null si se cancela.
/// Nota: no se hace dispose inmediato de los controllers para evitar
/// el crash "TextEditingController used after being disposed" durante
/// la animación de cierre del diálogo.
Future<(String, String)?> showSessionDialog(BuildContext context) async {
  final labelCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final res = await showDialog<(String, String)?>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Nueva sesión'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la sesión (label) *',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / razón (opcional)',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx, rootNavigator: true)
                  .pop((labelCtrl.text.trim(), reasonCtrl.text.trim()));
            },
            child: const Text('Iniciar'),
          ),
        ],
      );
    },
  );

  // No dispose inmediato para evitar race con animaciones del Overlay.
  // (Si quisieras, podrías: Future.microtask(() { labelCtrl.dispose(); reasonCtrl.dispose(); });)
  return res;
}
