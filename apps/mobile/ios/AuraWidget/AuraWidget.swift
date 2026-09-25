// Aura home-screen and lock-screen widgets (F11, WidgetKit + App Intents).
//
// * Home screen, medium, iOS 17+: interactive. Tap a group, then one of its
//   4 moods → "Saved · +10 Starlight". The app never comes to the front
//   (REQ-WID-01). The larger size adds "Need help" (aura://safety).
// * Home screen, small (and medium on iOS 16): the avatar and "How are
//   you feeling?"; a tap opens the check-in (aura://checkin, REQ-WID-04).
//   The extension needs iOS 16 (PRD 09: "iOS 16 gets a tap-to-open
//   widget"); the app itself still runs on iOS 15, without widgets.
// * Lock screen: only a star that opens the check-in (REQ-WID-03).
// * StandBy and other no-background / tinted renders: a plain star, never a
//   mood, colour or history.
// * Discreet widget (Settings): a plain star, no "Aura", no mood words.
//
// The widget writes a mood-only check-in to the App Group store and never
// talks to the network; the app imports it on its next launch or resume
// (lib/src/features/widget). All copy comes from the app, in its language;
// Localizable.xcstrings (generated) covers the time before the app ran.

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Bundle

@main
struct AuraWidgetBundle: WidgetBundle {
  var body: some Widget {
    AuraCheckInWidget()
    AuraLockWidget()
  }
}

// MARK: - Shared store access

enum WidgetEnv {
  static var store: AuraWidgetStore? {
    UserDefaultsKeyValue().map { AuraWidgetStore(kv: $0) }
  }

  static var avatarURL: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: AuraWidgetKeys.appGroup)?
      .appendingPathComponent(AuraWidgetKeys.avatarFile)
  }

  static func avatar() -> UIImage? {
    guard let url = avatarURL, let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
  }

  static let checkInURL = URL(string: "aura://checkin")!
  static let safetyURL = URL(string: "aura://safety")!
}

// MARK: - Timeline

struct AuraEntry: TimelineEntry {
  let date: Date
  let state: WidgetState
  let avatar: UIImage?
}

struct AuraProvider: TimelineProvider {
  static let empty = WidgetState(
    display: nil, phase: .notReady, checkedInToday: false,
    savedText: nil, capsuleText: nil, today: "")

  func placeholder(in context: Context) -> AuraEntry {
    AuraEntry(date: Date(), state: Self.empty, avatar: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (AuraEntry) -> Void) {
    completion(entry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<AuraEntry>) -> Void) {
    let now = Date()
    let tz = TimeZone.current
    let refresh = WidgetEnv.store?.nextRefresh(now: now, timeZone: tz)
      ?? [AuraDay.nextRollover(after: now, in: tz)]
    // Redraw when a save or a pick fades and at 04:00 (the new Aura day);
    // the app reloads us after each check-in and on avatar changes.
    let entries = [entry(at: now)] + refresh.map { entry(at: $0) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func entry(at date: Date) -> AuraEntry {
    let state = WidgetEnv.store?.state(now: date, timeZone: .current) ?? Self.empty
    let showAvatar = state.display?.avatar == true && state.phase != .discreet
    return AuraEntry(date: date, state: state, avatar: showAvatar ? WidgetEnv.avatar() : nil)
  }
}

// MARK: - Widgets

struct AuraCheckInWidget: Widget {
  let kind = "AuraCheckIn"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: AuraProvider()) { entry in
      AuraWidgetView(entry: entry)
    }
    .configurationDisplayName(Text("widget_galleryName"))
    .description(Text("widget_galleryDescription"))
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabledIfAvailable()
  }
}

struct AuraLockWidget: Widget {
  let kind = "AuraLockStar"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: AuraProvider()) { _ in
      LockStarView()
    }
    .configurationDisplayName(Text("widget_lockGalleryName"))
    .description(Text("widget_lockGalleryDescription"))
    .supportedFamilies([.accessoryCircular])
  }
}

