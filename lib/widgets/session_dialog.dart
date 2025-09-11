import 'package:flutter/material.dart';

/// Diálogo de inicio de sesión que devuelve (String labelModelo, String? reason).
/// - Muestra solo 4 actividades visibles:
///   "Caminar", "Sentarse/Pararse", "Escaleras", "Caída"
/// - Mapea a las clases reales del modelo/DB:
///   "caminar", "sentarse", "gradas", "caerse"
/// - reason opcional (rellena "initial" si no se usa campo de texto)
Future<(String, String?)?> showSessionDialog(BuildContext context) async {
  // Mapeo display -> modelo
  const Map<String, String> displayToModel = {
    'Caminar': 'caminar',
    'Sentarse/Pararse': 'sentarse',
    'Escaleras': 'gradas',
    'Caída': 'caerse',
  };

  final actividadesDisplay = displayToModel.keys.toList();
  String selectedDisplay = actividadesDisplay.first;

  // Si no usas campo de texto para reason, puedes fijarla a 'initial'
  String? reason = 'initial';

  return showDialog<(String, String?)?>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return AlertDialog(
        title: const Text('Iniciar sesión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Actividad inicial',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 6),
            StatefulBuilder(
              builder: (ctx, setSB) {
                return DropdownButtonFormField<String>(
                  value: selectedDisplay,
                  items: [
                    for (final a in actividadesDisplay)
                      DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (v) => setSB(() => selectedDisplay = v ?? selectedDisplay),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                );
              },
            ),
            // Si deseas incluir un campo para reason, descomenta esto:
            /*
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Razón (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => reason = v.trim().isEmpty ? null : v.trim(),
            ),
            */
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final String modelLabel = displayToModel[selectedDisplay]!;
              Navigator.of(context).pop((modelLabel, reason));
            },
            child: const Text('Iniciar'),
          ),
        ],
      );
    },
  );
}
