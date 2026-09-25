import Flutter
import Foundation
import WidgetKit

/// The app's side of the home-screen widget store (F11;
/// lib/src/features/widget/widget_store.dart `ChannelWidgetHost`). The store
/// logic and keys are shared with the extension (AuraWidgetCore.swift).
///
/// * `readPending` → the widget's `aura.widget.pending` JSON (or nil)
/// * `writeAcked(json)` → `aura.widget.acked`
/// * `publish({display, avatar})` → `aura.widget.display` + the avatar PNG in
///   the App Group container (nil removes it), then every widget redraws.
///
/// Never logs what it moves (mood ids live in these strings).
enum AuraWidgetChannel {
  static func register(messenger: FlutterBinaryMessenger) {
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

  private static func writeAvatar(_ data: Data?) {
    guard
      let url = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AuraWidgetKeys.appGroup)?
        .appendingPathComponent(AuraWidgetKeys.avatarFile)
    else { return }
    if let data {
      try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    } else {
      try? FileManager.default.removeItem(at: url)
    }
  }
}
