// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 (PERF-9) — the gzip a build applies to a large asset. Deterministic:
// the same input gives the same bytes on every machine, so a reproducible
// build (F-Droid) stays reproducible. dart:io's encoder writes no file name
// and a zero modification time; the OS byte of the header is pinned here
// because it otherwise names the platform that built the file.
import 'dart:io';
import 'dart:typed_data';

/// Offset of the gzip header's OS byte (RFC 1952 §2.3).
const _osByte = 9;

/// "Unknown" in RFC 1952: the same on every build machine.
const _osUnknown = 255;

Uint8List gzipDeterministic(List<int> bytes) {
  final out = Uint8List.fromList(GZipCodec(level: 9).encode(bytes));
  out[_osByte] = _osUnknown;
  return out;
}
