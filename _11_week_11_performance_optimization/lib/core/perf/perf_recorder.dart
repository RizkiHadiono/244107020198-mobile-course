import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Satu frame hasil pengukuran engine.
class FrameSample {
  const FrameSample({
    required this.frameNumber,
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
  });

  final int frameNumber;
  final double buildMs;
  final double rasterMs;
  final double totalMs;

  bool get isJank => math.max(buildMs, rasterMs) > PerfRecorder.frameBudgetMs;

  Map<String, Object?> toJson() => {
    'frame': frameNumber,
    'build': double.parse(buildMs.toStringAsFixed(3)),
    'raster': double.parse(rasterMs.toStringAsFixed(3)),
    'total': double.parse(totalMs.toStringAsFixed(3)),
    'jank': isJank,
  };
}

/// Perekam metrik performa berbasis `SchedulerBinding.addTimingsCallback`.
///
/// Sumber datanya sama dengan yang dipakai Flutter DevTools untuk menggambar
/// *frame chart* (UI thread = build, Raster thread = raster), sehingga angka
/// yang dilaporkan dapat diverifikasi ulang lewat DevTools.
///
/// Saat [enabled] bernilai `false` (build normal), seluruh method menjadi
/// no-op sehingga tidak menambah overhead pada aplikasi produksi.
class PerfRecorder {
  PerfRecorder._();

  static final PerfRecorder instance = PerfRecorder._();

  /// Aktif hanya jika dijalankan dengan `--dart-define=PERF_MODE=true`.
  static const bool enabled = bool.fromEnvironment('PERF_MODE');

  /// Budget frame 60 FPS.
  static const double frameBudgetMs = 1000 / 60;

  final List<FrameSample> frames = <FrameSample>[];
  final Map<String, int> buildCounts = <String, int>{};

  bool _attached = false;
  bool _recording = false;
  int? _loadStartMicros;
  double? _firstFrameMs;

  bool get isRecording => _recording;

  /// Dipanggil sekali di `main()` sebelum `runApp`.
  void start() {
    if (!enabled) return;
    _loadStartMicros = DateTime.now().microsecondsSinceEpoch;
    if (!_attached) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _attached = true;
    }
    _recording = true;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_recording) return;
    for (final t in timings) {
      final build = t.buildDuration.inMicroseconds / 1000.0;
      final raster = t.rasterDuration.inMicroseconds / 1000.0;
      frames.add(
        FrameSample(
          frameNumber: t.frameNumber,
          buildMs: build,
          rasterMs: raster,
          totalMs: t.totalSpan.inMicroseconds / 1000.0,
        ),
      );
    }
  }

  /// Mencatat waktu frame pertama tampil (cold start).
  void markFirstFrame() {
    if (!enabled || _firstFrameMs != null) return;
    final start = _loadStartMicros;
    if (start == null) return;
    _firstFrameMs =
        (DateTime.now().microsecondsSinceEpoch - start) / 1000.0;
  }

  /// Menghitung berapa kali sebuah widget dibangun ulang.
  ///
  /// Sengaja dipanggil dari dalam `build()` widget yang diuji. Ketika
  /// [enabled] false, biayanya hanya satu pengecekan boolean statis.
  void countBuild(String widgetName) {
    if (!enabled || !_recording) return;
    buildCounts[widgetName] = (buildCounts[widgetName] ?? 0) + 1;
  }

  void reset() {
    frames.clear();
    buildCounts.clear();
  }

  void stop() {
    _recording = false;
  }

  double get _avgBuild => _average(frames.map((f) => f.buildMs));
  double get _avgRaster => _average(frames.map((f) => f.rasterMs));

  double _average(Iterable<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _percentile(List<double> values, double p) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final index = ((sorted.length - 1) * p).round();
    return sorted[index];
  }

  Map<String, Object?> summary() {
    final totals = frames.map((f) => math.max(f.buildMs, f.rasterMs)).toList();
    final jank = frames.where((f) => f.isJank).toList();
    final imageCache = PaintingBinding.instance.imageCache;

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'frameBudgetMs': frameBudgetMs,
      'frameCount': frames.length,
      'jankCount': jank.length,
      'jankRatio': frames.isEmpty ? 0 : jank.length / frames.length,
      'avgBuildMs': double.parse(_avgBuild.toStringAsFixed(3)),
      'avgRasterMs': double.parse(_avgRaster.toStringAsFixed(3)),
      'avgFrameMs': double.parse(_average(totals).toStringAsFixed(3)),
      'p90FrameMs': double.parse(_percentile(totals, 0.90).toStringAsFixed(3)),
      'worstFrameMs': double.parse(
        (totals.isEmpty ? 0 : totals.reduce(math.max)).toStringAsFixed(3),
      ),
      'worstBuildMs': double.parse(
        (frames.isEmpty
                ? 0
                : frames.map((f) => f.buildMs).reduce(math.max))
            .toStringAsFixed(3),
      ),
      'worstRasterMs': double.parse(
        (frames.isEmpty
                ? 0
                : frames.map((f) => f.rasterMs).reduce(math.max))
            .toStringAsFixed(3),
      ),
      'firstFrameMs': _firstFrameMs == null
          ? null
          : double.parse(_firstFrameMs!.toStringAsFixed(3)),
      'buildCounts': Map<String, int>.from(buildCounts),
      'imageCacheCount': imageCache.currentSize,
      'imageCacheBytes': imageCache.currentSizeBytes,
      'frames': frames.map((f) => f.toJson()).toList(),
    };
  }
}
