import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'room_models.freezed.dart';
part 'room_models.g.dart';

/// Wire shapes of `contracts/api/v1-rooms.md` ("Shared shapes").
///
/// DS-10: other people are only ever `{memberId, pseudonym, silhouette,
/// moodChip}`. These models have no field that could hold an account id,
/// email, age or date of birth, so anything else a response carried is
/// dropped while parsing: the app can't show or keep it. Enum-like values
/// stay strings on the wire (an unknown value from a newer server never
/// breaks parsing) with typed getters for the app.

// ---- enums ------------------------------------------------------------------

/// The 8 preset gestures (F5). [wire] is the API key.
enum GestureType {
  warmTea('warm_tea'),
  lightACandle('light_a_candle'),
  hug('hug'),
  meToo('me_too'),
  softRain('soft_rain'),
  stargaze('stargaze'),
  deepBreath('deep_breath'),
  youreNotAlone('youre_not_alone');

  const GestureType(this.wire);

  final String wire;

  /// `null` for a key this build doesn't know (it is then not shown).
  static GestureType? fromWire(String? value) {
    for (final g in values) {
      if (g.wire == value) return g;
    }
    return null;
  }
}

/// A room's life (contracts §4.1): forming → open ⇄ lantern hour →
/// closing (20 h) → memory (24 h, read-only) → purged (404).
enum RoomPhase {
  forming,
  open,
  lanternHour,
  closing,
  memory;

  static RoomPhase fromWire(String? value) => switch (value) {
    'forming' => forming,
    'lantern_hour' => lanternHour,
    'closing' => closing,
    'memory' => memory,
    _ => open,
  };
}

/// Report reasons, one tap (PRD 06b; the int is the wire value, never
/// reused). Listed in the order the sheet shows them: "Something else"
/// stays last, so 9 comes before 8. Lanes are server-only and never shown.
enum ReportReason {
  inDanger(1),
  harassment(2),
  sexual(3),
  hate(4),
  contactInfo(5),
  spam(6),
  under13(7),

  /// "Seems to be targeting a young person": the Minors & grooming lane on
  /// the server, whatever anyone's age. Nobody's age is ever shown.
  targetingYoungPerson(9),
  other(8);

  const ReportReason(this.wire);

  final int wire;
}

/// "Did you feel less alone?" (§1.7), aggregate only on the server.
enum SurveyAnswer { yes, no, skip }

/// What a report is about (§2.1).
@immutable
sealed class ReportTarget {
  const ReportTarget(this.roomId);

  final String roomId;

  Map<String, dynamic> toJson();
}

class MemberReportTarget extends ReportTarget {
  const MemberReportTarget(super.roomId, this.memberId);

  final String memberId;

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'member',
    'roomId': roomId,
    'memberId': memberId,
  };
}

class GestureReportTarget extends ReportTarget {
  const GestureReportTarget(super.roomId, this.gestureId);

  final String gestureId;

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'gesture',
    'roomId': roomId,
    'gestureId': gestureId,
  };
}

class RoomReportTarget extends ReportTarget {
  const RoomReportTarget(super.roomId);

  @override
  Map<String, dynamic> toJson() => {'kind': 'room', 'roomId': roomId};
}

/// A reflection (F6, contracts/api/v1-reflections.md §1.6): it hides for
/// the reporter at once; the author is never told who reported.
class ReflectionReportTarget extends ReportTarget {
  const ReflectionReportTarget(super.roomId, this.reflectionId);

  final String reflectionId;

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'reflection',
    'roomId': roomId,
    'reflectionId': reflectionId,
  };
}

// ---- shared shapes ------------------------------------------------------------

@freezed
abstract class LanternHour with _$LanternHour {
  const factory LanternHour({
    /// The room's region clock (e.g. `Asia/Kolkata`).
    @Default('') String timezone,
    @Default(false) bool active,

    /// The current window while [active], else the next one.
    required DateTime startsAt,
    required DateTime endsAt,
  }) = _LanternHour;

  factory LanternHour.fromJson(Map<String, dynamic> json) =>
      _$LanternHourFromJson(json);
}

@freezed
abstract class RoomInfo with _$RoomInfo {
  const factory RoomInfo({
    required String roomId,
    required String quadrant,
    @Default('') String theme,
    @Default('open') String state,
    @Default(false) bool readOnly,
    required DateTime createdAt,

    /// No new members after this ("closing").
    required DateTime joinsCloseAt,

    /// Read-only memory from here ("becomes a memory at …").
    required DateTime memoryAt,
    required DateTime purgeAt,
    required LanternHour lanternHour,
  }) = _RoomInfo;

  const RoomInfo._();

