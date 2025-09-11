import 'package:flutter/material.dart';

/// Muestra un diálogo para elegir actividad (dropdown) y duración (min/seg).
/// Devuelve (String labelModelo, int duracionSeg) o null si cancela.
///
/// NOTA:
/// - Las opciones visibles son: "Caminar", "Sentarse/Pararse", "Escaleras", "Caída".
/// - Se mapean a las clases del modelo/DB: "caminar", "sentarse", "gradas", "caerse".
/// - El servidor espera y guarda el label del modelo.
Future<(String, int)?> showFeedbackDialog(
    BuildContext context, {
      String? initialLabel, // valor del modelo (ej: "caminar", "sentarse", "gradas", "caerse")
    }) async {
  // Mapeo display -> modelo
  const Map<String, String> displayToModel = {
    'Caminar': 'caminar',
    'Sentarse/Pararse': 'sentarse',
    'Escaleras': 'gradas',
    'Caída': 'caerse',
  };
  // Mapeo modelo -> display
  const Map<String, String> modelToDisplay = {
    'caminar': 'Caminar',
    'sentarse': 'Sentarse/Pararse',
    'gradas': 'Escaleras',
    'caerse': 'Caída',
  };

  final actividadesDisplay = displayToModel.keys.toList();

  // Resuelve etiqueta inicial a display (si viene en formato modelo)
  String initialDisplay =
      modelToDisplay[initialLabel?.toLowerCase().trim() ?? ''] ??
          actividadesDisplay.first;

  String selectedDisplay = initialDisplay;

  int minSel = 0; // 0..10
  int segSel = 0; // 0..59

  return showDialog<(String, int)?>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      final cs = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text('Confirma la actividad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Actividad
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Actividad', style: Theme.of(context).textTheme.labelLarge),
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
            const SizedBox(height: 14),

            // Duración
            Align(
              alignment: Alignment.centerLeft,
              child: Text('¿Cuánto tiempo?', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 6),
            StatefulBuilder(
              builder: (ctx, setSB) {
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: minSel,
                        items: [
                          for (int m = 0; m <= 10; m++)
                            DropdownMenuItem(value: m, child: Text('$m min')),
                        ],
                        onChanged: (v) => setSB(() => minSel = v ?? minSel),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: segSel,
                        items: [
                          for (int s = 0; s <= 59; s++)
                            DropdownMenuItem(value: s, child: Text('$s seg')),
                        ],
                        onChanged: (v) => setSB(() => segSel = v ?? segSel),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Se enviará en segundos.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final totalSeg = minSel * 60 + segSel;
              final String modelLabel = displayToModel[selectedDisplay]!;
              Navigator.of(context).pop((modelLabel, totalSeg));
            },
            child: const Text('Confirmar'),
          ),
        ],
      );
    },
  );
}
