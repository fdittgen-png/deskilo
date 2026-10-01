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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeskiloCapture") {
      CaptureGuard.shared.attach(messenger: registrar.messenger())
    }
  }
}

/// #1824 — screen-capture protection for the messenger on iOS.
///
/// iOS cannot refuse a screenshot, so while a conversation is on screen
/// (`enable` … `disable` from Dart, channel `deskilo/capture`) this:
/// - tells Dart when a screenshot was taken (`screenshot`), which posts
///   the notice into the conversation;
/// - tells Dart when the screen starts or stops being recorded,
///   mirrored or AirPlayed (`captured`), which hides the conversation;
/// - covers the window with a blur when the app leaves the foreground,
///   so the app-switcher snapshot shows no message.
final class CaptureGuard: NSObject {
  static let shared = CaptureGuard()

  private var channel: FlutterMethodChannel?
  private var enabled = false
  private var cover: UIView?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "deskilo/capture", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "enable":
        self.enabled = true
        result(self.isCaptured())
      case "disable":
        self.enabled = false
        self.removeCover()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(screenshotTaken),
      name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    center.addObserver(
      self, selector: #selector(captureChanged),
      name: UIScreen.capturedDidChangeNotification, object: nil)
    center.addObserver(
      self, selector: #selector(willResignActive),
      name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  private func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  private func isCaptured() -> Bool {
    keyWindow()?.windowScene?.screen.isCaptured ?? false
  }

  @objc private func screenshotTaken() {
    guard enabled else { return }
    channel?.invokeMethod("screenshot", arguments: nil)
  }

  @objc private func captureChanged() {
    guard enabled else { return }
    channel?.invokeMethod("captured", arguments: isCaptured())
  }

  @objc private func willResignActive() {
    guard enabled, cover == nil, let window = keyWindow() else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    cover = blur
  }

  @objc private func didBecomeActive() {
    removeCover()
  }

  private func removeCover() {
    cover?.removeFromSuperview()
    cover = nil
  }
}