  factory RoomInfo.fromJson(Map<String, dynamic> json) =>
      _$RoomInfoFromJson(json);

  RoomPhase get phase => RoomPhase.fromWire(state);

  /// Read-only: gestures rest; report, block, mute and leave still work.
  bool get isMemory => readOnly || phase == RoomPhase.memory;

  /// The room's quadrant; an unknown name falls back to Moonlight for
  /// colour only (every screen also names the theme).
  Quadrant get quadrantValue => quadrantByName(quadrant) ?? Quadrant.moonlight;
}

/// Real members only: no bots, echoes, staff or inflated numbers.
@freezed
abstract class RoomCounts with _$RoomCounts {
  const factory RoomCounts({
    /// Current members seen in the last 2 min.
    @Default(0) int hereNow,

    /// Everyone who has been a member of this room (it lives 24 h).
    @Default(0) int today,
  }) = _RoomCounts;

  factory RoomCounts.fromJson(Map<String, dynamic> json) =>
      _$RoomCountsFromJson(json);
}

/// Stage, a 30°-bucketed hue and (after F12) one standard cosmetic: never a
/// fingerprint.
@freezed
abstract class Silhouette with _$Silhouette {
  const factory Silhouette({
    @Default('spark') String stage,
    double? hue,
    String? cosmetic,
  }) = _Silhouette;

  const Silhouette._();

  factory Silhouette.fromJson(Map<String, dynamic> json) =>
      _$SilhouetteFromJson(json);

  AuraStage get stageValue => AuraStage.fromName(stage);
}

@freezed
abstract class RoomMember with _$RoomMember {
  const factory RoomMember({
    required String memberId,

    /// Fresh per room ("Quiet Comet"), from the server; never translated.
    required String pseudonym,
    @Default(Silhouette()) Silhouette silhouette,

    /// Catalogue mood id at join; the app localises it.
    @Default('') String moodChip,
    @Default(false) bool live,

    /// You muted this member (you still see the silhouette).
    @Default(false) bool muted,
    @Default(false) bool isMe,
  }) = _RoomMember;

  factory RoomMember.fromJson(Map<String, dynamic> json) =>
      _$RoomMemberFromJson(json);
}

@freezed
abstract class ReceivedGesture with _$ReceivedGesture {
  const factory ReceivedGesture({
    required String gestureId,
    required String type,
    required String fromMemberId,
    required String fromPseudonym,
    required DateTime at,
  }) = _ReceivedGesture;

  const ReceivedGesture._();

  factory ReceivedGesture.fromJson(Map<String, dynamic> json) =>
      _$ReceivedGestureFromJson(json);

  GestureType? get gesture => GestureType.fromWire(type);
}

@freezed
abstract class SentGesture with _$SentGesture {
  const factory SentGesture({
    required String gestureId,
    required String type,
    @Default('room') String target,
    String? toMemberId,
    required DateTime at,
  }) = _SentGesture;

  const SentGesture._();

  factory SentGesture.fromJson(Map<String, dynamic> json) =>
      _$SentGestureFromJson(json);

  GestureType? get gesture => GestureType.fromWire(type);
}

/// The room's anonymous feed ("others see an unnamed animation").
@freezed
abstract class RoomGesture with _$RoomGesture {
  const factory RoomGesture({
    required String gestureId,
    required String type,
    @Default('room') String target,
    required DateTime at,
  }) = _RoomGesture;

  const RoomGesture._();

  factory RoomGesture.fromJson(Map<String, dynamic> json) =>
      _$RoomGestureFromJson(json);

  GestureType? get gesture => GestureType.fromWire(type);
}

/// You in this room (`RoomSummary.me` has no silhouette or survey flag).
@freezed
abstract class RoomMe with _$RoomMe {
  const factory RoomMe({
    required String memberId,
    required String pseudonym,
    @Default('') String moodChip,
    Silhouette? silhouette,
    required DateTime joinedAt,

    /// Show "Did you feel less alone?" on exit (≥ 30 s here, not asked in
    /// the last 24 h).
    @Default(false) bool surveyEligible,
  }) = _RoomMe;

  factory RoomMe.fromJson(Map<String, dynamic> json) => _$RoomMeFromJson(json);
}

@freezed
abstract class RoomGestures with _$RoomGestures {
  const factory RoomGestures({
    @Default(<ReceivedGesture>[]) List<ReceivedGesture> received,
    @Default(<SentGesture>[]) List<SentGesture> sent,
    @Default(<RoomGesture>[]) List<RoomGesture> recent,
  }) = _RoomGestures;

  factory RoomGestures.fromJson(Map<String, dynamic> json) =>
      _$RoomGesturesFromJson(json);
}

