// Aura home-screen widget (F11): the logic the widget extension and the app
// share, Foundation only, so it is unit-tested with `swift test` in
// ios/AuraWidgetCore and compiled as-is into the AuraWidget extension and
// the Runner app (ios/Runner.xcodeproj).
//
// The store (App Group `group.com.akvega.aura` user defaults) holds three
// JSON strings, each with one writer (lib/src/features/widget/widget_store.dart):
//   aura.widget.display  written by the app: what to show (all copy
//                        pre-rendered in the app's language)
//   aura.widget.pending  written by the widget: mood-only check-ins
//   aura.widget.acked    written by the app: ids it has handled
// plus aura.widget.ui (widget-only: the picked group, the last save).
// The widget never talks to the network or to Supabase.

import Foundation

enum AuraWidgetKeys {
  static let appGroup = "group.com.akvega.aura"
  static let display = "aura.widget.display"
  static let pending = "aura.widget.pending"
  static let acked = "aura.widget.acked"
  static let ui = "aura.widget.ui"
  /// The avatar PNG the app writes into the App Group container.
  static let avatarFile = "aura-widget-avatar.png"
  static let storeVersion = 1
  /// At most this many unsent check-ins are kept (oldest dropped first).
  static let maxPending = 200
  /// How long "Saved · +10 Starlight" and a picked group stay on screen.
  static let savedSeconds: TimeInterval = 60
  static let pickSeconds: TimeInterval = 60
}

/// Key/value storage (UserDefaults in the app and the extension, a
/// dictionary in tests).
protocol AuraWidgetKeyValue: AnyObject {
  func string(forKey key: String) -> String?
  func setString(_ value: String?, forKey key: String)
}

final class UserDefaultsKeyValue: AuraWidgetKeyValue {
  private let defaults: UserDefaults
  init?(suiteName: String = AuraWidgetKeys.appGroup) {
    guard let d = UserDefaults(suiteName: suiteName) else { return nil }
    defaults = d
  }
  func string(forKey key: String) -> String? { defaults.string(forKey: key) }
  func setString(_ value: String?, forKey key: String) {
    if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
  }
}

// MARK: - What the app publishes

struct WidgetMood: Codable, Equatable {
  let id: String
  let label: String
}

struct WidgetQuadrant: Codable, Equatable {
  let id: String
  let label: String
  let moods: [WidgetMood]
}

struct WidgetLastMood: Codable, Equatable {
  let id: String
  let quadrant: String
  let text: String
}

struct WidgetDisplay: Codable, Equatable {
  var v: Int = AuraWidgetKeys.storeVersion
  var ready: Bool = false
  var discreet: Bool = false
  var tz: String?
  var owner: String?
  var auraDay: String?
  var checkedInToday: Bool?
  var awardsToday: [Int]?
  var awardsFresh: [Int]?
  var savedAward: [String: String]?
  var avatar: Bool?
  var s: [String: String] = [:]
  var streak: String?
  var capsuleWaiting: Bool?
  var triggerMoods: [String]?
  var lastMood: WidgetLastMood?
  var quadrants: [WidgetQuadrant]?

  static func decode(_ json: String?) -> WidgetDisplay? {
    guard let data = json?.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(WidgetDisplay.self, from: data)
  }

  func quadrant(_ id: String?) -> WidgetQuadrant? {
    guard let id else { return nil }
    return quadrants?.first { $0.id == id }
  }

  func mood(_ id: String) -> (WidgetQuadrant, WidgetMood)? {
    for q in quadrants ?? [] {
      if let m = q.moods.first(where: { $0.id == id }) { return (q, m) }
    }
    return nil
  }
}

// MARK: - What the widget writes

/// A mood-only check-in: client UUIDv7 + day stamp (F11 "Data path").
struct PendingCheckIn: Codable, Equatable {
  var v: Int = AuraWidgetKeys.storeVersion
  let id: String
  let moodId: String
  /// ISO 8601 UTC with milliseconds.
  let deviceTs: String
  let tzOffsetMinutes: Int
  let tz: String
  /// Aura day (04:00 rollover) in `tz`, `YYYY-MM-DD`.
  let localDay: String
  let owner: String
}

struct WidgetSaved: Codable, Equatable {
  let id: String
  let moodId: String
  let award: Int
  let at: Date
}

struct WidgetUIState: Codable, Equatable {
  var quadrant: String?
  var pickedAt: Date?
  var saved: WidgetSaved?
}

// MARK: - Aura day and ids

