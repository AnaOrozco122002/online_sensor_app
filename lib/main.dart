import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';

import 'controllers/sensor_controller.dart';
import 'models/sensor_sample.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SensorApp());
}

class SensorApp extends StatelessWidget {
  const SensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Stream',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const SensorHome(),
    );
  }
}

class SensorHome extends StatefulWidget {
  const SensorHome({super.key});

  @override
  State<SensorHome> createState() => _SensorHomeState();
}

class _SensorHomeState extends State<SensorHome> {
  late SensorController controller;
  late IOWebSocketChannel channel;

  String? selectedActivity;
  bool showSelector = false;

  @override
  void initState() {
    super.initState();

    controller = SensorController();

    controller.onSuddenChange = () {
      setState(() {
        selectedActivity = null; // para que el Dropdown empiece sin selección
        showSelector = true;
      });
    };

    controller.onSample = (sample) {
      if (selectedActivity != null) {
        final data = sample.toJson(selectedActivity!);
        channel.sink.add(jsonEncode(data));
        print('Enviado: $data');
      }
    };

    channel = IOWebSocketChannel.connect('ws://192.168.0.100:8080'); // ajusta tu IP

    controller.startListening();
  }

  void _onActivitySelected(String activity) {
    setState(() {
      selectedActivity = activity;
      showSelector = false;
    });
  }

  @override
  void dispose() {
    controller.stopListening();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      currentActivity: showSelector ? null : null,
      onActivitySelected: _onActivitySelected,
    );
  }
}
