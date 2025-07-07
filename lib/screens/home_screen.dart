import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final Function(String) onActivitySelected;
  final String? currentActivity;

  const HomeScreen({
    Key? key,
    required this.onActivitySelected,
    this.currentActivity,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final activities = ['Sentado', 'Caminando', 'Corriendo', 'Saltando'];
  String? selectedActivity;

  @override
  void initState() {
    super.initState();
    selectedActivity = widget.currentActivity;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentActivity != oldWidget.currentActivity) {
      setState(() {
        selectedActivity = widget.currentActivity;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showSelector = selectedActivity == null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Recolección de Actividad',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: showSelector
              ? Column(
            key: const ValueKey('selector'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Qué actividad estás realizando?',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: selectedActivity,
                hint: const Text('Selecciona una actividad'),
                items: activities.map((act) {
                  return DropdownMenuItem(
                    value: act,
                    child: Text(act),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedActivity = value;
                    });
                    widget.onActivitySelected(value);
                  }
                },
              ),
            ],
          )
              : const Text(
            'Esperando cambio significativo...',
            key: ValueKey('espera'),
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
