// lib/models/sensor_sample.dart
class SensorSample {
  DateTime timestamp;
  double ax, ay, az;
  double gx, gy, gz;
  String? activity;

  SensorSample({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    this.activity,
  });

  factory SensorSample.empty() {
    return SensorSample(
      timestamp: DateTime.now(),
      ax: 0, ay: 0, az: 0,
      gx: 0, gy: 0, gz: 0,
    );
  }

  SensorSample copy() {
    return SensorSample(
      timestamp: timestamp,
      ax: ax, ay: ay, az: az,
      gx: gx, gy: gy, gz: gz,
      activity: activity,
    );
  }
}
