// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Reading a package entry without trusting its declared size: the caps
// are enforced as the bytes come out.
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A package entry grew past its own cap, or past what the package may
/// still expand to ([total]).
class CapExceeded implements Exception {
  const CapExceeded({required this.total});
  final bool total;
}

/// Inflates [raw] while counting: the cap is enforced as bytes come out.
Uint8List inflateCapped(
  Uint8List raw,
  int method, {
  required int cap,
  required int remaining,
}) {
  if (method == ZipFile.zipCompressionStore) {
    if (raw.length > cap) throw const CapExceeded(total: false);
    if (raw.length > remaining) throw const CapExceeded(total: true);
    return raw;
  }
  final out = _CappedOutput(cap: cap, remaining: remaining);
  Inflate.stream(InputMemoryStream(raw), output: out);
  return out.getBytes();
}

class _CappedOutput extends OutputMemoryStream {
  _CappedOutput({required this.cap, required this.remaining});

  final int cap;
  final int remaining;
  int _written = 0;

  void _count(int n) {
    _written += n;
    if (_written > cap) throw const CapExceeded(total: false);
    if (_written > remaining) throw const CapExceeded(total: true);
  }

  @override
  void writeByte(int value) {
    _count(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _count(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _count(stream.length);
    super.writeStream(stream);
  }
}
