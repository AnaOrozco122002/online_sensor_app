// lib/widgets/feedback_activity_dialog.dart
import 'package:flutter/material.dart';

typedef ActivityFeedback = ({String actividad, int duracionSeg});

const kTriggerReasons = {
  'cooldown', 'budget', 'switch', 'keep_alive', 'uncertainty',
};

// Ajusta esta lista a tus actividades reales
const kActivities = <String>[
  'Caminando',
  'Sentado',
  'De pie',
  'Corriendo',
  'Subiendo escaleras',
  'Bajando escaleras',
  'Bicicleta',
  'Transporte',
];

Future<ActivityFeedback?> showFeedbackActivityDialog(BuildContext context) async {
  String? _actividad = kActivities.first;
  int _min = 0; // 0..10
  int _seg = 0; // 0..59

  final cs = Theme.of(context).colorScheme;

  return await showModalBottomSheet<ActivityFeedback>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actualiza actividad y duración',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se detectó una verificación del sistema. Indica la actividad y su duración.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Actividad (dropdown)
            DropdownButtonFormField<String>(
              value: _actividad,
              decoration: const InputDecoration(
                labelText: 'Actividad',
                border: OutlineInputBorder(),
              ),
              items: kActivities
                  .map((a) => DropdownMenuItem<String>(
                value: a,
                child: Text(a),
              ))
                  .toList(),
              onChanged: (v) => _actividad = v,
            ),

            const SizedBox(height: 12),

            // Duración M:S (dos dropdowns)
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Min (0–10)',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _min,
                      underline: const SizedBox.shrink(),
                      items: List.generate(11, (i) => i) // 0..10
                          .map((m) => DropdownMenuItem<int>(
                        value: m,
                        child: Text('$m'),
                      ))
                          .toList(),
                      onChanged: (v) => _min = v ?? 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Seg (0–59)',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _seg,
                      underline: const SizedBox.shrink(),
                      items: List.generate(60, (i) => i)
                          .map((s) => DropdownMenuItem<int>(
                        value: s,
                        child: Text('$s'),
                      ))
                          .toList(),
                      onChanged: (v) => _seg = v ?? 0,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(ctx).pop(null),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Aplicar'),
                  onPressed: () {
                    if (_actividad == null || _actividad!.trim().isEmpty) return;
                    final totalSeg = (_min * 60) + _seg;
                    Navigator.of(ctx).pop((
                    actividad: _actividad!.trim(),
                    duracionSeg: totalSeg
                    ));
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
