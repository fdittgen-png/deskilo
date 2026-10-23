import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// #2559 C1 — the app-switcher privacy cover on iPhone.
///
/// Registered as a scene life-cycle delegate of the Flutter engine
/// (`addSceneDelegate`, AppDelegate), so FlutterSceneDelegate keeps every
/// callback it handles — the deskilo:// links, orientations, the
/// engine's own life cycle — and calls this synchronously beside them.
///
/// Dart (channel `deskilo/switcher_cover`) says what the window shows:
/// `setProtectedContext(protected, frameEpoch)` and, once that frame is on
/// screen, `foregroundReady(frameEpoch)`. Nothing private crosses: this
/// keeps the protection, the current frame epoch, whether the scene is
/// active and whether the cover is up.
///
/// - `sceneWillResignActive` while protected: an opaque neutral view (the
///   system background and the launch mark — no blur, no animation) over
///   the whole window, resizing with it, so the switcher snapshot shows
///   nothing private.
/// - `sceneDidBecomeActive`: it stays until the CURRENT frame is
///   acknowledged; a stale epoch never lifts it.
/// - `sceneDidDisconnect`: the view goes with the scene; nothing builds up.
///
/// It starts protected with no frame, so a cover raised before Dart spoke
/// waits for a real acknowledgement.
final class SwitcherCover: NSObject, FlutterSceneLifeCycleDelegate {
  static let shared = SwitcherCover()
  static let channelName = "deskilo/switcher_cover"
  private static let noFrame: Int64 = -1

  private var channel: FlutterMethodChannel?
  private var protectedContext = true
  private var frameEpoch = SwitcherCover.noFrame
  private var active = false
  private var cover: UIView?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: SwitcherCover.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let epoch = (arguments?["frameEpoch"] as? NSNumber)?.int64Value
      switch call.method {
      case "setProtectedContext":
        guard let protect = arguments?["protected"] as? Bool, let epoch = epoch else {
          result(FlutterError(code: "bad_args", message: "protected and frameEpoch required", details: nil))
          return
        }
        self.protectedContext = protect
        self.frameEpoch = epoch
        // Nothing to hide any more, and the person is looking: lift it.
        if !protect && self.active { self.removeCover() }
        result(nil)
      case "foregroundReady":
        guard let epoch = epoch else {
          result(FlutterError(code: "bad_args", message: "frameEpoch required", details: nil))
          return
        }
        // Only the current frame, drawn while active, lifts it.
        if self.active && epoch == self.frameEpoch { self.removeCover() }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  func sceneWillResignActive(_ scene: UIScene) {
    active = false
    guard protectedContext, cover == nil, let window = window(of: scene) else { return }
    let view = UIView(frame: window.bounds)
    view.backgroundColor = .systemBackground
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.isUserInteractionEnabled = true
    view.accessibilityElementsHidden = true
    if let mark = UIImage(named: "LaunchImage") {
      let image = UIImageView(image: mark)
      image.contentMode = .center
      image.frame = view.bounds
      image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(image)
    }
    window.addSubview(view)
    cover = view
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    active = true
    if !protectedContext { removeCover() }
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    active = false
    removeCover()
  }

  private func window(of scene: UIScene) -> UIWindow? {
    guard let windowScene = scene as? UIWindowScene else { return nil }
    return windowScene.windows.first { $0.isKeyWindow } ?? windowScene.windows.first
  }

  private func removeCover() {
    cover?.removeFromSuperview()
    cover = nil
  }
}
