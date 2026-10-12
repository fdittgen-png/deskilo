// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

/// The chunk types of the PNG [bytes], in order: what a test inspects
/// (#2383: lib/ only strips chunks, it never lists them). Walks the plain
/// layout — an 8-byte signature, then length, type, data and CRC per chunk.
List<String> pngChunkTypes(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final types = <String>[];
  var at = 8;
  while (at + 8 <= bytes.length) {
    final length = data.getUint32(at);
    types.add(String.fromCharCodes(bytes.sublist(at + 4, at + 8)));
    at += 12 + length;
  }
  return types;
}
