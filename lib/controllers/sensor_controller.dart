import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sensor_sample.dart';

class SensorController {
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;
  double _lastMagnitude = 0;
  final double _threshold = 2.5;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  Function(SensorSample)? onSample;
  Function()? onSuddenChange;

  void startListening() {
    _accelSub = accelerometerEventStream().listen((event) {
      _ax = event.x;
      _ay = event.y;
      _az = event.z;
    });

    _gyroSub = gyroscopeEventStream().listen((event) {
      _gx = event.x;
      _gy = event.y;
      _gz = event.z;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentMagnitude = sqrt(_ax * _ax + _ay * _ay + _az * _az);
      final delta = (currentMagnitude - _lastMagnitude).abs();

      if (delta > _threshold) {
        onSuddenChange?.call();
      }

      _lastMagnitude = currentMagnitude;

      final sample = SensorSample(
        timestamp: DateTime.now(),
        ax: _ax,
        ay: _ay,
        az: _az,
        gx: _gx,
        gy: _gy,
        gz: _gz,
      );

      onSample?.call(sample);
    });
  }

  void stopListening() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
  }
}
