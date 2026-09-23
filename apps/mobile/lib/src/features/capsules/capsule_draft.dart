import 'dart:convert';
import 'dart:io';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/widgets.dart';

import '../../core/db/kv_store.dart';
import '../voice/voice_note_field.dart';
import '../voice/voice_store.dart';
import 'capsule_payload.dart';
import 'capsule_repository.dart';

/// How the composer's unlock choice is set.
enum CapsuleUnlockKind { date, feeling }

/// The capsule being written (F4 composer). Kept on this phone until it is
/// sealed or discarded (PRD 14-states "never lose input"): see
/// [CapsuleDraftStore]. [id] becomes the capsule's id when sealed, so a
/// retried seal after a crash is the same capsule.
///
/// Also the voice field's draft ([VoiceDraftBinding]): one recording, ≤ 2:00.
class CapsuleDraft extends ChangeNotifier implements VoiceDraftBinding {
  CapsuleDraft({
    required this.id,
    String title = '',
    String text = '',
    this._kind,
    this._date,
    this._moodId,
    this._quadrant,
    this._voice,
    List<CapsulePhotoDraft> photos = const [],
    this.promptTurn = 0,
  }) : title = TextEditingController(text: title),
       text = TextEditingController(text: text),
       photos = [...photos] {
    this.title.addListener(notifyListeners);
    this.text.addListener(notifyListeners);
  }

  final String id;
  final TextEditingController title;
  final TextEditingController text;
  final List<CapsulePhotoDraft> photos;

  /// "Another prompt" taps (the guided prompt rotates; never saved inside).
  int promptTurn;

  CapsuleUnlockKind? _kind;
  LocalDay? _date;
  String? _moodId;
  Quadrant? _quadrant;
  VoiceClip? _voice;
  bool _recording = false;
  Future<void> Function()? _finishRecording;

  CapsuleUnlockKind? get kind => _kind;
  LocalDay? get date => _date;
  String? get moodId => _moodId;
  Quadrant? get quadrant => _quadrant;

  set kind(CapsuleUnlockKind? value) {
    if (value == _kind) return;
    _kind = value;
    notifyListeners();
  }

  set date(LocalDay? value) {
    _date = value;
    _kind = CapsuleUnlockKind.date;
    notifyListeners();
  }

  /// One mood as the trigger (clears a quadrant).
  void pickMood(String moodId) {
    _moodId = moodId;
    _quadrant = null;
    _kind = CapsuleUnlockKind.feeling;
    notifyListeners();
  }

  /// A whole quadrant as the trigger (clears a mood).
  void pickQuadrant(Quadrant quadrant) {
    _quadrant = quadrant;
    _moodId = null;
    _kind = CapsuleUnlockKind.feeling;
    notifyListeners();
  }

  /// The unlock as chosen, or `null` while incomplete.
  CapsuleUnlock? get unlock => switch (_kind) {
    CapsuleUnlockKind.date => _date == null ? null : DateUnlock(_date!),
    CapsuleUnlockKind.feeling =>
      _moodId != null
          ? MoodUnlock.mood(_moodId!)
          : _quadrant != null
          ? MoodUnlock.quadrant(_quadrant!)
          : null,
    null => null,
  };

  /// The quadrant a feeling capsule waits for (guides the prompt).
  Quadrant? get targetQuadrant =>
      _quadrant ?? (_moodId == null ? null : moodById(_moodId!)?.quadrant);

  bool get hasContent =>
      title.text.trim().isNotEmpty ||
      text.text.trim().isNotEmpty ||
      _voice != null ||
      photos.isNotEmpty;

  /// Something is written, recorded, picked or chosen: leaving asks first.
  bool get hasInput => hasContent || _kind != null || _recording;

  CapsuleContent get content => CapsuleContent(
    title: title.text,
    text: text.text,
    voice: _voice == null
        ? null
        : CapsuleVoiceDraft(path: _voice!.path, duration: _voice!.duration),
    photos: List.unmodifiable(photos),
  );

  // ---- photos ------------------------------------------------------------------

  bool get atPhotoLimit => photos.length >= maxCapsulePhotos;

  void addPhoto(CapsulePhotoDraft photo) {
    if (atPhotoLimit) {
      _deletePath(photo.path);
      return;
    }
    photos.add(photo);
    notifyListeners();
  }

