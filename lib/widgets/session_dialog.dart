import 'package:flutter/material.dart';

/// Devuelve: (actividad, reason) => reason fijo 'initial'
Future<(String, String?)?> showSessionDialog(BuildContext context) async {
  final actividades = <String>[
    'Caminar',
    'Correr',
    'Estar de pie',
    'Sentado',
    'Acostado',
    'Subir escaleras',
    'Bajar escaleras',
    'Ciclismo',
  ];

  String? _selected; // actividad seleccionada

  return showDialog<(String, String?)>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cs.surfaceContainerHighest,
        title: Row(
          children: [
            Icon(Icons.play_circle_outline, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Iniciar sesión',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Selecciona la actividad que estás realizando. '
                      'Se guardará como etiqueta inicial de esta sesión.',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Actividad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selected,
                      isExpanded: true,
                      menuMaxHeight: 320,
                      hint: const Text('Elige una actividad'),
                      items: actividades
                          .map(
                            (a) => DropdownMenuItem<String>(
                          value: a,
                          child: Text(a),
                        ),
                      )
                          .toList(),
                      onChanged: (v) {
                        _selected = v;
                        // Forzar rebuild del diálogo
                        (ctx as Element).markNeedsBuild();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Aceptar'),
            onPressed: _selected == null
                ? null
                : () {
              // reason = 'initial'
              Navigator.of(ctx).pop((_selected!, 'initial'));
            },
          ),
        ],
      );
    },
  );
}
