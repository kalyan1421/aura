import 'package:freezed_annotation/freezed_annotation.dart';

part 'reflection_models.freezed.dart';
part 'reflection_models.g.dart';

/// Wire shapes of `contracts/api/v1-reflections.md` ("Shapes").
///
/// DS-10: authors are only ever `{memberId, pseudonym}` of their room
/// membership; nothing here can hold an account id, age, report lane or
/// moderation score, so anything else a response carried is dropped while
/// parsing. Enum-like values stay strings on the wire (an unknown value from
/// a newer server never breaks parsing) with typed getters for the app.
///
/// Reflection text is never logged: no `toString` here is ever printed.

/// What the author may see of their own reflection (anything but
/// [published] only ever appears on your own).
enum ReflectionStatus {
  pending,
  published,
  held,
  rejected,
  removed,

  /// Only in a send answer and the author's `reflection_status` event.
  crisisDiverted,

  /// A status this build doesn't know (treated like [pending]: waiting).
  unknown;

  static ReflectionStatus fromWire(String? value) => switch (value) {
    'pending' => pending,
    'published' => published,
    'held' => held,
    'rejected' => rejected,
    'removed' => removed,
    'crisis_diverted' => crisisDiverted,
    _ => unknown,
  };
}

/// Why a reflection didn't go up (`RejectReason`).
enum RejectReason {
  contactDetails,
  link,
  personalQuestions,
  hurtful,
  sexual,
  other;

  static RejectReason? fromWire(String? value) => switch (value) {
    null => null,
    'contact_details' => contactDetails,
    'link' => link,
    'personal_questions' => personalQuestions,
    'hurtful' => hurtful,
    'sexual' => sexual,
    _ => other,
  };
}

/// `ReviewHint`: when a held (or pending) one may be decided.
enum ReviewHint {
  soon,

  /// The reviewer's night: "This may take until morning".
  overnight;

  static ReviewHint? fromWire(String? value) => switch (value) {
    'soon' => soon,
    'overnight' => overnight,
    _ => null,
  };
}

/// `ComposerState`.
enum ComposerState {
  open,

  /// 3 in this room in 24 h, or 10 across rooms.
  limitReached,

  /// Kill switch / reduced mode: "Reflections are resting for a bit."
  paused,

  /// The room is a memory.
  readOnly;

  static ComposerState fromWire(String? value) => switch (value) {
    'limit_reached' => limitReached,
    'paused' => paused,
    'read_only' => readOnly,
    _ => open,
  };
}

@freezed
abstract class ReflectionAuthor with _$ReflectionAuthor {
  const factory ReflectionAuthor({
    required String memberId,

    /// The room pseudonym ("Quiet Comet"); never translated.
    required String pseudonym,
  }) = _ReflectionAuthor;

  factory ReflectionAuthor.fromJson(Map<String, dynamic> json) =>
      _$ReflectionAuthorFromJson(json);
}

@freezed
abstract class Reflection with _$Reflection {
  const factory Reflection({
    required String reflectionId,
    @Default('published') String status,
    required ReflectionAuthor author,
    @Default(false) bool isMine,

    /// As written (never translated). Never logged.
    @Default('') String text,
    required DateTime createdAt,
    DateTime? publishedAt,

    /// Delivered gestures on it: your own published ones only.
    int? gestureCount,
    String? rejectReason,
    String? review,
  }) = _Reflection;

  const Reflection._();

  factory Reflection.fromJson(Map<String, dynamic> json) =>
      _$ReflectionFromJson(json);

  ReflectionStatus get statusValue => ReflectionStatus.fromWire(status);
  RejectReason? get rejectReasonValue => RejectReason.fromWire(rejectReason);
  ReviewHint? get reviewValue => ReviewHint.fromWire(review);

  bool get isPublished => statusValue == ReflectionStatus.published;
}

@freezed
abstract class ReflectionComposer with _$ReflectionComposer {
  const factory ReflectionComposer({
    @Default('open') String state,
    @Default(200) int maxChars,
    @Default(3) int perRoom,

    /// "2 of 3 left today" (rolling 24 h).
    @Default(3) int remainingInRoom,

    /// Of 10 across rooms (rolling 24 h).
    @Default(10) int remainingToday,

    /// The automatic check is degraded: "Reflections are slower right now".
    @Default(false) bool slow,
  }) = _ReflectionComposer;

  const ReflectionComposer._();

  factory ReflectionComposer.fromJson(Map<String, dynamic> json) =>
      _$ReflectionComposerFromJson(json);

  ComposerState get stateValue => ComposerState.fromWire(state);

  bool get isOpen => stateValue == ComposerState.open;
}

/// `GET /v1/rooms/:roomId/reflections`.
@freezed
abstract class ReflectionList with _$ReflectionList {
  const factory ReflectionList({
    /// Newest first (by `createdAt`; no ranking).
    @Default(<Reflection>[]) List<Reflection> reflections,
    @Default(ReflectionComposer()) ReflectionComposer composer,
  }) = _ReflectionList;

  factory ReflectionList.fromJson(Map<String, dynamic> json) =>
      _$ReflectionListFromJson(json);
}

/// `POST /v1/rooms/:roomId/reflections` → `SendOutcome`.
@freezed
abstract class SendOutcome with _$SendOutcome {
  const factory SendOutcome({
    required String reflectionId,
    required String status,
    String? rejectReason,
    String? review,

    /// `crisis_diverted` only: open the F9 support sheet at once.
    @Default(false) bool showSupport,

    /// The stored item (null for rejected-by-rules and crisis_diverted).
    Reflection? reflection,
    @Default(ReflectionComposer()) ReflectionComposer composer,
  }) = _SendOutcome;

  const SendOutcome._();

  factory SendOutcome.fromJson(Map<String, dynamic> json) =>
      _$SendOutcomeFromJson(json);

  ReflectionStatus get statusValue => ReflectionStatus.fromWire(status);
  RejectReason? get rejectReasonValue => RejectReason.fromWire(rejectReason);
  ReviewHint? get reviewValue => ReviewHint.fromWire(review);
}