  void removePhoto(int index) {
    if (index < 0 || index >= photos.length) return;
    _deletePath(photos.removeAt(index).path);
    notifyListeners();
  }

  // ---- voice (VoiceDraftBinding) ------------------------------------------------

  @override
  VoiceClip? get newVoice => _voice;

  @override
  SavedVoice? get savedVoice => null;

  @override
  bool get keepsSavedVoice => false;

  bool get isRecording => _recording;

  @override
  set isRecording(bool value) {
    if (value == _recording) return;
    _recording = value;
    notifyListeners();
  }

  @override
  void recordingDropped() => _recording = false;

  @override
  void setNewVoice(VoiceClip clip) {
    if (_voice?.path != clip.path) _deletePath(_voice?.path);
    _voice = clip;
    notifyListeners();
  }

  @override
  void removeVoice() {
    _deletePath(_voice?.path);
    _voice = null;
    notifyListeners();
  }

  @override
  void attachRecorder(Future<void> Function()? finish) =>
      _finishRecording = finish;

  /// Stops a recording in progress and keeps it (Seal calls this first).
  Future<void> finishVoice() async => _finishRecording?.call();

  static void _deletePath(String? path) {
    if (path == null) return;
    try {
      File(path).deleteSync();
    } on FileSystemException {
      // Already moved (sealed) or gone.
    }
  }

  // ---- persistence ---------------------------------------------------------------

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title.text,
    'text': text.text,
    'kind': _kind?.name,
    'date': _date?.toIso(),
    'moodId': _moodId,
    'quadrant': _quadrant?.name,
    'voice': _voice == null
        ? null
        : {'path': _voice!.path, 'ms': _voice!.duration.inMilliseconds},
    'photos': [
      for (final p in photos) {'path': p.path, 'w': p.width, 'h': p.height},
    ],
    'promptTurn': promptTurn,
  };

  /// Restores a kept draft; media files that no longer exist are left out.
  static CapsuleDraft fromJson(Map<String, dynamic> j) {
    final v = j['voice'] as Map<String, dynamic>?;
    final voicePath = v?['path'] as String?;
    return CapsuleDraft(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      text: (j['text'] as String?) ?? '',
      kind: switch (j['kind']) {
        'date' => CapsuleUnlockKind.date,
        'feeling' => CapsuleUnlockKind.feeling,
        _ => null,
      },
      date: parseCalendarDate(j['date'] as String?),
      moodId: j['moodId'] as String?,
      quadrant: j['quadrant'] == null
          ? null
          : quadrantByName(j['quadrant'] as String),
      voice: voicePath != null && File(voicePath).existsSync()
          ? VoiceClip(
              path: voicePath,
              duration: Duration(milliseconds: (v!['ms'] as num).toInt()),
            )
          : null,
      photos: [
        for (final p in (j['photos'] as List<dynamic>?) ?? const [])
          if (p is Map<String, dynamic> &&
              File(p['path'] as String).existsSync())
            CapsulePhotoDraft(
              path: p['path'] as String,
              width: (p['w'] as num).toInt(),
              height: (p['h'] as num).toInt(),
            ),
      ],
      promptTurn: (j['promptTurn'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  void dispose() {
    title.dispose();
    text.dispose();
    super.dispose();
  }
}

/// The one capsule draft kept on this phone (plaintext inside the encrypted
/// database, like an unsaved check-in note; wiped at sign-out).
class CapsuleDraftStore {
  CapsuleDraftStore(this._kv);

  final KvStore _kv;

  static const String key = 'capsules.draft';

  Future<CapsuleDraft?> load() async {
    try {
      final j = await _kv.getJson(key);
      return j == null ? null : CapsuleDraft.fromJson(j);
    } on Object catch (e) {
      debugPrint('capsules: draft unreadable (${e.runtimeType})');
      return null;
    }
  }

  /// The draft's id, if one is kept (its media folder must not be swept).
  Future<String?> keptId() async {
    try {
      return (await _kv.getJson(key))?['id'] as String?;
    } on Object {
      return null;
    }
  }

  Stream<bool> watchHasDraft() => _kv.watch(key).map((v) => v != null);

  Future<void> save(CapsuleDraft draft) =>
      _kv.set(key, jsonEncode(draft.toJson()));

  Future<void> clear() => _kv.set(key, null);
}
