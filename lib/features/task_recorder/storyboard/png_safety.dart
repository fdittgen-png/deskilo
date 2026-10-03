// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — a PNG that leaves the app carries pixels and nothing else.
//
// [readPngHeader] checks the structure before anything is decoded or
// allocated: the signature, IHDR first, every chunk length inside the
// file, every CRC, the dimensions and the decoded pixel count against
// the bounds, IEND last. [stripPngMetadata] then keeps only the chunks
// that make the picture — IHDR, PLTE, tRNS, IDAT, IEND — and drops text,
// time, EXIF, colour profiles and anything unknown, so no author, tool,
// date or hidden payload rides along into a document or a video.
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Why an image was refused.
class PngRejected implements Exception {
  const PngRejected(this.reason);

  /// `signature`, `truncated`, `crc`, `header`, `dimensions`, `order`.
  final String reason;

  @override
  String toString() => 'PngRejected($reason)';
}

/// The bounds a picture must fit before it is decoded.
class PngLimits {
  const PngLimits({
    this.maxWidth = 2048,
    this.maxHeight = 2048,
    this.maxPixels = 2048 * 1536,
    this.maxBytes = 4 * 1024 * 1024,
  });

  final int maxWidth;
  final int maxHeight;
  final int maxPixels;
  final int maxBytes;
}

const _signature = [137, 80, 78, 71, 13, 10, 26, 10];
const _kept = {'IHDR', 'PLTE', 'tRNS', 'IDAT', 'IEND'};

class _Chunk {
  _Chunk(this.type, this.start, this.length);
  final String type;

  /// Offset of the length field.
  final int start;
  final int length;
  int get end => start + 12 + length;
}

List<_Chunk> _chunks(Uint8List bytes, PngLimits limits) {
  if (bytes.length > limits.maxBytes) throw const PngRejected('dimensions');
  if (bytes.length < 8 + 25 + 12) throw const PngRejected('truncated');
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != _signature[i]) throw const PngRejected('signature');
  }
  final data = ByteData.sublistView(bytes);
  final chunks = <_Chunk>[];
  var at = 8;
  while (at < bytes.length) {
    if (at + 12 > bytes.length) throw const PngRejected('truncated');
    final length = data.getUint32(at);
    if (length > bytes.length - at - 12) throw const PngRejected('truncated');
    final type = String.fromCharCodes(bytes.sublist(at + 4, at + 8));
    final crc = data.getUint32(at + 8 + length);
    if (getCrc32(bytes.sublist(at + 4, at + 8 + length)) != crc) {
      throw const PngRejected('crc');
    }
    chunks.add(_Chunk(type, at, length));
    at += 12 + length;
    if (type == 'IEND') break;
  }
  if (chunks.isEmpty ||
      chunks.first.type != 'IHDR' ||
      chunks.first.length != 13) {
    throw const PngRejected('header');
  }
  if (chunks.last.type != 'IEND' || at != bytes.length) {
    throw const PngRejected('order');
  }
  if (!chunks.any((c) => c.type == 'IDAT')) throw const PngRejected('order');
  return chunks;
}

/// The checked dimensions of [bytes]. Throws [PngRejected].
({int width, int height}) readPngHeader(
  Uint8List bytes, {
  PngLimits limits = const PngLimits(),
}) {
  _chunks(bytes, limits);
  final data = ByteData.sublistView(bytes);
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  if (width == 0 ||
      height == 0 ||
      width > limits.maxWidth ||
      height > limits.maxHeight ||
      width * height > limits.maxPixels) {
    throw const PngRejected('dimensions');
  }
  return (width: width, height: height);
}

/// [bytes] with every chunk but the picture's own removed. Throws
/// [PngRejected] for a malformed or oversized file.
Uint8List stripPngMetadata(
  Uint8List bytes, {
  PngLimits limits = const PngLimits(),
}) {
  readPngHeader(bytes, limits: limits);
  final out = BytesBuilder(copy: false)..add(bytes.sublist(0, 8));
  for (final c in _chunks(bytes, limits)) {
    if (_kept.contains(c.type)) out.add(bytes.sublist(c.start, c.end));
  }
  return out.toBytes();
}

/// The chunk types of [bytes], in order: what a test inspects.
List<String> pngChunkTypes(
  Uint8List bytes, {
  PngLimits limits = const PngLimits(),
}) => [for (final c in _chunks(bytes, limits)) c.type];
