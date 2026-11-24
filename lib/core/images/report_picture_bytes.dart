// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3984 — a report picture is stored at print size when it is added.
//
// The pattern of emblem_bytes.dart: decode with the platform's codec at a
// target size, then encode. A picture within the size, the format rule and
// the weight is handed back as it arrived, byte for byte; otherwise the
// result is a JPEG (no transparency) or a PNG (transparency). The name is
// the caller's and never changes.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../trace/traced_compute.dart';
import 'report_picture_sizes.dart';

/// A picture ready to be stored: its bytes and the content type read from
/// them, not from a file's ending.
class ReportPicture {
  const ReportPicture(this.bytes, this.contentType);

  final Uint8List bytes;
  final String contentType;
}

/// Why a file is not a picture a report can hold.
class ReportPictureException implements Exception {
  const ReportPictureException();

  @override
  String toString() => 'not a JPEG, PNG or WebP picture';
}

const _jpeg = 'image/jpeg';
const _png = 'image/png';

/// The content type of [b] by its first bytes, or null when it is none of
/// JPEG, PNG and WebP.
@visibleForTesting
String? reportPictureTypeOf(Uint8List b) {
  bool at(int i, List<int> sig) {
    if (b.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (b[i + k] != sig[k]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return _jpeg;
  if (at(0, const [0x89, 0x50, 0x4E, 0x47])) return _png;
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
      at(8, const [0x57, 0x45, 0x42, 0x50])) {
    return 'image/webp';
  }
  return null;
}

/// [bytes] at print size: see the constants in report_picture_sizes.dart.
///
/// Throws [ReportPictureException] for bytes that are no picture.
Future<ReportPicture> reportPictureForPrint(Uint8List bytes) async {
  final type = reportPictureTypeOf(bytes);
  final img.DecodeInfo? info = type == null
      ? null
      : img.findDecoderForData(bytes)?.startDecode(bytes);
  if (type == null || info == null) throw const ReportPictureException();
  final longest = math.max(info.width, info.height);

  // A JPEG within size and weight has nothing to change: it uses no
  // transparency and the PDF takes it as it is.
  if (type == _jpeg &&
      longest <= reportPictureMaxEdge &&
      bytes.lengthInBytes <= reportPictureMaxBytes) {
    return ReportPicture(bytes, _jpeg);
  }

  final source = _Source(bytes, info.width, info.height);
  final first = await source.decode(reportPictureMaxEdge);
  try {
    if (_usesTransparency(first.rgba)) {
      if (type == _png &&
          longest <= reportPictureMaxEdgeTransparent &&
          bytes.lengthInBytes <= reportPictureMaxBytes) {
        return ReportPicture(bytes, _png);
      }
      return await _asPng(source, first);
    }
    return await _asJpeg(source, first);
  } finally {
    first.image.dispose();
  }
}

class _Decoded {
  const _Decoded(this.image, this.rgba);

  final ui.Image image;
  final Uint8List rgba;
}

/// The picture as it arrived, decoded by the platform at a chosen edge.
class _Source {
  const _Source(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  /// Decoded at [edge] across at most; a picture is never enlarged.
  Future<_Decoded> decode(int edge) async {
    final scale = edge / math.max(width, height);
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: scale < 1 && width >= height
            ? (width * scale).round()
            : null,
        targetHeight: scale < 1 && height > width
            ? (height * scale).round()
            : null,
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final data = await image.toByteData();
      if (data == null) throw const ReportPictureException();
      return _Decoded(image, data.buffer.asUint8List());
    } on ReportPictureException {
      rethrow;
    } on Object {
      // trace-exempt: a file the platform cannot decode is a refusal.
      throw const ReportPictureException();
    }
  }
}

bool _usesTransparency(Uint8List rgba) {
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0xFF) return true;
  }
  return false;
}

Future<ReportPicture> _asJpeg(_Source source, _Decoded first) async {
  var current = first;
  var quality = reportPictureJpegQuality;
  while (true) {
    final out = await _encodeJpeg(current, quality);
    if (out.lengthInBytes <= reportPictureMaxBytes) {
      return ReportPicture(out, _jpeg);
    }
    if (quality - reportPictureJpegQualityStep >=
        reportPictureJpegQualityFloor) {
      quality -= reportPictureJpegQualityStep;
      continue;
    }
    final edge =
        (math.max(current.image.width, current.image.height) *
                reportPictureScaleStep)
            .floor();
    if (edge < reportPictureMinEdge) return ReportPicture(out, _jpeg);
    final next = await source.decode(edge);
    if (!identical(current, first)) current.image.dispose();
    current = next;
  }
}

Future<ReportPicture> _asPng(_Source source, _Decoded first) async {
  var edge = math.min(
    math.max(source.width, source.height),
    reportPictureMaxEdgeTransparent,
  );
  var current = edge < math.max(first.image.width, first.image.height)
      ? await source.decode(edge)
      : first;
  while (true) {
    final data = await current.image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw const ReportPictureException();
    final out = data.buffer.asUint8List();
    final next = (edge * reportPictureScaleStep).floor();
    if (out.lengthInBytes <= reportPictureMaxBytes ||
        next < reportPictureMinEdge) {
      if (!identical(current, first)) current.image.dispose();
      return ReportPicture(out, _png);
    }
    edge = next;
    final scaled = await source.decode(edge);
    if (!identical(current, first)) current.image.dispose();
    current = scaled;
  }
}

/// JPEG encoding runs off the interface's thread where there is one.
Future<Uint8List> _encodeJpeg(_Decoded picture, int quality) => tracedCompute(
  _jpegOf,
  (picture.rgba, picture.image.width, picture.image.height, quality),
  area: 'images',
  what: 'a report picture encoding',
);

Uint8List _jpegOf((Uint8List, int, int, int) job) {
  final (rgba, width, height, quality) = job;
  final picture = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(picture, quality: quality);
}
