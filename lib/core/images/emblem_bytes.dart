// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — what a workspace's emblem is allowed to be, before it is
// stored.
//
// An emblem arrives as a file somebody chose: any size, any format the
// bucket accepts, and whatever metadata their camera or design tool put
// in it — which for a photograph includes the place it was taken.
//
// So nothing is uploaded as it arrived. The image is decoded, drawn once
// into a canvas at most [maxEdge] across, and re-encoded as PNG. That
// bounds the bytes and the dimensions, and it strips every metadata
// block by construction: the output is pixels this code drew, not a file
// somebody handed over with an EXIF block travelling inside it.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'emblem_refusal.dart';

export 'emblem_refusal.dart';

/// The longest edge an emblem is stored at. It is shown beside the app
/// logo — a drawer header, a switcher row — so anything larger is bytes
/// nobody sees.
const int maxEmblemEdge = 512;

/// The most an emblem may weigh once re-encoded. A 512-pixel PNG of a
/// logo is a few tens of kilobytes; a quarter of a megabyte is room for
/// a photographic one and still a refusal for the pathological.
const int maxEmblemBytes = 256 * 1024;

/// The PNG to store for [bytes]: at most [maxEmblemEdge] on its longest
/// side, aspect kept, metadata gone.
///
/// Throws [EmblemException] rather than returning null, because the two
/// refusals need different words on screen.
Future<Uint8List> emblemPngOf(Uint8List bytes) async {
  final ui.Image source;
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: null,
      targetHeight: null,
    );
    source = (await codec.getNextFrame()).image;
  } on Object {
    // trace-exempt: a file the platform cannot decode is a refusal with
    // its own sentence, not a fault to report.
    throw const EmblemException(EmblemRefusal.notAnImage);
  }

  final scale = maxEmblemEdge /
      (source.width > source.height ? source.width : source.height);
  final width = scale >= 1 ? source.width : (source.width * scale).round();
  final height = scale >= 1 ? source.height : (source.height * scale).round();

  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    source,
    ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final drawn = await recorder.endRecording().toImage(width, height);
  final png = await drawn.toByteData(format: ui.ImageByteFormat.png);
  source.dispose();
  drawn.dispose();
  if (png == null) throw const EmblemException(EmblemRefusal.notAnImage);
  final out = png.buffer.asUint8List();
  if (out.lengthInBytes > maxEmblemBytes) {
    throw const EmblemException(EmblemRefusal.tooHeavy);
  }
  return out;
}
