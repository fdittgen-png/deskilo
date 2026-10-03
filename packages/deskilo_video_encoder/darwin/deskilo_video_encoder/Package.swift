// swift-tools-version: 5.9
// SPDX-License-Identifier: AGPL-3.0-or-later

import PackageDescription

let package = Package(
  name: "deskilo_video_encoder",
  platforms: [
    .iOS("15.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "deskilo-video-encoder", targets: ["deskilo_video_encoder"])
  ],
  dependencies: [],
  targets: [
    .target(name: "deskilo_video_encoder", dependencies: [])
  ]
)