extension WidgetConfiguration {
  func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 17.0, *) {
      return self.contentMarginsDisabled()
    }
    return self
  }
}

// MARK: - Palette (docs/design-system.md tokens)

enum AuraPalette {
  static let sky = Color(red: 0x0A / 255, green: 0x0C / 255, blue: 0x1D / 255)
  static let surface = Color(red: 0x15 / 255, green: 0x19 / 255, blue: 0x35 / 255)
  static let text = Color(red: 0xF2 / 255, green: 0xF0 / 255, blue: 0xFF / 255)
  static let textSoft = Color(red: 0xBD / 255, green: 0xB9 / 255, blue: 0xE0 / 255)
  static let starlight = Color(red: 0xF7 / 255, green: 0xE6 / 255, blue: 0xB5 / 255)

  static func accent(_ quadrant: String) -> Color {
    switch quadrant {
    case "sunrise": return Color(red: 0xF3 / 255, green: 0xBE / 255, blue: 0x67 / 255)
    case "rain": return Color(red: 0x5A / 255, green: 0xCB / 255, blue: 0xBE / 255)
    case "moonlight": return Color(red: 0xAF / 255, green: 0xC3 / 255, blue: 0xF0 / 255)
    default: return Color(red: 0xAE / 255, green: 0x93 / 255, blue: 0xFA / 255)  // storm
    }
  }

  static func deep(_ quadrant: String) -> Color {
    switch quadrant {
    case "sunrise": return Color(red: 0x2E / 255, green: 0x22 / 255, blue: 0x13 / 255)
    case "rain": return Color(red: 0x0E / 255, green: 0x2A / 255, blue: 0x2B / 255)
    case "moonlight": return Color(red: 0x16 / 255, green: 0x1F / 255, blue: 0x3A / 255)
    default: return Color(red: 0x22 / 255, green: 0x1A / 255, blue: 0x43 / 255)
    }
  }

  /// Lighthouse, raindrop, moon, sun: a group is never told by colour alone.
  static func glyph(_ quadrant: String) -> String {
    switch quadrant {
    case "sunrise": return "sun.max"
    case "rain": return "drop"
    case "moonlight": return "moon"
    default: return "light.beacon.max"
    }
  }

  /// App grid order: more energy on top, unpleasant on the left.
  static let gridOrder = ["storm", "sunrise", "rain", "moonlight"]
}

// MARK: - Views

struct AuraWidgetView: View {
  let entry: AuraEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    content
      .widgetURL(WidgetEnv.checkInURL)
      .auraBackground()
  }

  @ViewBuilder private var content: some View {
    if family == .systemMedium {
      MediumView(entry: entry)
    } else {
      SmallView(entry: entry)
    }
  }
}

/// Passes true where the widget must stay neutral: StandBy / no container
/// background, or a tinted (accented / vibrant) render. There it shows a
/// plain star and no mood, colour or history (REQ-WID-03).
struct NeutralReader<Content: View>: View {
  let content: (Bool) -> Content

  init(@ViewBuilder content: @escaping (Bool) -> Content) {
    self.content = content
  }

  var body: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      Neutral17(content: content)
    } else {
      Neutral16(content: content)
    }
  }
}

@available(iOSApplicationExtension 17.0, *)
private struct Neutral17<Content: View>: View {
  let content: (Bool) -> Content
  @Environment(\.showsWidgetContainerBackground) private var background
  @Environment(\.widgetRenderingMode) private var mode
  var body: some View { content(!background || mode != .fullColor) }
}

private struct Neutral16<Content: View>: View {
  let content: (Bool) -> Content
  @Environment(\.widgetRenderingMode) private var mode
  var body: some View { content(mode != .fullColor) }
}

struct StarMark: View {
  var size: CGFloat = 34
  var body: some View {
    Image(systemName: "sparkle")
      .font(.system(size: size, weight: .regular))
      .foregroundColor(AuraPalette.starlight)
      .accessibilityHidden(true)
  }
}

