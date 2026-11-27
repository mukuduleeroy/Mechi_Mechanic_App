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
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MechiJobActions") else {
      return
    }
    let channel = FlutterMethodChannel(name: "mechi/job_actions", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard let argument = call.arguments as? String else {
        result(false)
        return
      }
      let url: URL?
      switch call.method {
      case "directions":
        guard let browser = URLComponents(string: argument),
              browser.scheme == "https", browser.host == "www.google.com",
              let destination = browser.queryItems?.first(where: { $0.name == "destination" })?.value else {
          result(false)
          return
        }
        var maps = URLComponents()
        maps.scheme = "maps"
        maps.host = ""
        maps.queryItems = [URLQueryItem(name: "daddr", value: destination),
                           URLQueryItem(name: "dirflg", value: "d")]
        if let appleMaps = maps.url {
          UIApplication.shared.open(appleMaps) { opened in
            if opened {
              result(true)
            } else if let fallback = browser.url {
              UIApplication.shared.open(fallback, completionHandler: { result($0) })
            } else {
              result(false)
            }
          }
          return
        }
        url = browser.url
      case "dial":
        url = URL(string: "tel:" + argument)
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url else {
        result(false)
        return
      }
      UIApplication.shared.open(url, completionHandler: { result($0) })
    }
  }
}
