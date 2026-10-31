// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 — the build's gzip is reversible and deterministic: the same input
// gives byte-identical output, with no time stamp and no build platform in
// the header, so a reproducible build stays reproducible.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo_asset_gzip/deskilo_asset_gzip.dart';
import 'package:test/test.dart';

void main() {
  final input = utf8.encode('{"schema":[${List.filled(500, '"x"').join(',')}]}');

  test('decodes back to the input', () {
    expect(gzip.decode(gzipDeterministic(input)), input);
  });

  test('the same input gives the same bytes', () {
    expect(gzipDeterministic(input), gzipDeterministic(input));
  });

  test('the header carries no time and no build platform', () {
    final header = gzipDeterministic(input).sublist(0, 10);
    expect(header.sublist(4, 8), [0, 0, 0, 0], reason: 'MTIME');
    expect(header[9], 255, reason: 'OS = unknown');
    expect(header[3] & 0x08, 0, reason: 'no file name');
  });

  test('the transformer writes the gzip of its input', () {
    final dir = Directory.systemTemp.createTempSync('asset_gzip_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = File('${dir.path}/in.json')..writeAsBytesSync(input);
    final target = '${dir.path}/out.json';
    final run = Process.runSync(Platform.resolvedExecutable, [
      'run',
      'bin/deskilo_asset_gzip.dart',
      '--input=${source.path}',
      '--output=$target',
    ]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(File(target).readAsBytesSync(), gzipDeterministic(input));
  });
}
