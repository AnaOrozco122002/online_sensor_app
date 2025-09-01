import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final Function(String) onActivitySelected;
  final String? currentActivity;
  final Map<String, dynamic>? currentSampleData;

  const HomeScreen({
    Key? key,
    required this.onActivitySelected,
    this.currentActivity,
    this.currentSampleData,
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

  Widget buildSensorCard({
    required String title,
    required Map<String, dynamic> values,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color.darken(0.4),
                )),
            const SizedBox(height: 8),
            Text('x: ${values['x'].toStringAsFixed(3)}'),
            Text('y: ${values['y'].toStringAsFixed(3)}'),
            Text('z: ${values['z'].toStringAsFixed(3)}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showSelector = selectedActivity == null;
    final sample = widget.currentSampleData;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: showSelector
                    ? Column(
                  key: const ValueKey('selector'),
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
              const SizedBox(height: 24),
              if (sample != null) ...[
                const Text(
                  'Datos actuales del sensor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                buildSensorCard(
                  title: 'Acelerómetro',
                  values: Map<String, double>.from(sample['accelerometer']),
                  color: Colors.lightBlue,
                ),
                buildSensorCard(
                  title: 'Giroscopio',
                  values: Map<String, double>.from(sample['gyroscope']),
                  color: Colors.pinkAccent,
                ),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.greenAccent.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.tag, color: Colors.green),
                    title: const Text('Etiqueta actual'),
                    subtitle: Text(sample['activity']),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension ColorShades on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