struct AvatarMark: View {
  let entry: AuraEntry
  let neutral: Bool
  var size: CGFloat

  var body: some View {
    if !neutral, let image = entry.avatar {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    } else {
      StarMark(size: size * 0.5).frame(width: size, height: size)
    }
  }
}

struct SmallView: View {
  let entry: AuraEntry

  var body: some View {
    let s = entry.state
    NeutralReader { neutral in
      VStack(spacing: 6) {
        AvatarMark(entry: entry, neutral: neutral || s.phase == .discreet, size: 72)
        Text(line(s))
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(AuraPalette.text)
          .multilineTextAlignment(.center)
          .lineLimit(3)
          .minimumScaleFactor(0.7)
        if !neutral, s.phase != .discreet, let streak = s.display?.streak, s.phase != .notReady {
          Text(streak)
            .font(.system(size: 11))
            .foregroundColor(AuraPalette.textSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func line(_ s: WidgetState) -> String {
    switch s.phase {
    case .notReady:
      return s.text("openApp", fallback: String(localized: "widget_openApp"))
    case .discreet:
      return s.checkedInToday
        ? s.text("doneToday", fallback: String(localized: "widget_doneToday"))
        : s.text("checkIn", fallback: String(localized: "widget_checkIn"))
    default:
      if let saved = s.savedText { return saved }
      return s.checkedInToday
        ? s.text("doneToday", fallback: String(localized: "widget_doneToday"))
        : s.text("prompt", fallback: String(localized: "widget_prompt"))
    }
  }
}

struct MediumView: View {
  let entry: AuraEntry

  var body: some View {
    let s = entry.state
    NeutralReader { neutral in
      if s.phase == .notReady || s.phase == .discreet || neutral {
        SmallView(entry: entry)
      } else {
        HStack(alignment: .center, spacing: 10) {
          Summary(entry: entry)
            .frame(maxWidth: .infinity, alignment: .leading)
          if #available(iOSApplicationExtension 17.0, *) {
            Picker17(state: s)
              .frame(width: 176)
          }
        }
        .padding(12)
      }
    }
  }
}

/// The left column: avatar, the line, and "Need help".
struct Summary: View {
  let entry: AuraEntry

  var body: some View {
    let s = entry.state
    VStack(alignment: .leading, spacing: 4) {
      AvatarMark(entry: entry, neutral: false, size: 52)
      Text(s.savedText ?? (s.checkedInToday
        ? s.text("doneToday", fallback: String(localized: "widget_doneToday"))
        : s.text("prompt", fallback: String(localized: "widget_prompt"))))
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(AuraPalette.text)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
      if let capsule = s.capsuleText {
        Text(capsule)
          .font(.system(size: 11))
          .foregroundColor(AuraPalette.starlight)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
      } else if let last = s.display?.lastMood {
        // Opt-in only ("Show my last mood"); redacted wherever iOS hides
        // private data (locked, StandBy).
        Text(last.text)
          .font(.system(size: 11))
          .foregroundColor(AuraPalette.textSoft)
          .lineLimit(1)
          .privacySensitive()
      } else if let streak = s.display?.streak {
        Text(streak)
          .font(.system(size: 11))
          .foregroundColor(AuraPalette.textSoft)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      Spacer(minLength: 0)
      Link(destination: WidgetEnv.safetyURL) {
        Label(s.text("needHelp", fallback: String(localized: "widget_needHelp")),
              systemImage: "heart")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(AuraPalette.starlight)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(minHeight: 28)
      }
    }
  }
}

/// Tap 1: a group (glyph + name). Tap 2: one of its 4 moods. iOS 17+.
@available(iOSApplicationExtension 17.0, *)
struct Picker17: View {
  let state: WidgetState

  var body: some View {
    switch state.phase {
    case .moods(let q):
      VStack(spacing: 6) {
        grid(q.moods.map { m in
          AnyView(
            Button(intent: SaveMoodIntent(moodId: m.id)) {
              Tile(title: m.label, glyph: nil, quadrant: q.id)
            }
            .buttonStyle(.plain))
        })
        Button(intent: BackIntent()) {
          Label(state.text("back", fallback: String(localized: "widget_back")),
                systemImage: "chevron.backward")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(AuraPalette.textSoft)
            .frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(.plain)
      }
    default:
      let quadrants = AuraPalette.gridOrder.compactMap { state.display?.quadrant($0) }
      grid(quadrants.map { q in
        AnyView(
          Button(intent: PickQuadrantIntent(quadrant: q.id)) {
            Tile(title: q.label, glyph: AuraPalette.glyph(q.id), quadrant: q.id)
          }
          .buttonStyle(.plain))
      })
    }
  }

  private func grid(_ tiles: [AnyView]) -> some View {
    VStack(spacing: 6) {
      ForEach(0..<2, id: \.self) { row in
        HStack(spacing: 6) {
          ForEach(0..<2, id: \.self) { col in
            let i = row * 2 + col
            if i < tiles.count { tiles[i] } else { Color.clear }
          }
        }
      }
    }
  }
}

/// One tile: equal size and weight for every group (docs/design-system.md).
struct Tile: View {
  let title: String
  let glyph: String?
  let quadrant: String

  var body: some View {
    HStack(spacing: 4) {
      if let glyph {
        Image(systemName: glyph)
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(AuraPalette.accent(quadrant))
          .accessibilityHidden(true)
      }
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(AuraPalette.text)
        .lineLimit(2)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(AuraPalette.deep(quadrant))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AuraPalette.accent(quadrant).opacity(0.55), lineWidth: 1)))
    .accessibilityElement(children: .combine)
  }
}

/// Lock screen: only a star that opens the check-in (F11 privacy).
struct LockStarView: View {
  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Image(systemName: "sparkle")
        .font(.system(size: 22, weight: .regular))
    }
    .widgetURL(WidgetEnv.checkInURL)
    .accessibilityLabel(Text("widget_checkIn"))
    .auraBackground(clear: true)
  }
}

extension View {
  @ViewBuilder
  func auraBackground(clear: Bool = false) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      if clear {
        self.containerBackground(for: .widget) { Color.clear }
      } else {
        self.containerBackground(for: .widget) {
          LinearGradient(colors: [AuraPalette.surface, AuraPalette.sky],
                         startPoint: .top, endPoint: .bottom)
        }
      }
    } else if clear {
      self
    } else {
      self.background(
        LinearGradient(colors: [AuraPalette.surface, AuraPalette.sky],
                       startPoint: .top, endPoint: .bottom))
    }
  }
}

