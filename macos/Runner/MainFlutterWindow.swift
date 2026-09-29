import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // #1824 — screen-capture protection for the messenger: while a
    // conversation is on screen the window is excluded from screenshots
    // and screen sharing. `enable` answers whether the screen is being
    // captured right now; macOS blocks rather than detects, so: never.
    let capture = FlutterMethodChannel(
      name: "deskilo/capture",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    capture.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        self?.sharingType = .none
        result(false)
      case "disable":
        self?.sharingType = .readOnly
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
