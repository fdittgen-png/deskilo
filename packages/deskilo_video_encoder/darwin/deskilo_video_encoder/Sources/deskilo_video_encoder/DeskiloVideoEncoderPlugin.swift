// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the method channel in front of VideoSession (protocol in
// lib/deskilo_video_encoder.dart). Every call runs on one serial queue,
// so frames are appended in order and one at a time; the reply to
// addFrame is sent only after the frame was appended.
import Foundation

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

public class DeskiloVideoEncoderPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "de.deskilo.video_encoder")
  private var sessions: [Int: VideoSession] = [:]
  private var nextId = 1
  private static let maxBytes = 64 * 1024 * 1024

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "deskilo/video_encoder", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(DeskiloVideoEncoderPlugin(), channel: channel)
  }

  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private func fail(_ result: @escaping FlutterResult, _ code: String) {
    DispatchQueue.main.async { result(FlutterError(code: code, message: nil, details: nil)) }
  }

  private static func code(_ error: Error) -> String {
    switch error as? VideoSessionError {
    case .unsupported?: return "unsupported"
    case .badArgs?: return "bad_args"
    case .finalizeFailed?: return "finalize_failed"
    default: return "encode_failed"
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async { [self] in
      switch call.method {
      case "probe":
        let ok = VideoSession.supports(
          width: args["width"] as? Int ?? 0, height: args["height"] as? Int ?? 0)
        reply(result, ["supported": ok, "reason": ok ? NSNull() : "unsupported"] as [String: Any])
      case "start":
        do {
          let session = try VideoSession(
            width: args["width"] as? Int ?? 0, height: args["height"] as? Int ?? 0,
            bitrate: args["bitrate"] as? Int ?? 2_000_000,
            keyframeIntervalMs: args["keyframeIntervalMs"] as? Int ?? 2000,
            directory: FileManager.default.temporaryDirectory)
          let id = nextId
          nextId += 1
          sessions[id] = session
          reply(result, id)
        } catch {
          fail(result, Self.code(error))
        }
      case "addFrame":
        guard let id = args["session"] as? Int, let session = sessions[id] else {
          return fail(result, "no_session")
        }
        guard let frame = args["rgba"] as? FlutterStandardTypedData,
          let pts = (args["ptsMs"] as? NSNumber)?.int64Value
        else { return fail(result, "bad_args") }
        do {
          try session.append(rgba: frame.data, ptsMs: pts)
          reply(result, nil)
        } catch {
          session.cancel()
          sessions[id] = nil
          fail(result, Self.code(error))
        }
      case "finish":
        guard let id = args["session"] as? Int, let session = sessions.removeValue(forKey: id)
        else { return fail(result, "no_session") }
        let end = (args["endMs"] as? NSNumber)?.int64Value ?? 0
        let done = DispatchSemaphore(value: 0)
        session.finish(endMs: end, maxBytes: Self.maxBytes) { outcome in
          switch outcome {
          case .success(let data): self.reply(result, FlutterStandardTypedData(bytes: data))
          case .failure(let error): self.fail(result, Self.code(error))
          }
          done.signal()
        }
        done.wait()
      case "cancel":
        if let id = args["session"] as? Int, let session = sessions.removeValue(forKey: id) {
          session.cancel()
        }
        reply(result, nil)
      default:
        DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
      }
    }
  }
}
