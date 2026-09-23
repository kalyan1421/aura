import Flutter
import UIKit
import UserNotifications

#if canImport(DeclaredAgeRange)
  import DeclaredAgeRange
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications (F4 capsule "ready to open" notices): the
    // app delegate forwards notification callbacks to plugins. Asks for no
    // permission; that stays with the push soft ask.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    AuraPlatformChannel.register(messenger: engineBridge.applicationRegistrar.messenger())
    AuraAgeSignalsChannel.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Platform age signals (F8 REQ-ACC-04; lib/src/features/auth/age_signals.dart).
/// `read` answers `{status: shared|declined|unavailable, lower?, upper?}` and
/// never fails. Apple's Declared Age Range is asked only where
/// `isEligibleForAgeFeatures` (iOS 26.2+: regions whose law requires age
/// assurance), so nobody elsewhere is shown Apple's share sheet. Needs the
/// `com.apple.developer.declared-age-range` entitlement (Runner.entitlements).
/// The value is only ever used on device: never logged or sent.
private enum AuraAgeSignalsChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.akvega.aura/age_signals", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      read { payload in result(payload) }
    }
  }

  private static let unavailable: [String: Any] = ["status": "unavailable"]

  private static func read(_ done: @escaping ([String: Any]) -> Void) {
    #if canImport(DeclaredAgeRange)
      if #available(iOS 26.2, *) {
        Task { @MainActor in
          do {
            guard try await AgeRangeService.shared.isEligibleForAgeFeatures,
              let presenter = topViewController()
            else {
              done(unavailable)
              return
            }
            // Gates 13 and 18 are the only ages Aura acts on; 16 splits the
            // teen band (ranges must span ≥ 2 years).
            let response = try await AgeRangeService.shared.requestAgeRange(
              ageGates: 13, 16, 18, in: presenter)
            switch response {
            case .declinedSharing:
              done(["status": "declined"])
            case .sharing(let range):
              done([
                "status": "shared",
                "lower": range.lowerBound.map { $0 as Any } ?? NSNull(),
                "upper": range.upperBound.map { $0 as Any } ?? NSNull(),
              ])
            @unknown default:
              done(unavailable)
            }
          } catch {
            done(unavailable)
          }
        }
        return
      }
    #endif
    done(unavailable)
  }

  @MainActor
  private static func topViewController() -> UIViewController? {
    let scene =
      UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

/// App ↔ OS glue (lib/src/features/voice/voice_devices.dart,
/// ChannelAuraPlatform). No plugin needed for these two calls.
private enum AuraPlatformChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.akvega.aura/platform", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "openAppSettings":
        // Mic denied → "turn it on in Settings": this app's page.
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
      case "excludeFromBackup":
        // Voice files live in Application Support, which iCloud backs up by
        // default: the `voice/` directory (and so its contents) opts out.
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        var url = URL(fileURLWithPath: path, isDirectory: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
          try url.setResourceValues(values)
          result(true)
        } catch {
          result(FlutterError(code: "io", message: nil, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
