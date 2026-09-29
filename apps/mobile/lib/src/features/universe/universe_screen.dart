import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart' show GrowthStage, Vitality;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/perf/device_profile.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/help_app_bar.dart';
import '../capsules/capsules_list_screen.dart';
import '../habits/habits_section.dart';
import '../progress/progress_view.dart';
import '../sanctuary/sanctuary_activities.dart';
import 'roam.dart';
import 'roam_controls.dart';
import 'universe_scene.dart';
import 'universe_scene_view.dart';
import 'welcome_back.dart';
import 'world_habits.dart';

extension UniverseDestinationCopy on UniverseDestination {
  String title(AppLocalizations l) => switch (this) {
    UniverseDestination.grove => l.universe_grove,
    UniverseDestination.tidePool => l.universe_pool,
    UniverseDestination.reflection => l.universe_reflection,
    UniverseDestination.observatory => l.universe_observatory,
  };
  String description(AppLocalizations l) => switch (this) {
    UniverseDestination.grove => l.universe_groveBody,
    UniverseDestination.tidePool => l.universe_poolBody,
    UniverseDestination.reflection => l.universe_reflectionBody,
    UniverseDestination.observatory => l.universe_observatoryBody,
  };
  String action(AppLocalizations l) => switch (this) {
    UniverseDestination.grove => l.universe_habits,
    UniverseDestination.tidePool => l.universe_breathe,
    UniverseDestination.reflection => l.universe_checkIn,
    UniverseDestination.observatory => l.universe_capsules,
  };
  IconData get icon => switch (this) {
    UniverseDestination.grove => Icons.park_outlined,
    UniverseDestination.tidePool => Icons.water_outlined,
    UniverseDestination.reflection => Icons.auto_awesome_outlined,
    UniverseDestination.observatory => Icons.nightlight_outlined,
  };
}

extension _PlantCopy on AppLocalizations {
  String stageLabel(GrowthStage stage) => switch (stage) {
    GrowthStage.seed => universe_stage_seed,
    GrowthStage.sprout => universe_stage_sprout,
    GrowthStage.young => universe_stage_young,
    GrowthStage.grown => universe_stage_grown,
    GrowthStage.flourishing => universe_stage_flourishing,
    GrowthStage.ancient => universe_stage_ancient,
  };

  /// Only the states a person might want to know about; a thriving plant
  /// needs no extra word.
  String? vitalityLabel(Vitality v) => switch (v) {
    Vitality.thriving => null,
    Vitality.dimmed => universe_vitality_dimmed,
    Vitality.wilting => universe_vitality_wilting,
    Vitality.dormant => universe_vitality_dormant,
  };
}

/// A local world view over existing care tools. There is no separate reward
/// ledger, social presence or upload of private text to the renderer.
class UniverseScreen extends ConsumerStatefulWidget {
  const UniverseScreen({super.key});

  @override
  ConsumerState<UniverseScreen> createState() => _UniverseScreenState();
}

