// lib/models/sensor_window.dart
import 'sensor_sample.dart';

class SensorWindow {
  final DateTime startTime;
  final DateTime endTime;
  final int sampleCount;
  final double sampleRateHz;
  final List<SensorSample> samples;

  /// Mapa de features (variables) calculadas de la ventana.
  /// Ejemplo de claves:
  ///  ax_mean, ax_std, ax_min, ax_max, ax_rms,
  ///  ay_mean, ..., gz_rms,
  ///  acc_norm_mean, acc_norm_std, acc_norm_rms,
  ///  gyro_norm_mean, gyro_norm_std, gyro_norm_rms
  ///
  final Map<String, double> features;

  SensorWindow({
    required this.startTime,
    required this.endTime,
    required this.sampleCount,
    required this.sampleRateHz,
    required this.samples,
    required this.features,
  });

  Map<String, dynamic> toJson({String? activity}) {
    return {
      "start_time": startTime.toIso8601String(),
      "end_time": endTime.toIso8601String(),
      "sample_count": sampleCount,
      "sample_rate_hz": sampleRateHz,
      if (activity != null) "activity": activity,
      "features": features,
      // Si no quieres enviar crudo, comenta la sección "samples".
      "samples": samples.map((s) => {
        "t": s.timestamp.toIso8601String(),
        "ax": s.ax, "ay": s.ay, "az": s.az,
        "gx": s.gx, "gy": s.gy, "gz": s.gz,
      }).toList(),
    };
  }
}
