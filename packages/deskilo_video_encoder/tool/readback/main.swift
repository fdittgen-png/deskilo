// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — independent readback of the Darwin encoder, outside Flutter.
//
//   swiftc -O darwin/deskilo_video_encoder/Sources/deskilo_video_encoder/VideoSession.swift \
//     tool/readback/main.swift -o "$TMPDIR/readback" && "$TMPDIR/readback"
//
// Encodes five 2-second "steps", each a distinct solid colour with a
// white bar whose width encodes the step number, re-sending each still
// once a second as the app does. Then it reads the file back with
// AVAssetReader (a different API from the writer): the container is MP4,
// the track is H.264 ('avc1'), the duration matches, the decoded frame
// in the middle of each step has that step's colour (no missing,
// duplicated, reordered or blank step), and the temporary file is gone.
// Exit code 0 only when every check passes.
import AVFoundation
import Foundation

let width = 640
let height = 360
let colors: [(UInt8, UInt8, UInt8)] = [
  (200, 30, 30), (30, 160, 40), (30, 60, 200), (220, 180, 20), (140, 40, 160),
]
let stepMs: Int64 = 2000

func frame(_ step: Int) -> Data {
  var data = Data(count: width * height * 4)
  let (r, g, b) = colors[step]
  data.withUnsafeMutableBytes { raw in
    let p = raw.bindMemory(to: UInt8.self)
    for y in 0..<height {
      for x in 0..<width {
        let o = (y * width + x) * 4
        let bar = y < 40 && x < (step + 1) * 100
        p[o] = bar ? 255 : r
        p[o + 1] = bar ? 255 : g
        p[o + 2] = bar ? 255 : b
        p[o + 3] = 255
      }
    }
  }
  return data
}

var failures = 0
func check(_ ok: Bool, _ what: String) {
  print((ok ? "PASS " : "FAIL ") + what)
  if !ok { failures += 1 }
}

let dir = FileManager.default.temporaryDirectory
let session = try VideoSession(
  width: width, height: height, bitrate: 2_000_000, keyframeIntervalMs: 2000, directory: dir)
for step in 0..<colors.count {
  let still = frame(step)
  var t: Int64 = 0
  while t < stepMs {
    try session.append(rgba: still, ptsMs: Int64(step) * stepMs + t)
    t += 1000
  }
}
let total = Int64(colors.count) * stepMs
let done = DispatchSemaphore(value: 0)
var output: Data?
session.finish(endMs: total, maxBytes: 64 * 1024 * 1024) { result in
  if case .success(let data) = result { output = data }
  done.signal()
}
done.wait()
check(output != nil, "finalized")
check(!FileManager.default.fileExists(atPath: session.url.path), "temporary file deleted")
guard let mp4 = output else { exit(1) }
let ftyp = String(data: mp4.subdata(in: 4..<8), encoding: .ascii)
check(ftyp == "ftyp", "MP4 container (ftyp box first)")
let copy = dir.appendingPathComponent("deskilo-readback-\(UUID().uuidString).mp4")
try mp4.write(to: copy)
defer { try? FileManager.default.removeItem(at: copy) }

let asset = AVURLAsset(url: copy)
let sem = DispatchSemaphore(value: 0)
var track: AVAssetTrack?
var seconds = 0.0
var subtype: FourCharCode = 0
Task {
  let tracks = try await asset.loadTracks(withMediaType: .video)
  track = tracks.first
  seconds = try await asset.load(.duration).seconds
  if let t = track, let desc = try await t.load(.formatDescriptions).first {
    subtype = CMFormatDescriptionGetMediaSubType(desc)
  }
  sem.signal()
}
sem.wait()
check(track != nil, "one video track")
check(subtype == kCMVideoCodecType_H264, "codec is H.264 (avc1)")
check(abs(seconds - Double(total) / 1000) < 0.15, "duration \(seconds)s ≈ \(Double(total) / 1000)s")

let reader = try AVAssetReader(asset: asset)
let out = AVAssetReaderTrackOutput(
  track: track!,
  outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(out)
reader.startReading()
var seen: [Int] = []
var frames = 0
while let sample = out.copyNextSampleBuffer() {
  frames += 1
  let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
  guard let px = CMSampleBufferGetImageBuffer(sample) else { continue }
  CVPixelBufferLockBaseAddress(px, .readOnly)
  let base = CVPixelBufferGetBaseAddress(px)!.assumingMemoryBound(to: UInt8.self)
  let row = CVPixelBufferGetBytesPerRow(px)
  let o = (height / 2) * row + (width / 2) * 4
  let (b, g, r) = (Int(base[o]), Int(base[o + 1]), Int(base[o + 2]))
  CVPixelBufferUnlockBaseAddress(px, .readOnly)
  let step = colors.enumerated().min { a, c in
    let da = abs(Int(a.element.0) - r) + abs(Int(a.element.1) - g) + abs(Int(a.element.2) - b)
    let dc = abs(Int(c.element.0) - r) + abs(Int(c.element.1) - g) + abs(Int(c.element.2) - b)
    return da < dc
  }!.offset
  check(step == Int(pts * 1000) / Int(stepMs), "frame at \(pts)s shows step \(step + 1)")
  if seen.last != step { seen.append(step) }
}
check(reader.status == .completed, "decoder read to the end")
check(seen == Array(0..<colors.count), "steps in order, none missing or repeated: \(seen)")
check(frames == colors.count * 2, "\(frames) frames decoded")
print(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
