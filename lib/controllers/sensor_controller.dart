import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sensor_sample.dart';

class SensorController {
  late StreamSubscription<AccelerometerEvent> _accelSub;
  late StreamSubscription<GyroscopeEvent> _gyroSub;

  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  Function(SensorSample)? onSample;

  void startListening() {
    _accelSub = accelerometerEvents.listen((event) {
      _ax = event.x;
      _ay = event.y;
      _az = event.z;
    });

    _gyroSub = gyroscopeEvents.listen((event) {
      _gx = event.x;
      _gy = event.y;
      _gz = event.z;
    });

    Timer.periodic(Duration(seconds: 1), (timer) {
      final sample = SensorSample(
        timestamp: DateTime.now(),
        ax: _ax,
        ay: _ay,
        az: _az,
        gx: _gx,
        gy: _gy,
        gz: _gz,
      );
      if (onSample != null) onSample!(sample);
    });
  }

  void stopListening() {
    _accelSub.cancel();
    _gyroSub.cancel();
  }
}
