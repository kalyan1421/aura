import BackgroundTasks
import Flutter
import Foundation
import WidgetKit

/// The app's side of the home-screen widget store (F11;
/// lib/src/features/widget/widget_store.dart `ChannelWidgetHost`). The store
/// logic and keys are shared with the extension (AuraWidgetCore.swift).
///
/// * `readPending` → the widget's `aura.widget.pending` JSON (or nil)
/// * `writeAcked(json)` → `aura.widget.acked`
/// * `writeBackgroundHandled(json)` → `aura.widget.bgHandled` (background runs)
/// * `publish({display, avatar})` → `aura.widget.display` + the avatar PNG in
///   the App Group container (nil removes it), then every widget redraws.
///
/// Never logs what it moves (mood ids live in these strings).
///
/// MASVS F-1 (docs/security/masvs-l1.md): the App Group container (the
/// widget's UserDefaults plist under Library/Preferences, the avatar PNG) is
/// excluded from iCloud / Finder backup, like the app's own database (G-1).
/// What's in it stays minimal: mood-only pending check-ins until the app
/// imports them, the display state (a last mood only when "Show my last
/// mood" is on), the avatar picture. Nothing is lost on a new phone: widget
/// check-ins the app hasn't imported yet are the only thing not on the
/// server, and the widget is set up again from the app.
enum AuraWidgetChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    excludeContainerFromBackup()
    let channel = FlutterMethodChannel(
      name: "com.akvega.aura/widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let kv = UserDefaultsKeyValue() else {
        // No App Group (entitlement missing): the widget can't be served.
        result(FlutterError(code: "no_app_group", message: nil, details: nil))
        return
      }
      switch call.method {
      case "readPending":
        result(kv.string(forKey: AuraWidgetKeys.pending))
      case "writeAcked":
        kv.setString(call.arguments as? String, forKey: AuraWidgetKeys.acked)
        result(nil)
      case "writeBackgroundHandled":
        kv.setString(call.arguments as? String, forKey: AuraWidgetKeys.bgHandled)
        result(nil)
      case "publish":
        let args = call.arguments as? [String: Any]
        kv.setString(args?["display"] as? String, forKey: AuraWidgetKeys.display)
        writeAvatar((args?["avatar"] as? FlutterStandardTypedData)?.data)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Sets `isExcludedFromBackup` on the App Group container and the
  /// directories under it that exist (a directory covers its contents, and
  /// directories survive the atomic rewrites of the plist and PNG inside).
  /// Idempotent, runs at every launch, never fatal.
  static func excludeContainerFromBackup() {
    guard
      let root = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AuraWidgetKeys.appGroup)
    else { return }
    let library = root.appendingPathComponent("Library", isDirectory: true)
    for dir in [root, library, library.appendingPathComponent("Preferences", isDirectory: true)] {
      guard FileManager.default.fileExists(atPath: dir.path) else { continue }
      var url = dir
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? url.setResourceValues(values)
    }
  }

  private static func writeAvatar(_ data: Data?) {
    guard
      let url = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AuraWidgetKeys.appGroup)?
        .appendingPathComponent(AuraWidgetKeys.avatarFile)
    else { return }
    if let data {
      try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      // An atomic write is a new file: mark it too (belt and braces; the
      // container itself is already excluded).
      var file = url
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? file.setResourceValues(values)
    } else {
      try? FileManager.default.removeItem(at: url)
    }
  }
}

/// Widget background refresh (F11 "Data path": the app imports widget
/// check-ins "on next launch or background refresh, then syncs"; PRD
/// 16-offline: the outbox drains "via … BGTaskScheduler").
///
/// A widget extension can't schedule background tasks, so the app asks for a
/// `BGAppRefreshTask` whenever it goes to the background while an Aura widget
/// is installed, and again after each run; iOS decides when (battery, usage).
/// A run:
///  - does nothing (and starts no Flutter) unless the widget holds check-ins
///    no background run imported yet;
///  - hands the work to the app's engine when it is alive (suspended in the
///    background): `backgroundSync` on `com.akvega.aura/widget`;
///  - otherwise runs a headless engine at `widgetBackgroundMain`
///    (lib/main.dart → lib/src/features/widget/widget_background.dart), which
///    imports and pushes without UI and answers `done` on
///    `com.akvega.aura/widget_background`. Nothing runs signed out, before
///    onboarding or under the under-13 lock (checked in Dart).
/// Never logs what it moves.
enum AuraWidgetBackgroundSync {
  static let taskId = "com.akvega.aura.widget-sync"
  private static let minimumInterval: TimeInterval = 15 * 60

  /// The app's own engine, while it exists.
  static weak var appMessenger: FlutterBinaryMessenger?
  private static var engine: FlutterEngine?

  /// Before `didFinishLaunching` returns (BGTaskScheduler requirement).
  static func register() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: DispatchQueue.main) { task in
      guard let task = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      handle(task)
    }
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
    ) { _ in schedule() }
  }

  /// Asks for the next run, only while an Aura widget is on a screen.
  static func schedule() {
    WidgetCenter.shared.getCurrentConfigurations { result in
      guard case .success(let widgets) = result, !widgets.isEmpty else { return }
      let request = BGAppRefreshTaskRequest(identifier: taskId)
      request.earliestBeginDate = Date(timeIntervalSinceNow: minimumInterval)
      try? BGTaskScheduler.shared.submit(request)
    }
  }

  private static func handle(_ task: BGAppRefreshTask) {
    schedule()
    var completed = false
    func complete(_ success: Bool) {
      guard !completed else { return }
      completed = true
      engine?.destroyContext()
      engine = nil
      task.setTaskCompleted(success: success)
    }
    guard let kv = UserDefaultsKeyValue(), AuraWidgetStore(kv: kv).needsBackgroundImport else {
      complete(true)
      return
    }
    task.expirationHandler = { DispatchQueue.main.async { complete(false) } }

    if let messenger = appMessenger {
      FlutterMethodChannel(name: "com.akvega.aura/widget", binaryMessenger: messenger)
        .invokeMethod("backgroundSync", arguments: nil) { _ in complete(true) }
      return
    }

    let headless = FlutterEngine(name: "aura.widget-sync", project: nil, allowHeadlessExecution: true)
    guard headless.run(withEntrypoint: "widgetBackgroundMain") else {
      complete(false)
      return
    }
    engine = headless
    GeneratedPluginRegistrant.register(with: headless)
    AuraWidgetChannel.register(messenger: headless.binaryMessenger)
    FlutterMethodChannel(name: "com.akvega.aura/widget_background", binaryMessenger: headless.binaryMessenger)
      .setMethodCallHandler { call, result in
        result(nil)
        if call.method == "done" { complete(true) }
      }
  }
}
