// T01 benchmark: the personal universe through the Canvas renderer, then through
// the GPU renderer, on the phone it runs on. Hands-off: it orbits the camera and
// walks the companion for a fixed time in each renderer and reports frame times.
// It touches no personal data, no database and no network.
//
//   flutter run --profile -d <device> -t lib/universe_bench.dart
//
// (Debug builds and simulators say nothing about real speed: use profile on a
// phone.) Results are printed as `AURA_BENCH {json}` lines and shown on screen.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show ProcessInfo;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aura_domain/aura_domain.dart'
    show GrowthStage, SkyPhase, Vitality;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'src/features/universe/native/native_scene_view.dart';
import 'src/features/universe/native/scene_probe.dart';
import 'src/features/universe/universe_scene.dart';
import 'src/features/universe/universe_scene_view.dart';

const Duration _phaseLength = Duration(seconds: 8);

/// `--dart-define=BENCH_HOLD=canvas|gpu`: no timing, just that renderer on
/// screen with the camera frozen (for comparing the two pictures).
const String _hold = String.fromEnvironment('BENCH_HOLD');

void main() => runApp(const _BenchApp());

class _BenchApp extends StatelessWidget {
  const _BenchApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const _Bench(),
  );
}

class _PhaseResult {
  _PhaseResult(this.name);
  final String name;
  final List<double> buildMs = [];
  final List<double> rasterMs = [];
  final List<double> totalMs = [];
  int rssMb = 0;
  String note = '';

  static double _p(List<double> v, double q) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    return s[math.min(s.length - 1, (s.length * q).floor())];
  }

  static double _avg(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  Map<String, Object> toJson(double refreshHz) {
    final budget = 1000 / refreshHz;
    return {
      'phase': name,
      'frames': totalMs.length,
      'fps': double.parse(
        (totalMs.length / _phaseLength.inSeconds).toStringAsFixed(1),
      ),
      'buildMsAvg': double.parse(_avg(buildMs).toStringAsFixed(2)),
      'rasterMsAvg': double.parse(_avg(rasterMs).toStringAsFixed(2)),
      'rasterMsP95': double.parse(_p(rasterMs, 0.95).toStringAsFixed(2)),
      'totalMsP95': double.parse(_p(totalMs, 0.95).toStringAsFixed(2)),
      'totalMsMax': double.parse(
        (totalMs.isEmpty ? 0 : totalMs.reduce(math.max)).toStringAsFixed(2),
      ),
      'framesOverBudget': totalMs.where((t) => t > budget * 1.1).length,
      'budgetMs': double.parse(budget.toStringAsFixed(2)),
      'rssMb': rssMb,
      if (note.isNotEmpty) 'note': note,
    };
  }
}

class _Bench extends StatefulWidget {
  const _Bench();

  @override
  State<_Bench> createState() => _BenchState();
}

class _BenchState extends State<_Bench> with SingleTickerProviderStateMixin {
  late final IslandMesh _mesh = IslandMesh(
    growth: 1,
    litStones: 12,
    plants: [
      for (var i = 0; i < maxWorldPlants; i++)
        WorldPlant(
          slot: i,
          stage: GrowthStage.values[(i + 2) % GrowthStage.values.length],
          vitality: Vitality.values[i % Vitality.values.length],
        ),
    ],
  );