/// `room:<roomId>` and `member:<memberId>` (§3).
@freezed
abstract class RealtimeTopics with _$RealtimeTopics {
  const factory RealtimeTopics({
    required String roomTopic,
    required String memberTopic,
  }) = _RealtimeTopics;

  factory RealtimeTopics.fromJson(Map<String, dynamic> json) =>
      _$RealtimeTopicsFromJson(json);
}

@freezed
abstract class RoomDetail with _$RoomDetail {
  const factory RoomDetail({
    required RoomInfo room,
    required RoomMe me,
    @Default(RoomCounts()) RoomCounts counts,

    /// Current members incl. you, oldest first (blocked people left out).
    @Default(<RoomMember>[]) List<RoomMember> members,
    @Default(RoomGestures()) RoomGestures gestures,
    required RealtimeTopics realtime,
  }) = _RoomDetail;

  factory RoomDetail.fromJson(Map<String, dynamic> json) =>
      _$RoomDetailFromJson(json);
}

/// For analytics only (`room_joined`); never shown.
@freezed
abstract class MatchInfo with _$MatchInfo {
  const factory MatchInfo({
    @Default(0) int step,

    /// Step 0: the same room, pseudonym and memberId as before.
    @Default(false) bool reentry,
    @Default(false) bool created,
    @Default(false) bool merged,
  }) = _MatchInfo;

  factory MatchInfo.fromJson(Map<String, dynamic> json) =>
      _$MatchInfoFromJson(json);
}

/// `POST /v1/rooms/match` → every `RoomDetail` field plus `match`.
@immutable
class MatchResult {
  const MatchResult({required this.detail, required this.match});

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
    detail: RoomDetail.fromJson(json),
    match: json['match'] is Map<String, dynamic>
        ? MatchInfo.fromJson(json['match'] as Map<String, dynamic>)
        : const MatchInfo(),
  );

  final RoomDetail detail;
  final MatchInfo match;
}

/// The "Your rooms" strip (`GET /v1/rooms`).
@freezed
abstract class RoomSummary with _$RoomSummary {
  const factory RoomSummary({
    required RoomInfo room,
    required RoomMe me,
    @Default(RoomCounts()) RoomCounts counts,
  }) = _RoomSummary;

  factory RoomSummary.fromJson(Map<String, dynamic> json) =>
      _$RoomSummaryFromJson(json);
}

/// `POST /v1/rooms/:roomId/heartbeat`: fresh state and counts (doubles as
/// a poll).
@freezed
abstract class HeartbeatResult with _$HeartbeatResult {
  const factory HeartbeatResult({
    required RoomInfo room,
    @Default(RoomCounts()) RoomCounts counts,
  }) = _HeartbeatResult;

  factory HeartbeatResult.fromJson(Map<String, dynamic> json) =>
      _$HeartbeatResultFromJson(json);
}

/// `202` — the same whether delivered or silently dropped (it always
/// "looks sent").
@freezed
abstract class GestureAck with _$GestureAck {
  const factory GestureAck({required String gestureId, required DateTime at}) =
      _GestureAck;

  factory GestureAck.fromJson(Map<String, dynamic> json) =>
      _$GestureAckFromJson(json);
}

@freezed
abstract class ReportAck with _$ReportAck {
  const factory ReportAck({
    required String reportId,

    /// Reason 1 (crisis lane): the reporter sees helplines at once.
    @Default(false) bool showHelplines,
  }) = _ReportAck;

  factory ReportAck.fromJson(Map<String, dynamic> json) =>
      _$ReportAckFromJson(json);
}

/// Community guidelines on the server (REQ-SAFE-04, contracts §2.4): the
/// version rooms require and whether this account accepted it (or a newer
/// one). A plain class: nothing here needs code generation.
@immutable
class GuidelinesStatus {
  const GuidelinesStatus({
    required this.version,
    required this.accepted,
    this.acceptedVersion,
  });

  factory GuidelinesStatus.fromJson(Map<String, dynamic> json) =>
      GuidelinesStatus(
        version: (json['version'] as num?)?.toInt() ?? 1,
        accepted: json['accepted'] == true,
        acceptedVersion: (json['acceptedVersion'] as num?)?.toInt(),
      );

  final int version;
  final bool accepted;
  final int? acceptedVersion;
}

/// `GET /v1/safety/me` (only what the app shows: room access and until).
@freezed
abstract class SafetyStanding with _$SafetyStanding {
  const factory SafetyStanding({
    /// `available` · `suspended` · `closed`.
    @Default('available') String rooms,
    DateTime? until,
  }) = _SafetyStanding;

  factory SafetyStanding.fromJson(Map<String, dynamic> json) =>
      _$SafetyStandingFromJson(json);
}
