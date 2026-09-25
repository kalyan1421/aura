import Foundation
import XCTest

@testable import AuraWidgetCore

final class MemoryKV: AuraWidgetKeyValue {
  var values: [String: String] = [:]
  func string(forKey key: String) -> String? { values[key] }
  func setString(_ value: String?, forKey key: String) { values[key] = value }
}

final class AuraWidgetCoreTests: XCTestCase {
  let ist = TimeZone(identifier: "Asia/Kolkata")!
  /// 15:30 IST on 8 Oct 2026.
  let afternoon = ISO8601DateFormatter().date(from: "2026-10-08T10:00:00Z")!

  func display(ready: Bool = true, discreet: Bool = false, day: String = "2026-10-08",
               checkedIn: Bool = false, triggers: [String] = []) -> String {
    var d = WidgetDisplay()
    d.ready = ready
    d.discreet = discreet
    d.owner = ready ? "owner-1" : nil
    d.auraDay = day
    d.checkedInToday = checkedIn
    d.awardsToday = checkedIn ? [2, 2, 0, 0] : [10, 2, 2, 0]
    d.awardsFresh = [10, 2, 2, 0]
    d.savedAward = ["10": "Saved · +10 Starlight", "2": "Saved · +2 Starlight"]
    d.s = ["saved": "Saved", "capsuleWaiting": "Something from past you is waiting"]
    d.triggerMoods = triggers
    d.quadrants = [
      WidgetQuadrant(id: "moonlight", label: "Moonlight", moods: [
        WidgetMood(id: "calm", label: "Calm"), WidgetMood(id: "content", label: "Content"),
      ]),
      WidgetQuadrant(id: "storm", label: "Storm", moods: [
        WidgetMood(id: "anxious", label: "Anxious"),
      ]),
    ]
    return String(data: try! JSONEncoder().encode(d), encoding: .utf8)!
  }

  func store(_ json: String?) -> (AuraWidgetStore, MemoryKV) {
    let kv = MemoryKV()
    kv.values[AuraWidgetKeys.display] = json
    return (AuraWidgetStore(kv: kv), kv)
  }

  /// contracts/rules/vectors/aura_day.json: the same cases Dart and TS pass.
  func testAuraDayVectors() throws {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("../../../../contracts/rules/vectors/aura_day.json").standardized
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    let cases = json["cases"] as! [[String: Any]]
    XCTAssertFalse(cases.isEmpty)
    let parser = ISO8601DateFormatter()
    for c in cases {
      let instant = parser.date(from: c["utc"] as! String)!
      let tz = TimeZone(identifier: c["tz"] as! String)!
      XCTAssertEqual(AuraDay.of(instant, in: tz), c["expect"] as? String, c["name"] as? String ?? "")
    }
  }

  func testNextRolloverIs0400Local() {
    let next = AuraDay.nextRollover(after: afternoon, in: ist)
    XCTAssertEqual(AuraISO.string(next), "2026-10-08T22:30:00.000Z")  // 04:00 IST on 9 Oct
  }

