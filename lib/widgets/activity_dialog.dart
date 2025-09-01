// lib/widgets/activity_dialog.dart
import 'package:flutter/material.dart';

Future<String?> showActivityDialog(BuildContext context) async {
  final List<String> activities = [
    'Caminando',
    'Corriendo',
    'Sentado',
    'De pie',
    'Subiendo escaleras',
    'Bajando escaleras'
  ];

  String? selectedActivity;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('¿Qué actividad estás realizando?'),
        content: DropdownButton<String>(
          isExpanded: true,
          hint: const Text('Selecciona una actividad'),
          value: selectedActivity,
          items: activities.map((activity) {
            return DropdownMenuItem<String>(
              value: activity,
              child: Text(activity),
            );
          }).toList(),
          onChanged: (value) {
            selectedActivity = value;
            Navigator.of(context).pop(value);
          },
        ),
      );
    },
  );
}
