Pod::Spec.new do |s|
  s.name             = 'deskilo_video_encoder'
  s.version          = '1.0.0'
  s.summary          = 'DesKilo tutorial video encoder (AVAssetWriter, H.264/MP4).'
  s.description      = 'Encodes app-drawn RGBA frames into an H.264 MP4 with AVFoundation. No third-party codec, no network.'
  s.homepage         = 'https://github.com/fdittgen-png/deskilo'
  s.license          = { :type => 'AGPL-3.0-or-later' }
  s.author           = { 'DesKilo' => 'noreply@deskilo.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'deskilo_video_encoder/Sources/deskilo_video_encoder/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '10.15'
  s.frameworks       = 'AVFoundation', 'CoreMedia', 'CoreVideo', 'Accelerate'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