// MARK: - App Intents (iOS 17 interactive widget; run in this extension)

@available(iOSApplicationExtension 17.0, *)
struct PickQuadrantIntent: AppIntent {
  static var title: LocalizedStringResource = "widget_checkIn"
  static var isDiscoverable: Bool = false

  @Parameter(title: "widget_checkIn")
  var quadrant: String

  init() {}
  init(quadrant: String) { self.quadrant = quadrant }

  func perform() async throws -> some IntentResult {
    WidgetEnv.store?.pick(quadrant: quadrant, now: Date())
    return .result()
  }
}

@available(iOSApplicationExtension 17.0, *)
struct SaveMoodIntent: AppIntent {
  static var title: LocalizedStringResource = "widget_checkIn"
  static var isDiscoverable: Bool = false

  @Parameter(title: "widget_checkIn")
  var moodId: String

  init() {}
  init(moodId: String) { self.moodId = moodId }

  func perform() async throws -> some IntentResult {
    // Local only: the app imports it and syncs (never the network here).
    WidgetEnv.store?.save(moodId: moodId, now: Date(), timeZone: .current)
    return .result()
  }
}

@available(iOSApplicationExtension 17.0, *)
struct BackIntent: AppIntent {
  static var title: LocalizedStringResource = "widget_back"
  static var isDiscoverable: Bool = false

  init() {}

  func perform() async throws -> some IntentResult {
    WidgetEnv.store?.back()
    return .result()
  }
}
