import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'controllers/sensor_controller.dart';
import 'models/sensor_sample.dart';

void main() {
  runApp(SensorApp());
}

class SensorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Streaming',
      home: SensorHomePage(),
    );
  }
}

class SensorHomePage extends StatefulWidget {
  @override
  _SensorHomePageState createState() => _SensorHomePageState();
}

class _SensorHomePageState extends State<SensorHomePage> {
  late SensorController controller;
  late IOWebSocketChannel channel;

  final List<String> activities = ['Sentado', 'Caminando', 'Corriendo'];
  String selectedActivity = 'Sentado';

  @override
  void initState() {
    super.initState();

    controller = SensorController();

    // REEMPLAZA CON TU IP LOCAL O SERVIDOR
    channel = IOWebSocketChannel.connect('ws://192.168.0.100:8080');

    controller.onSample = (sample) {
      final data = sample.toJson(selectedActivity);
      channel.sink.add(jsonEncode(data));
      print('Enviado: $data');
    };

    controller.startListening();
  }

  @override
  void dispose() {
    controller.stopListening();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Streaming en Tiempo Real')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Actividad actual:', style: TextStyle(fontSize: 18)),
            DropdownButton<String>(
              value: selectedActivity,
              items: activities.map((act) => DropdownMenuItem(
                value: act,
                child: Text(act),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedActivity = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