enum AuraDay {
  /// The Aura day of `instant` in `timeZone`: the local date, minus a day
  /// before 04:00 (contracts/rules RULES.md §1, the same rule as Dart/TS).
  static func of(_ instant: Date, in timeZone: TimeZone) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    var c = cal.dateComponents([.year, .month, .day, .hour], from: instant)
    if (c.hour ?? 0) < 4 {
      let noon = cal.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: 12))!
      let prev = cal.date(byAdding: .day, value: -1, to: noon)!
      c = cal.dateComponents([.year, .month, .day], from: prev)
    }
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }

  /// The next 04:00 local after `instant` (the widget redraws then).
  static func nextRollover(after instant: Date, in timeZone: TimeZone) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    let today4 = cal.date(bySettingHour: 4, minute: 0, second: 0, of: instant)!
    return today4 > instant ? today4 : cal.date(byAdding: .day, value: 1, to: today4)!
  }
}

enum UUIDv7 {
  /// RFC 9562 UUIDv7: 48-bit Unix ms, version 7, variant 10, random rest.
  static func make(at date: Date, random: () -> UInt8 = { UInt8.random(in: 0...255) }) -> String {
    let ms = UInt64(max(0, date.timeIntervalSince1970 * 1000))
    var b = [UInt8](repeating: 0, count: 16)
    for i in 0..<6 { b[i] = UInt8((ms >> (8 * (5 - UInt64(i)))) & 0xff) }
    for i in 6..<16 { b[i] = random() }
    b[6] = (b[6] & 0x0f) | 0x70
    b[8] = (b[8] & 0x3f) | 0x80
    let hex = b.map { String(format: "%02x", $0) }.joined()
    let parts = [hex.prefix(8), hex.dropFirst(8).prefix(4), hex.dropFirst(12).prefix(4),
                 hex.dropFirst(16).prefix(4), hex.dropFirst(20)]
    return parts.map(String.init).joined(separator: "-")
  }
}

enum AuraISO {
  static func string(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    f.timeZone = TimeZone(identifier: "UTC")
    return f.string(from: date)
  }
}

// MARK: - The widget's state

/// What a widget render needs, computed from the store at `now`.
struct WidgetState: Equatable {
  enum Phase: Equatable {
    /// Signed out / not set up: "Open Aura to continue", input off.
    case notReady
    /// Discreet: a plain star that opens the app.
    case discreet
    /// The four groups.
    case quadrants
    /// The four moods of one group.
    case moods(WidgetQuadrant)
  }

  let display: WidgetDisplay?
  let phase: Phase
  let checkedInToday: Bool
  /// "Saved · +10 Starlight" (or "Saved") right after a widget save.
  let savedText: String?
  /// "Something from past you is waiting".
  let capsuleText: String?
  let today: String

  func text(_ key: String, fallback: String) -> String { display?.s[key] ?? fallback }
}

/// The widget's logic over a key/value store. Thin: every rule that matters
/// (Starlight, what may be shown) was decided by the app.
final class AuraWidgetStore {
  let kv: AuraWidgetKeyValue
  init(kv: AuraWidgetKeyValue) { self.kv = kv }

  var display: WidgetDisplay? { WidgetDisplay.decode(kv.string(forKey: AuraWidgetKeys.display)) }

  var ui: WidgetUIState {
    guard let data = kv.string(forKey: AuraWidgetKeys.ui)?.data(using: .utf8),
      let s = try? Self.decoder.decode(WidgetUIState.self, from: data)
    else { return WidgetUIState() }
    return s
  }

  var acked: Set<String> {
    guard let data = kv.string(forKey: AuraWidgetKeys.acked)?.data(using: .utf8),
      let ids = try? JSONDecoder().decode([String].self, from: data)
    else { return [] }
    return Set(ids)
  }

  /// Check-ins saved here that the app hasn't handled yet.
  var unsent: [PendingCheckIn] {
    let done = acked
    return pendingRaw.filter { !done.contains($0.id) }
  }

  private var pendingRaw: [PendingCheckIn] {
    guard let data = kv.string(forKey: AuraWidgetKeys.pending)?.data(using: .utf8),
      let list = try? JSONDecoder().decode([PendingCheckIn].self, from: data)
    else { return [] }
    return list
  }

  // MARK: reading

  func state(now: Date, timeZone: TimeZone) -> WidgetState {
    let d = display
    let today = AuraDay.of(now, in: timeZone)
    let unsentToday = unsent.filter { $0.localDay == today }
    let published = d?.auraDay == today && (d?.checkedInToday ?? false)
    let done = published || !unsentToday.isEmpty

    guard let d, d.ready else {
      return WidgetState(display: d, phase: .notReady, checkedInToday: false,
                         savedText: nil, capsuleText: nil, today: today)
    }
    if d.discreet {
      return WidgetState(display: d, phase: .discreet, checkedInToday: done,
                         savedText: nil, capsuleText: nil, today: today)
    }
    let ui = self.ui
    var saved: String?
    if let s = ui.saved, now.timeIntervalSince(s.at) < AuraWidgetKeys.savedSeconds, now >= s.at {
      saved = s.award > 0 ? (d.savedAward?["\(s.award)"] ?? d.s["saved"]) : d.s["saved"]
    }
    let triggers = Set(d.triggerMoods ?? [])
    let matched = unsent.contains { triggers.contains($0.moodId) }
    let capsule = (d.capsuleWaiting ?? false) || matched ? d.s["capsuleWaiting"] : nil
    var phase = WidgetState.Phase.quadrants
    if saved == nil, let picked = d.quadrant(ui.quadrant), let at = ui.pickedAt,
      now.timeIntervalSince(at) < AuraWidgetKeys.pickSeconds, now >= at
    {
      phase = .moods(picked)
    }
    return WidgetState(display: d, phase: phase, checkedInToday: done,
                       savedText: saved, capsuleText: capsule, today: today)
  }

