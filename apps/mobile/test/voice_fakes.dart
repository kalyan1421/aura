import 'dart:async';
import 'dart:io';

import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/voice/voice_devices.dart';
import 'package:aura/src/features/voice/voice_loader.dart';
import 'package:aura/src/features/voice/voice_store.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Test doubles for voice notes: no microphone, speaker or platform channel.

/// A microphone that behaves like iOS: the OS prompt is shown at most once.
class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.granted = false, this.promptAnswer = true});

  /// What the OS currently allows.
  bool granted;

  /// What the one-time OS prompt resolves to.
  bool promptAnswer;
  bool _answered = false;

  int prompts = 0;
  final List<String> started = [];
  int stops = 0;
  int cancels = 0;
  int levelListeners = 0;
  Object? startError;
  final levelsCtrl = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission({bool request = false}) async {
    if (!granted && request && !_answered) {
      prompts++;
      _answered = true;
      granted = promptAnswer;
    }
    return granted;
  }

  @override
  Future<void> start(String path) async {
    final e = startError;
    if (e != null) throw e;
    started.add(path);
  }

  @override
  Future<String?> stop() async {
    stops++;
    return started.isEmpty ? null : started.last;
  }

  @override
  Future<void> cancel() async => cancels++;

  @override
  Stream<double> levels() {
    levelListeners++;
    return levelsCtrl.stream;
  }

  @override
  Future<void> dispose() async {}
}

class FakePlayer implements VoicePlayer {
  final List<String> played = [];
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  bool disposed = false;
  final positionCtrl = StreamController<Duration>.broadcast();
  final durationCtrl = StreamController<Duration>.broadcast();
  final completedCtrl = StreamController<void>.broadcast();

  @override
  Future<void> play(String path) async => played.add(path);
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> resume() async => resumes++;
  @override
  Future<void> stop() async => stops++;
  @override
  Stream<Duration> get position => positionCtrl.stream;
  @override
  Stream<Duration> get duration => durationCtrl.stream;
  @override
  Stream<void> get completed => completedCtrl.stream;
  @override
  Future<void> dispose() async => disposed = true;
}

class FakePlatform implements AuraPlatform {
  int settingsOpened = 0;
  final List<String> excluded = [];

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<void> excludeFromBackup(String path) async => excluded.add(path);
}

/// A voice store that never touches the disk (widget tests run in fake
/// async): drafts get made-up paths, adopting just keeps the name.
class FakeVoiceStore extends VoiceStore {
  FakeVoiceStore()
    : super(
        root: () async => Directory.systemTemp,
        temp: () async => Directory.systemTemp,
      );

  int _n = 0;
  final List<String> adopted = [];
  final List<String> tempsDeleted = [];
  bool failAdopt = false;

  @override
  Future<String> newDraftPath() async => '/fake/voice/drafts/rec-${_n++}.m4a';

  @override
  Future<String> adopt(String draftPath) async {
    if (failAdopt) throw const VoiceStoreException('write_failed');
    final name = draftPath.split('/').last;
    adopted.add(name);
    return name;
  }

  @override
  Future<void> delete(String? name) async {}

  @override
  Future<void> deleteTemp(String path) async => tempsDeleted.add(path);

  @override
  Future<void> wipe() async {}
}

/// A loader that answers from a script.
class FakeLoader extends VoiceLoader {
  FakeLoader(this.answer)
    : super(
        store: FakeVoiceStore(),
        api: null,
        cipher: ({bool fetch = false}) async => null,
        online: () => true,
      );

  Future<VoiceSource> Function(String id, String? file, String? path) answer;
  int loads = 0;

  @override
  Future<VoiceSource> load({
    required String checkInId,
    String? file,
    String? path,
  }) {
    loads++;
    return answer(checkInId, file, path);
  }
}

/// Provider overrides for widget tests (on top of `testOverrides`).
List<Override> voiceOverrides({
  FakeRecorder? recorder,
  FakePlayer? player,
  FakePlatform? platform,
  FakeVoiceStore? store,
  VoiceLoader? loader,
}) => [
  voiceRecorderFactoryProvider.overrideWithValue(
    () => recorder ?? FakeRecorder(granted: true),
  ),
  voicePlayerFactoryProvider.overrideWithValue(() => player ?? FakePlayer()),
  auraPlatformProvider.overrideWithValue(platform ?? FakePlatform()),
  voiceStoreProvider.overrideWithValue(store ?? FakeVoiceStore()),
  if (loader != null) voiceLoaderProvider.overrideWithValue(loader),
];