  func testUUIDv7Shape() {
    let id = UUIDv7.make(at: afternoon)
    XCTAssertNotNil(id.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
                             options: .regularExpression), id)
    XCTAssertLessThan(UUIDv7.make(at: afternoon), UUIDv7.make(at: afternoon.addingTimeInterval(1)))
  }

  func testNotSetUpDisablesInput() {
    let (s, kv) = store(display(ready: false))
    XCTAssertEqual(s.state(now: afternoon, timeZone: ist).phase, .notReady)
    XCTAssertNil(s.save(moodId: "calm", now: afternoon, timeZone: ist))
    XCTAssertNil(kv.values[AuraWidgetKeys.pending])
    let (empty, _) = store(nil)
    XCTAssertEqual(empty.state(now: afternoon, timeZone: ist).phase, .notReady)
  }

  func testDiscreetIsAPlainStarWithoutInput() {
    let (s, _) = store(display(discreet: true))
    XCTAssertEqual(s.state(now: afternoon, timeZone: ist).phase, .discreet)
    XCTAssertNil(s.save(moodId: "calm", now: afternoon, timeZone: ist))
  }

  func testTwoTapsSaveAMoodOnlyRecordWithTheDayStamp() throws {
    let (s, kv) = store(display())
    s.pick(quadrant: "moonlight", now: afternoon)
    guard case .moods(let q) = s.state(now: afternoon, timeZone: ist).phase else {
      return XCTFail("expected the mood step")
    }
    XCTAssertEqual(q.id, "moonlight")

    let r = try XCTUnwrap(s.save(moodId: "calm", now: afternoon, timeZone: ist))
    XCTAssertEqual(r.moodId, "calm")
    XCTAssertEqual(r.owner, "owner-1")
    XCTAssertEqual(r.localDay, "2026-10-08")
    XCTAssertEqual(r.tz, "Asia/Kolkata")
    XCTAssertEqual(r.tzOffsetMinutes, 330)
    XCTAssertEqual(r.deviceTs, "2026-10-08T10:00:00.000Z")
    XCTAssertEqual(r.v, 1)

    let stored = try JSONDecoder().decode(
      [PendingCheckIn].self, from: kv.values[AuraWidgetKeys.pending]!.data(using: .utf8)!)
    XCTAssertEqual(stored, [r])
    // No note, tags or voice: a mood-only record.
    let raw = kv.values[AuraWidgetKeys.pending]!
    XCTAssertFalse(raw.contains("note"))
    XCTAssertFalse(raw.contains("tags"))

    let after = s.state(now: afternoon, timeZone: ist)
    XCTAssertEqual(after.phase, .quadrants)
    XCTAssertTrue(after.checkedInToday)
    XCTAssertEqual(after.savedText, "Saved · +10 Starlight")
    // The confirmation fades after a minute.
    XCTAssertNil(s.state(now: afternoon.addingTimeInterval(61), timeZone: ist).savedText)
  }

  func testA0130TapIsStampedForThePreviousAuraDay() throws {
    let (s, _) = store(display(day: "2026-10-07"))
    let night = ISO8601DateFormatter().date(from: "2026-10-07T20:00:00Z")!  // 01:30 IST, 8 Oct
    let r = try XCTUnwrap(s.save(moodId: "calm", now: night, timeZone: ist))
    XCTAssertEqual(r.localDay, "2026-10-07")
  }

  func testAwardsFollowTheAppsSequenceAndAFreshDay() {
    let (s, _) = store(display())
    XCTAssertEqual(s.nextAward(now: afternoon, timeZone: ist), 10)
    s.save(moodId: "calm", now: afternoon, timeZone: ist)
    XCTAssertEqual(s.nextAward(now: afternoon.addingTimeInterval(5), timeZone: ist), 2)

    // The app published yesterday: a new day starts from the fresh sequence.
    let (stale, _) = store(display(day: "2026-10-07", checkedIn: true))
    XCTAssertEqual(stale.nextAward(now: afternoon, timeZone: ist), 10)
    XCTAssertFalse(stale.state(now: afternoon, timeZone: ist).checkedInToday)
  }

  func testAcknowledgedRecordsAreDroppedAndNotCountedTwice() throws {
    let (s, kv) = store(display())
    let first = try XCTUnwrap(s.save(moodId: "calm", now: afternoon, timeZone: ist))
    // The app imported it and republished today's state.
    kv.values[AuraWidgetKeys.acked] = "[\"\(first.id)\"]"
    kv.values[AuraWidgetKeys.display] = display(checkedIn: true)
    XCTAssertTrue(s.unsent.isEmpty)
    XCTAssertEqual(s.nextAward(now: afternoon.addingTimeInterval(10), timeZone: ist), 2)

    let second = try XCTUnwrap(s.save(moodId: "content", now: afternoon.addingTimeInterval(10), timeZone: ist))
    let stored = try JSONDecoder().decode(
      [PendingCheckIn].self, from: kv.values[AuraWidgetKeys.pending]!.data(using: .utf8)!)
    XCTAssertEqual(stored.map(\.id), [second.id])
  }

  func testBackgroundImportIsNeededOnlyForUnsentNotYetHandled() throws {
    let (s, kv) = store(display())
    XCTAssertFalse(s.needsBackgroundImport)
    let saved = try XCTUnwrap(s.save(moodId: "calm", now: afternoon, timeZone: ist))
    XCTAssertTrue(s.needsBackgroundImport)
    // A background run imported it without acknowledging: the widget still
    // shows it, background refresh skips it.
    kv.values[AuraWidgetKeys.bgHandled] = "[\"\(saved.id)\"]"
    XCTAssertFalse(s.needsBackgroundImport)
    XCTAssertTrue(s.state(now: afternoon, timeZone: ist).checkedInToday)
    XCTAssertNotNil(s.save(moodId: "anxious", now: afternoon.addingTimeInterval(10), timeZone: ist))
    XCTAssertTrue(s.needsBackgroundImport)
  }

  func testADoubleTapSavesOnce() {
    let (s, kv) = store(display())
    XCTAssertNotNil(s.save(moodId: "calm", now: afternoon, timeZone: ist))
    XCTAssertNil(s.save(moodId: "calm", now: afternoon.addingTimeInterval(0.5), timeZone: ist))
    XCTAssertEqual(s.unsent.count, 1)
    XCTAssertNotNil(kv.values[AuraWidgetKeys.pending])
  }

  func testUnknownMoodIsRefused() {
    let (s, _) = store(display())
    XCTAssertNil(s.save(moodId: "ecstatic", now: afternoon, timeZone: ist))
  }

  func testAPickExpires() {
    let (s, _) = store(display())
    s.pick(quadrant: "storm", now: afternoon)
    XCTAssertEqual(s.state(now: afternoon.addingTimeInterval(61), timeZone: ist).phase, .quadrants)
    s.pick(quadrant: "storm", now: afternoon)
    s.back()
    XCTAssertEqual(s.state(now: afternoon, timeZone: ist).phase, .quadrants)
  }

  func testACapsuleMatchShowsTheWaitingLine() {
    let (s, _) = store(display(triggers: ["anxious"]))
    XCTAssertNil(s.state(now: afternoon, timeZone: ist).capsuleText)
    s.save(moodId: "anxious", now: afternoon, timeZone: ist)
    XCTAssertEqual(s.state(now: afternoon, timeZone: ist).capsuleText,
                   "Something from past you is waiting")
  }

  func testPendingIsCapped() {
    let (s, _) = store(display())
    for i in 0..<(AuraWidgetKeys.maxPending + 5) {
      s.save(moodId: i % 2 == 0 ? "calm" : "content",
             now: afternoon.addingTimeInterval(Double(i) * 3), timeZone: ist)
    }
    XCTAssertEqual(s.unsent.count, AuraWidgetKeys.maxPending)
  }

  func testTheDisplayJsonFromTheAppDecodes() throws {
    // Shape produced by lib/src/features/widget/widget_display.dart.
    let json = """
      {"v":1,"ready":true,"discreet":false,"tz":"Asia/Kolkata","owner":"o","auraDay":"2026-10-08",
       "checkedInToday":false,"awardsToday":[10,2,2,0],"awardsFresh":[10,2,2,0],
       "savedAward":{"10":"Saved · +10 Starlight"},"avatar":true,
       "s":{"prompt":"How are you feeling?"},"capsuleWaiting":false,"triggerMoods":[],
       "lastMood":{"id":"calm","quadrant":"moonlight","text":"Last: Calm"},
       "quadrants":[{"id":"storm","label":"Storm","moods":[{"id":"anxious","label":"Anxious"}]}],
       "somethingNew":1}
      """
    let d = try XCTUnwrap(WidgetDisplay.decode(json))
    XCTAssertEqual(d.lastMood?.text, "Last: Calm")
    XCTAssertEqual(d.mood("anxious")?.0.id, "storm")
    XCTAssertEqual(d.s["prompt"], "How are you feeling?")
    // Not set up: only the essentials.
    let off = try XCTUnwrap(WidgetDisplay.decode(
      #"{"v":1,"ready":false,"discreet":true,"tz":"UTC","s":{"openApp":"Open the app to continue"}}"#))
    XCTAssertFalse(off.ready)
    XCTAssertNil(off.quadrants)
  }
}
