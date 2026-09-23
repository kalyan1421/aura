import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    AuraPlatformChannel.register(messenger: engineBridge.applicationRegistrar.messenger())
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
