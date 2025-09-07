// lib/widgets/profile_photo_dialog.dart
import 'package:flutter/material.dart';

Future<String?> showProfilePhotoDialog(BuildContext context, {String? initialUrl}) {
  final ctrl = TextEditingController(text: initialUrl ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text('Foto de perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'URL de imagen (https://...)',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 80,
                height: 80,
                color: cs.surfaceVariant.withOpacity(0.6),
                child: ctrl.text.trim().isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : Image.network(
                  ctrl.text.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );
}