  late final Ticker _ticker;
  final List<_PhaseResult> _results = [];
  _PhaseResult? _current;
  String _phase = 'starting';
  bool _gpuAvailable = false;
  bool _done = false;
  double _refreshHz = 60;
  Duration _phaseStart = Duration.zero;
  Duration _elapsed = Duration.zero;
  final Stopwatch _wall = Stopwatch();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      _elapsed = e;
      if (_hold.isEmpty &&
          _current != null &&
          e - _phaseStart >= _phaseLength) {
        _endPhase();
      } else {
        setState(() {});
      }
    });
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // After the first frame: the view (refresh rate, size) is readable then.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    super.dispose();
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    final cur = _current;
    if (cur == null) return;
    for (final t in timings) {
      cur.buildMs.add(t.buildDuration.inMicroseconds / 1000);
      cur.rasterMs.add(t.rasterDuration.inMicroseconds / 1000);
      cur.totalMs.add(t.totalSpan.inMicroseconds / 1000);
    }
  }

  Future<void> _run() async {
    final view = View.of(context);
    _refreshHz = view.display.refreshRate;
    _gpuAvailable =
        !const bool.fromEnvironment('BENCH_NOGPU') &&
        await nativeSceneAvailable();
    debugPrint(
      'AURA_BENCH ${jsonEncode({'start': true, 'gpuAvailable': _gpuAvailable, 'refreshHz': _refreshHz, 'devicePixelRatio': view.devicePixelRatio, 'size': '${view.physicalSize}'})}',
    );
    if (_hold.isNotEmpty) {
      setState(() => _phase = _hold);
      return;
    }
    for (final name in ['canvas', if (_gpuAvailable) 'gpu']) {
      await _phaseRun(name);
    }
    if (!_gpuAvailable) {
      final r = _PhaseResult('gpu')..note = 'unavailable on this device/build';
      _results.add(r);
      debugPrint('AURA_BENCH ${jsonEncode(r.toJson(_refreshHz))}');
    }
    _ticker.stop();
    debugPrint('AURA_BENCH ${jsonEncode({'done': true})}');
    if (mounted) setState(() => _done = true);
  }

  Future<void> _phaseRun(String name) async {
    setState(() {
      _phase = name;
      _current = null;
    });
    // Let the view settle (the GPU view loads its scene) before measuring.
    if (!_ticker.isActive) _ticker.start();
    await Future<void>.delayed(const Duration(seconds: 2));
    final r = _PhaseResult(name);
    _phaseStart = _elapsed;
    _current = r;
    _wall.reset();
    _wall.start();
    final done = Completer<void>();
    _phaseDone = done;
    await done.future;
  }

  Completer<void>? _phaseDone;

  void _endPhase() {
    final r = _current!;
    r.rssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    _current = null;
    _results.add(r);
    debugPrint('AURA_BENCH ${jsonEncode(r.toJson(_refreshHz))}');
    _phaseDone?.complete();
  }

  @override
  Widget build(BuildContext context) {
    final t = _hold.isNotEmpty ? 3.0 : _elapsed.inMicroseconds / 1e6;
    final camera = UniverseCamera(
      yaw: 0.18 + t * 0.7,
      pitch: 0.66,
      distance: 7.8 + math.sin(t * 0.8) * 1.2,
    );
    final companion = WorldPoint(
      math.cos(t * 0.9) * 1.0,
      0.16,
      math.sin(t * 0.9) * 1.0,
    );
    final pose = CompanionPose.still;
    Widget scene(String which) => SizedBox(
      height: 400,
      child: which == 'gpu'
          ? NativeSceneView(
              mesh: _mesh,
              camera: camera,
              companion: companion,
              selected: UniverseDestination.grove,
              sky: SkyPhase.day,
              pose: pose,
              onOrbit: (_, _) {},
              onSelect: (_) {},
              onUnavailable: () {},
            )
          : UniverseSceneView(
              mesh: _mesh,
              camera: camera,
              companion: companion,
              selected: UniverseDestination.grove,
              sky: SkyPhase.day,
              pose: pose,
              onOrbit: (_, _) {},
              onSelect: (_) {},
            ),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _done ? 'Benchmark done' : 'Benchmark: $_phase',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (!_done) scene(_phase == 'gpu' ? 'gpu' : 'canvas'),
            const SizedBox(height: 12),
            for (final r in _results)
              Text(
                '${r.name}: ${r.toJson(_refreshHz)}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