class _UniverseScreenState extends ConsumerState<UniverseScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  UniverseCamera _camera = const UniverseCamera();
  UniverseDestination _selected = UniverseDestination.grove;
  bool _listOnly = false;

  /// W05: optional free-roam mode. Tap-to-travel and the list stay available.
  bool _freeRoam = false;
  RoamInput _roamInput = RoamInput.zero;
  Ticker? _roamTicker;
  Duration _lastRoamTick = Duration.zero;
  bool _disposed = false;
  WorldPoint _from = const WorldPoint(0, 0.16, 0);
  WorldPoint _to = const WorldPoint(0, 0.16, 0);
  late final AnimationController _walk;
  IslandMesh? _mesh;
  double? _meshGrowth;
  List<WorldPlant>? _meshPlants;

  WorldPoint get _position =>
      WorldPoint.lerp(_from, _to, Curves.easeInOut.transform(_walk.value));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _walk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _roamTicker = createTicker(_onRoamTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) _walk.value = 1;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _walk.value = 1;
      _setRoamInput(RoamInput.zero);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _roamTicker?.dispose();
    _walk.dispose();
    super.dispose();
  }

  // ---- free roam (W05) -----------------------------------------------------
  // The ticker runs only while a direction is held: no idle loop, nothing in
  // the background, and a stalled frame never moves the companion far.

  void _setRoamInput(RoamInput input) {
    if (_disposed) return;
    _roamInput = input;
    final ticker = _roamTicker;
    if (ticker == null) return;
    if (input.isZero) {
      if (ticker.isActive) ticker.stop();
    } else if (!ticker.isActive) {
      _lastRoamTick = Duration.zero;
      ticker.start();
    }
  }

  void _onRoamTick(Duration elapsed) {
    final dt = (elapsed - _lastRoamTick).inMicroseconds / 1e6;
    _lastRoamTick = elapsed;
    _moveTo(stepRoam(_position, _roamInput, _camera, dt));
  }

  void _nudge(RoamInput input) =>
      _moveTo(nudgeRoam(_position, input, _camera));

  /// Puts the companion at [point] and, near a place, selects it so the care
  /// card (a live region) names it and its button acts on it.
  void _moveTo(WorldPoint point) {
    if (_disposed) return;
    final here = _position;
    if (point.x == here.x && point.z == here.z) return;
    _walk.stop();
    setState(() {
      _from = point;
      _to = point;
      _walk.value = 1;
      final near = nearestPlace(point);
      if (near != null) _selected = near;
    });
  }

  void _setFreeRoam(bool on) {
    _setRoamInput(RoamInput.zero);
    setState(() => _freeRoam = on);
  }

  void _select(UniverseDestination destination) {
    final current = _position;
    setState(() {
      _selected = destination;
      _from = current;
      _to = destination.avatarStop;
    });
    if (_listOnly || reduceMotionOf(context)) {
      _walk.value = 1;
    } else {
      _walk.forward(from: 0);
    }
  }

  void _open() {
    _walk.value = 1;
    switch (_selected) {
      case UniverseDestination.grove:
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => const SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: HabitsSection(),
          ),
        );
      case UniverseDestination.tidePool:
        openSanctuaryActivity(context, SanctuaryActivity.breathe);
      case UniverseDestination.reflection:
        context.push(Routes.checkIn);
      case UniverseDestination.observatory:
        openCapsulesList(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final growth = universeGrowth(
      ref.watch(progressViewProvider.select((v) => v.totalStarlight)),
    );
    // One plant per shown habit (RULES.md section 13). Until the first read
    // the grove keeps the aggregate fallback.
    final habits = ref.watch(worldHabitsProvider).value;
    final plants = habits == null
        ? null
        : [for (final h in habits) h.plant];
    return Scaffold(
      appBar: helpAppBar(context, title: l.universe_title),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                if (ref.watch(welcomeBackProvider).value ?? false) ...[
                  _WelcomeBack(
                    resting: habits?.where((h) => h.resting).length ?? 0,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(l.universe_intro, style: t.bodyLarge),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: const ValueKey('universe-view-toggle'),
                    icon: Icon(
                      _listOnly ? Icons.public : Icons.view_list_outlined,
                    ),
                    label: Text(
                      _listOnly ? l.universe_worldView : l.universe_listView,
                    ),
                    onPressed: () {
                      _walk.value = 1;
                      _setRoamInput(RoamInput.zero);
                      setState(() {
                        _listOnly = !_listOnly;
                        _freeRoam = false;
                      });
                    },
                  ),
                ),
                if (!_listOnly) ...[
                  SegmentedButton<bool>(
                    key: const ValueKey('universe-mode'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.touch_app_outlined),
                        label: Text(l.universe_tapToTravel),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.directions_walk_rounded),
                        label: Text(l.universe_freeRoam),
                      ),
                    ],
                    selected: {_freeRoam},
                    onSelectionChanged: (v) => _setFreeRoam(v.first),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: DeviceProfile.instance.prefersLowTier,
                    builder: (context, lowDetail, _) {
                      if (_mesh == null ||
                          _meshGrowth != growth ||
                          !listEquals(_meshPlants, plants) ||
                          _mesh!.lowDetail != lowDetail) {
                        _mesh = IslandMesh(
                          growth: growth,
                          lowDetail: lowDetail,
                          plants: plants,
                        );
                        _meshGrowth = growth;
                        _meshPlants = plants;
                      }
                      return LayoutBuilder(
                        builder: (context, box) => SizedBox(
                          height: math.min(
                            400,
                            math.max(250, box.maxWidth * 0.85),
                          ),
                          child: AnimatedBuilder(
                            animation: _walk,
                            builder: (context, _) => UniverseSceneView(
                              mesh: _mesh!,
                              camera: _camera,
                              companion: _position,
                              selected: _selected,
                              onOrbit: (h, v) =>
                                  setState(() => _camera = _camera.orbit(h, v)),
                              onSelect: _select,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      _cameraButton(
                        l.universe_left,
                        Icons.rotate_left,
                        () => _camera = _camera.orbit(-0.3, 0),
                      ),
                      _cameraButton(
                        l.universe_right,
                        Icons.rotate_right,
                        () => _camera = _camera.orbit(0.3, 0),
                      ),
                      _cameraButton(
                        l.universe_zoomIn,
                        Icons.add,
                        () => _camera = _camera.zoom(-0.5),
                      ),
                      _cameraButton(
                        l.universe_zoomOut,
                        Icons.remove,
                        () => _camera = _camera.zoom(0.5),
                      ),
                      _cameraButton(
                        l.universe_reset,
                        Icons.restart_alt,
                        () => _camera = const UniverseCamera(),
                      ),
                    ],
                  ),
                  Text(
                    _freeRoam ? l.universe_roamHint : l.universe_hint,
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_freeRoam) ...[
                    const SizedBox(height: 12),
                    RoamControls(
                      key: const ValueKey('universe-roam-controls'),
                      onInput: _setRoamInput,
                      onNudge: _nudge,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final destination in UniverseDestination.values)
                      Semantics(
                        selected: destination == _selected,
                        child: OutlinedButton.icon(
                          key: ValueKey('universe-${destination.name}'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            side: BorderSide(
                              color: destination == _selected
                                  ? AuraColors.starlight
                                  : AuraColors.controlOutline,
                            ),
                            foregroundColor: destination == _selected
                                ? AuraColors.onAccent
                                : null,
                            backgroundColor: destination == _selected
                                ? Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                : null,
                          ),
                          onPressed: () => _select(destination),
                          icon: Icon(destination.icon, size: 20),
                          label: Text(destination.title(l)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_selected.title(l), style: t.titleLarge),
                          const SizedBox(height: 8),
                          Text(_selected.description(l), style: t.bodyMedium),
                          if (_selected == UniverseDestination.grove &&
                              habits != null &&
                              habits.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _GrovePlants(habits: habits),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const ValueKey('universe-care-action'),
                            onPressed: _open,
                            icon: Icon(_selected.icon),
                            label: Text(_selected.action(l)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraButton(String label, IconData icon, VoidCallback change) =>
      IconButton(
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () => setState(change),
        icon: Icon(icon),
      );
}

/// The accessible twin of the grove (the renderer is excluded from
/// semantics): each habit's plant, its stage and, when it is resting, a warm
/// word for it. A plant that is thriving needs no extra word.
class _GrovePlants extends StatelessWidget {
  const _GrovePlants({required this.habits});
  final List<WorldHabit> habits;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final resting = habits.where((h) => h.resting).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (resting > 0) ...[
          Text(
            l.universe_plantsResting(resting),
            key: const ValueKey('universe-plants-resting'),
            style: t.bodyMedium,
          ),
          const SizedBox(height: 8),
        ],
        Semantics(
          header: true,
          child: Text(l.universe_yourPlants, style: t.titleSmall),
        ),
        const SizedBox(height: 4),
        for (final h in habits)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              key: ValueKey('universe-plant-${h.slot}'),
              children: [
                Icon(
                  h.resting ? Icons.bedtime_outlined : Icons.spa_outlined,
                  size: 18,
                  color: AuraColors.textSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(() {
                    final name = habitDisplayName(
                      l,
                      preset: h.input.preset,
                      name: h.input.name,
                    );
                    final stage = l.stageLabel(h.stage);
                    final state = l.vitalityLabel(h.vitality);
                    return state == null
                        ? l.universe_plantRow(name, stage)
                        : l.universe_plantRowResting(name, stage, state);
                  }(), style: t.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The one-time return card (W04): the world is intact, and nothing is asked.
/// Either action ends it for this absence. It never mentions days away,
/// streaks or what was missed; a resting plant gets the same warm line the
/// Grove uses.
class _WelcomeBack extends ConsumerWidget {
  const _WelcomeBack({required this.resting});
  final int resting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    void done() => ref.read(welcomeBackProvider.notifier).dismiss();
    return Semantics(
      liveRegion: true,
      child: Card(
        key: const ValueKey('universe-welcome'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.universe_welcomeTitle, style: t.titleLarge),
              const SizedBox(height: 8),
              Text(l.universe_welcomeBody, style: t.bodyMedium),
              if (resting > 0) ...[
                const SizedBox(height: 8),
                Text(l.universe_plantsResting(resting), style: t.bodyMedium),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const ValueKey('universe-welcome-checkin'),
                    onPressed: () {
                      done();
                      context.push(Routes.checkIn);
                    },
                    child: Text(l.universe_welcomeCheckIn),
                  ),
                  TextButton(
                    key: const ValueKey('universe-welcome-explore'),
                    onPressed: done,
                    child: Text(l.universe_welcomeExplore),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
