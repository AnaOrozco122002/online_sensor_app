class SensorSample {
  final DateTime timestamp;
  final double ax, ay, az, gx, gy, gz;

  SensorSample({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  Map<String, dynamic> toJson(String activity) => {
    'timestamp': timestamp.toIso8601String(),
    'activity': activity,
    'accelerometer': {'x': ax, 'y': ay, 'z': az},
    'gyroscope': {'x': gx, 'y': gy, 'z': gz},
  };
}
