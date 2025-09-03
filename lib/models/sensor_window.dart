// lib/models/sensor_window.dart
import 'sensor_sample.dart';

class SensorWindow {
  final DateTime startTime;
  final DateTime endTime;
  final int sampleCount;
  final double sampleRateHz;
  final List<SensorSample> samples;

  /// Índices absolutos (0-based) dentro del stream continuo
  final int startIndex;
  final int endIndex;

  /// Mapa de features calculadas (ej.: ax_mean, ax_std, ..., acc_mag_range, etc.)
  /// Debe venir ya con las claves que tu modelo espera.
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

  /// Construye el JSON para enviar al servidor.
  /// Incluye:
  ///  - Campos meta (start_time, end_time, sample_count, sample_rate_hz, start_index, end_index, activity opcional)
  ///  - "features": (features del controlador) + {start_index, end_index, n_muestras, etiqueta?}
  ///  - "samples": crudo por ventana (puedes quitarlo si no lo necesitas)
  Map<String, dynamic> toJson({String? activity}) {
    // Asegurar que tenemos un Map<String, dynamic> no nulo y modificable
    final feats = Map<String, dynamic>.from(features);

    // Añadir metadatos que tu pipeline requiere como columnas
    feats.addAll({
      "start_index": startIndex.toDouble(),
      "end_index": endIndex.toDouble(),
      "n_muestras": sampleCount.toDouble(),
    });

    // Si tu pipeline espera "etiqueta" (target/label) textual en el dataset final:
    // - La enviamos como campo de nivel superior ("activity") para compatibilidad
    // - Y opcionalmente la duplicamos dentro de "features" como string (si tu ETL la lee desde ahí)
    if (activity != null) {
      feats["etiqueta"] = activity; // déjala textual si tu pipeline la consume así
    }

    return {
      // Metadatos "clásicos" que ya usas
      "start_time": startTime.toIso8601String(),
      "end_time": endTime.toIso8601String(),
      "sample_count": sampleCount,
      "sample_rate_hz": sampleRateHz,

      // Índices absolutos para trazar cada ventana dentro del stream
      "start_index": startIndex,
      "end_index": endIndex,

      // Etiqueta (nivel superior) para lecturas simples en el server/DB
      if (activity != null) "activity": activity,

      // Todas las features, incluyendo las añadidas arriba
      "features": feats,

      // Muestras crudas (opcional). Si no quieres enviarlas, elimina este bloque.
      "samples": samples.map((s) => {
        "t": s.timestamp.toIso8601String(),
        "ax": s.ax, "ay": s.ay, "az": s.az,
        "gx": s.gx, "gy": s.gy, "gz": s.gz,
      }).toList(),
    };
  }
}
