// lib/models/sensor_window.dart
import 'sensor_sample.dart';

class SensorWindow {
  final DateTime startTime;
  final DateTime endTime;
  final int sampleCount;
  final double sampleRateHz;
  final List<SensorSample> samples;
  final int startIndex;
  final int endIndex;
  final Map<String, double> features;

  SensorWindow({
    required this.startTime,
    required this.endTime,
    required this.sampleCount,
    required this.sampleRateHz,
    required this.samples,
    required this.features,
    required this.startIndex,
    required this.endIndex,
  });

  Map<String, dynamic> toJson({String? activity, String? userId}) {
    final feats = Map<String, dynamic>.from(features);
    feats.addAll({
      "start_index": startIndex.toDouble(),
      "end_index": endIndex.toDouble(),
      "n_muestras": sampleCount.toDouble(),
    });
    if (activity != null) {
      feats["etiqueta"] = activity;
    }

    return {
      "id_usuario": userId, // <<--- NUEVO
      "start_time": startTime.toIso8601String(),
      "end_time": endTime.toIso8601String(),
      "sample_count": sampleCount,
      "sample_rate_hz": sampleRateHz,
      "start_index": startIndex,
      "end_index": endIndex,
      if (activity != null) "activity": activity,
      "features": feats,
      // Si no necesitas crudo, elimina "samples" para reducir ancho de banda:
      "samples": samples.map((s) => {
        "t": s.timestamp.toIso8601String(),
        "ax": s.ax, "ay": s.ay, "az": s.az,
        "gx": s.gx, "gy": s.gy, "gz": s.gz,
      }).toList(),
    };
  }
}
