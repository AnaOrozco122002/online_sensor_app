// lib/controllers/sensor_controller.dart
import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

import '../models/sensor_sample.dart';
import '../models/sensor_window.dart';

typedef WindowReadyCallback = void Function(SensorWindow window);

class SensorController {
  // ====== Parámetros de ventana ======
  final double sampleRateHz = 50.0;           // 50 Hz
  final double windowSeconds = 2.0;           // 2 s => 100 muestras
  final double hopSeconds = 1.0;              // 1 s (50% solape)

  // ====== Internos calculados ======
  late final int _windowSize; // muestras por ventana
  late final int _hopSize;    // desplazamiento en muestras
  late final Duration _tick;  // periodo del temporizador

  // Buffer circular con las muestras crudas
  final ListQueue<SensorSample> _buffer = ListQueue();

  // Timers y últimos valores de sensores
  Timer? _samplingTimer;
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  // Callback cuando la ventana está lista
  WindowReadyCallback? onWindowReady;

  SensorController() {
    _windowSize = (sampleRateHz * windowSeconds).round(); // 100
    _hopSize = (sampleRateHz * hopSeconds).round();       // 50
    _tick = Duration(
      microseconds: (1e6 / sampleRateHz).round(),
    ); // ~20 ms
  }

  void startListening() {
    // Streams de sensores
    accelerometerEventStream().listen((event) {
      _ax = event.x; _ay = event.y; _az = event.z;
    });

    gyroscopeEventStream().listen((event) {
      _gx = event.x; _gy = event.y; _gz = event.z;
    });

    // Muestreo periódico a ~50Hz
    _samplingTimer = Timer.periodic(_tick, (_) {
      final now = DateTime.now();
      final sample = SensorSample(
        ax: _ax, ay: _ay, az: _az,
        gx: _gx, gy: _gy, gz: _gz,
        timestamp: now,
      );

      _buffer.addLast(sample);

      // Mantener el buffer razonable (hasta 2 ventanas por seguridad)
      final maxBuffer = _windowSize * 2;
      while (_buffer.length > maxBuffer) {
        _buffer.removeFirst();
      }

      // ¿Tenemos al menos una ventana? Emite con hop deslizante
      _maybeEmitWindow();
    });
  }

  void stopListening() {
    _samplingTimer?.cancel();
  }

  // Estado para controlar el "hop" (deslizamiento)
  int _sinceLastEmit = 0;

  void _maybeEmitWindow() {
    if (_buffer.length < _windowSize) {
      return; // aún no completa la primera ventana
    }

    _sinceLastEmit++;
    if (_sinceLastEmit < _hopSize) {
      return; // todavía no toca emitir (según hop)
    }
    _sinceLastEmit = 0;

    // Tomar la ventana más reciente (las últimas _windowSize muestras)
    final List<SensorSample> windowSamples = _buffer
        .toList()
        .sublist(_buffer.length - _windowSize);

    final startTime = windowSamples.first.timestamp;
    final endTime = windowSamples.last.timestamp;

    // Calcular features
    final features = _computeFeatures(windowSamples);

    final window = SensorWindow(
      startTime: startTime,
      endTime: endTime,
      sampleCount: windowSamples.length,
      sampleRateHz: sampleRateHz,
      samples: windowSamples,
      features: features,
    );

    onWindowReady?.call(window);
  }

  Map<String, double> _computeFeatures(List<SensorSample> s) {
    // Vectores por eje
    final ax = s.map((e) => e.ax).toList();
    final ay = s.map((e) => e.ay).toList();
    final az = s.map((e) => e.az).toList();
    final gx = s.map((e) => e.gx).toList();
    final gy = s.map((e) => e.gy).toList();
    final gz = s.map((e) => e.gz).toList();

    // Magnitudes
    final accNorm = List<double>.generate(s.length, (i) {
      return math.sqrt(ax[i]*ax[i] + ay[i]*ay[i] + az[i]*az[i]);
    });
    final gyroNorm = List<double>.generate(s.length, (i) {
      return math.sqrt(gx[i]*gx[i] + gy[i]*gy[i] + gz[i]*gz[i]);
    });

    final feats = <String, double>{};

    void addStats(String prefix, List<double> v) {
      final m = _mean(v);
      final st = _std(v, m);
      final mn = _min(v);
      final mx = _max(v);
      final rms = _rms(v);
      feats['${prefix}_mean'] = m;
      feats['${prefix}_std']  = st;
      feats['${prefix}_min']  = mn;
      feats['${prefix}_max']  = mx;
      feats['${prefix}_rms']  = rms;
    }

    addStats('ax', ax);
    addStats('ay', ay);
    addStats('az', az);
    addStats('gx', gx);
    addStats('gy', gy);
    addStats('gz', gz);
    addStats('acc_norm', accNorm);
    addStats('gyro_norm', gyroNorm);

    return feats;
  }

  double _mean(List<double> v) =>
      v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;

  double _std(List<double> v, double mean) {
    if (v.length < 2) return 0.0;
    double sum2 = 0.0;
    for (final x in v) {
      final d = x - mean;
      sum2 += d * d;
    }
    return math.sqrt(sum2 / (v.length - 1));
  }

  double _min(List<double> v) =>
      v.isEmpty ? 0.0 : v.reduce(math.min);

  double _max(List<double> v) =>
      v.isEmpty ? 0.0 : v.reduce(math.max);

  double _rms(List<double> v) {
    if (v.isEmpty) return 0.0;
    double s2 = 0.0;
    for (final x in v) {
      s2 += x * x;
    }
    return math.sqrt(s2 / v.length);
  }
}
