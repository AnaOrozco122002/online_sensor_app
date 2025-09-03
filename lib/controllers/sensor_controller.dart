// lib/controllers/sensor_controller.dart
import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

import '../models/sensor_sample.dart';
import '../models/sensor_window.dart';

typedef WindowReadyCallback = void Function(SensorWindow window);

class SensorController {
  // ====== Parámetros ======
  final double sampleRateHz = 50.0;   // 50 Hz
  final double windowSeconds = 2.0;   // 2 s -> 100 muestras
  final double hopSeconds = 1.0;      // 1 s (50% solape)

  late final int _windowSize;
  late final int _hopSize;
  late final Duration _tick;

  final ListQueue<SensorSample> _buffer = ListQueue();

  Timer? _samplingTimer;
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  // NUEVO: contador global de muestras emitidas
  int _totalSamples = 0;
  int _sinceLastEmit = 0;

  WindowReadyCallback? onWindowReady;

  SensorController() {
    _windowSize = (sampleRateHz * windowSeconds).round(); // 100
    _hopSize = (sampleRateHz * hopSeconds).round();       // 50
    _tick = Duration(microseconds: (1e6 / sampleRateHz).round());
  }

  void startListening() {
    accelerometerEventStream().listen((event) {
      _ax = event.x; _ay = event.y; _az = event.z;
    });
    gyroscopeEventStream().listen((event) {
      _gx = event.x; _gy = event.y; _gz = event.z;
    });

    _samplingTimer = Timer.periodic(_tick, (_) {
      final now = DateTime.now();
      final sample = SensorSample(
        ax: _ax, ay: _ay, az: _az,
        gx: _gx, gy: _gy, gz: _gz,
        timestamp: now,
      );

      _buffer.addLast(sample);
      _totalSamples++;

      // Mantener buffer razonable
      final maxBuffer = _windowSize * 2;
      while (_buffer.length > maxBuffer) _buffer.removeFirst();

      _maybeEmitWindow();
    });
  }

  void stopListening() {
    _samplingTimer?.cancel();
  }

  void _maybeEmitWindow() {
    if (_buffer.length < _windowSize) return;

    _sinceLastEmit++;
    if (_sinceLastEmit < _hopSize) return;
    _sinceLastEmit = 0;

    final List<SensorSample> windowSamples =
    _buffer.toList().sublist(_buffer.length - _windowSize);

    final startTime = windowSamples.first.timestamp;
    final endTime = windowSamples.last.timestamp;

    // Índices absolutos (0-based):
    final endIndex = _totalSamples - 1;
    final startIndex = endIndex - _windowSize + 1;

    final features = _computeFeatures(windowSamples);

    final window = SensorWindow(
      startTime: startTime,
      endTime: endTime,
      sampleCount: windowSamples.length,
      sampleRateHz: sampleRateHz,
      samples: windowSamples,
      features: features,
      startIndex: startIndex,
      endIndex: endIndex,
    );

    onWindowReady?.call(window);
  }

  Map<String, double> _computeFeatures(List<SensorSample> s) {
    // Series por eje
    final ax = s.map((e) => e.ax).toList();
    final ay = s.map((e) => e.ay).toList();
    final az = s.map((e) => e.az).toList();
    final gx = s.map((e) => e.gx).toList();
    final gy = s.map((e) => e.gy).toList();
    final gz = s.map((e) => e.gz).toList();

    // pitch/roll (grados) desde acelerómetro
    final pitch = List<double>.generate(s.length, (i) {
      final v = ax[i];
      final h = math.sqrt(ay[i]*ay[i] + az[i]*az[i]);
      return math.atan2(v, h) * 180.0 / math.pi;
    });
    final roll = List<double>.generate(s.length, (i) {
      final v = ay[i];
      final h = math.sqrt(ax[i]*ax[i] + az[i]*az[i]);
      return math.atan2(v, h) * 180.0 / math.pi;
    });

    // Magnitud acelerómetro
    final accMag = List<double>.generate(s.length, (i) {
      return math.sqrt(ax[i]*ax[i] + ay[i]*ay[i] + az[i]*az[i]);
    });

    final feats = <String, double>{};

    void addStats5(String prefix, List<double> v) {
      final m  = _mean(v);
      final sd = _std(v, m);
      final mn = _min(v);
      final mx = _max(v);
      final range = mx - mn;

      feats['${prefix}_mean']  = m;
      feats['${prefix}_std']   = sd;
      feats['${prefix}_min']   = mn;
      feats['${prefix}_max']   = mx;
      feats['${prefix}_range'] = range;
    }

    // Ejes lineales
    addStats5('ax', ax);
    addStats5('ay', ay);
    addStats5('az', az);

    // Giros
    addStats5('gx', gx);
    addStats5('gy', gy);
    addStats5('gz', gz);

    // Orientaciones
    addStats5('pitch', pitch);
    addStats5('roll', roll);

    // Magnitud aceleración
    addStats5('acc_mag', accMag);

    return feats;
    // NOTA: n_muestras, start_index, end_index, etiqueta
    // se añaden en SensorWindow.toJson() para empatar 1:1 con tus columnas.
  }

  double _mean(List<double> v) =>
      v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;

  double _std(List<double> v, double mean) {
    if (v.length < 2) return 0.0;
    double sum2 = 0.0;
    for (final x in v) { final d = x - mean; sum2 += d*d; }
    return math.sqrt(sum2 / (v.length - 1));
  }

  double _min(List<double> v) => v.isEmpty ? 0.0 : v.reduce(math.min);
  double _max(List<double> v) => v.isEmpty ? 0.0 : v.reduce(math.max);
}