  /// Provisional Starlight for one more check-in now: the app's sequence
  /// for today (or for a new day it hasn't seen), indexed by the check-ins
  /// saved here today that it hasn't counted yet.
  func nextAward(now: Date, timeZone: TimeZone) -> Int {
    guard let d = display else { return 0 }
    let today = AuraDay.of(now, in: timeZone)
    let seq = (d.auraDay == today ? d.awardsToday : d.awardsFresh) ?? []
    let index = unsent.filter { $0.localDay == today }.count
    guard !seq.isEmpty else { return 0 }
    return index < seq.count ? seq[index] : (seq.last ?? 0)
  }

  /// When the widget should redraw next (a save or a pick fades, 04:00).
  func nextRefresh(now: Date, timeZone: TimeZone) -> [Date] {
    var dates: [Date] = []
    let ui = self.ui
    if let s = ui.saved?.at, s.addingTimeInterval(AuraWidgetKeys.savedSeconds) > now {
      dates.append(s.addingTimeInterval(AuraWidgetKeys.savedSeconds))
    }
    if let p = ui.pickedAt, p.addingTimeInterval(AuraWidgetKeys.pickSeconds) > now {
      dates.append(p.addingTimeInterval(AuraWidgetKeys.pickSeconds))
    }
    dates.append(AuraDay.nextRollover(after: now, in: timeZone))
    return dates.sorted()
  }

  // MARK: writing (widget side)

  /// Tap 1: a group.
  func pick(quadrant: String, now: Date) {
    guard let d = display, d.ready, !d.discreet, d.quadrant(quadrant) != nil else { return }
    var s = ui
    s.quadrant = quadrant
    s.pickedAt = now
    s.saved = nil
    writeUI(s)
  }

  /// "Back": from the moods to the groups.
  func back() {
    var s = ui
    s.quadrant = nil
    s.pickedAt = nil
    writeUI(s)
  }

  /// Tap 2: a mood → a mood-only check-in in `pending`. Returns it, or nil
  /// when input is off (not set up, discreet, unknown mood) or it is the
  /// same mood again within 2 s (a double tap saves once, like F1).
  @discardableResult
  func save(moodId: String, now: Date, timeZone: TimeZone,
            random: () -> UInt8 = { UInt8.random(in: 0...255) }) -> PendingCheckIn? {
    guard let d = display, d.ready, !d.discreet, let owner = d.owner, !owner.isEmpty,
      d.mood(moodId) != nil
    else { return nil }
    var s = ui
    if let last = s.saved, last.moodId == moodId, abs(now.timeIntervalSince(last.at)) < 2 {
      return nil
    }
    let award = nextAward(now: now, timeZone: timeZone)
    let record = PendingCheckIn(
      id: UUIDv7.make(at: now, random: random),
      moodId: moodId,
      deviceTs: AuraISO.string(now),
      tzOffsetMinutes: timeZone.secondsFromGMT(for: now) / 60,
      tz: timeZone.identifier,
      localDay: AuraDay.of(now, in: timeZone),
      owner: owner)
    // The widget is the only writer of `pending`: drop what the app handled.
    var list = unsent + [record]
    if list.count > AuraWidgetKeys.maxPending {
      list.removeFirst(list.count - AuraWidgetKeys.maxPending)
    }
    if let data = try? JSONEncoder().encode(list) {
      kv.setString(String(data: data, encoding: .utf8), forKey: AuraWidgetKeys.pending)
    }
    s.quadrant = nil
    s.pickedAt = nil
    s.saved = WidgetSaved(id: record.id, moodId: moodId, award: award, at: now)
    writeUI(s)
    return record
  }

  private func writeUI(_ s: WidgetUIState) {
    if let data = try? Self.encoder.encode(s) {
      kv.setString(String(data: data, encoding: .utf8), forKey: AuraWidgetKeys.ui)
    }
  }

  private static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .secondsSince1970
    return e
  }()
  private static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .secondsSince1970
    return d
  }()
}
