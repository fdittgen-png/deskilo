// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — one H.264/MP4 encode with AVAssetWriter.
//
// Frames arrive as RGBA from the app's off-screen renderer, are permuted
// to BGRA with vImage into a pixel buffer from the adaptor's pool, and are
// appended at their presentation time. append() waits (bounded) for the
// input to be ready: that wait is the backpressure the Dart side awaits.
// The temporary file belongs to this session: finish() reads and deletes
// it after the writer COMPLETED, cancel() cancels the writer and deletes
// it. No Flutter import, so the same file builds the readback harness.
import AVFoundation
import Accelerate
import CoreMedia
import CoreVideo
import Foundation

enum VideoSessionError: Error {
  case unsupported
  case encodeFailed
  case finalizeFailed
  case badArgs
}

final class VideoSession {
  let width: Int
  let height: Int
  let url: URL
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor
  private var lastPts: Int64 = -1

  static func supports(width: Int, height: Int) -> Bool {
    width > 0 && height > 0 && width <= 1920 && height <= 1920
      && width % 2 == 0 && height % 2 == 0
  }

  init(width: Int, height: Int, bitrate: Int, keyframeIntervalMs: Int, directory: URL) throws {
    guard VideoSession.supports(width: width, height: height) else {
      throw VideoSessionError.unsupported
    }
    self.width = width
    self.height = height
    url = directory.appendingPathComponent("deskilo-video-\(UUID().uuidString).mp4")
    writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoMaxKeyFrameIntervalDurationKey: Double(keyframeIntervalMs) / 1000.0,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoAllowFrameReorderingKey: false,
      ],
    ]
    input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ])
    guard writer.canAdd(input) else { throw VideoSessionError.unsupported }
    writer.add(input)
    guard writer.startWriting() else {
      try? FileManager.default.removeItem(at: url)
      throw VideoSessionError.unsupported
    }
    writer.startSession(atSourceTime: .zero)
  }

  func append(rgba: Data, ptsMs: Int64) throws {
    guard rgba.count == width * height * 4, ptsMs > lastPts else {
      throw VideoSessionError.badArgs
    }
    var waited = 0
    while !input.isReadyForMoreMediaData {
      if writer.status != .writing || waited > 10_000 {
        throw VideoSessionError.encodeFailed
      }
      usleep(5_000)
      waited += 5
    }
    guard let pool = adaptor.pixelBufferPool else { throw VideoSessionError.encodeFailed }
    var buffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
      let pixels = buffer
    else { throw VideoSessionError.encodeFailed }
    CVPixelBufferLockBaseAddress(pixels, [])
    defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
    guard let base = CVPixelBufferGetBaseAddress(pixels) else {
      throw VideoSessionError.encodeFailed
    }
    let rowBytes = CVPixelBufferGetBytesPerRow(pixels)
    let status: vImage_Error = rgba.withUnsafeBytes { raw in
      var source = vImage_Buffer(
        data: UnsafeMutableRawPointer(mutating: raw.baseAddress!),
        height: vImagePixelCount(height), width: vImagePixelCount(width),
        rowBytes: width * 4)
      var dest = vImage_Buffer(
        data: base, height: vImagePixelCount(height), width: vImagePixelCount(width),
        rowBytes: rowBytes)
      let map: [UInt8] = [2, 1, 0, 3]  // RGBA -> BGRA
      return vImagePermuteChannels_ARGB8888(&source, &dest, map, vImage_Flags(kvImageNoFlags))
    }
    guard status == kvImageNoError else { throw VideoSessionError.encodeFailed }
    guard adaptor.append(pixels, withPresentationTime: CMTime(value: ptsMs, timescale: 1000))
    else { throw VideoSessionError.encodeFailed }
    lastPts = ptsMs
  }

  /// Finalizes and returns the MP4 bytes; the file is deleted either way.
  func finish(endMs: Int64, maxBytes: Int, completion: @escaping (Result<Data, VideoSessionError>) -> Void) {
    input.markAsFinished()
    writer.endSession(atSourceTime: CMTime(value: max(endMs, lastPts + 1), timescale: 1000))
    writer.finishWriting { [url, writer] in
      let data = writer.status == .completed ? try? Data(contentsOf: url) : nil
      // Deleted BEFORE anyone hears the result: no partial or finished
      // copy outlives the session.
      try? FileManager.default.removeItem(at: url)
      guard let data, !data.isEmpty, data.count <= maxBytes else {
        completion(.failure(.finalizeFailed))
        return
      }
      completion(.success(data))
    }
  }

  func cancel() {
    if writer.status == .writing { writer.cancelWriting() }
    try? FileManager.default.removeItem(at: url)
  }
}
