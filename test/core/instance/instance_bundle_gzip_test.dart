// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 — the build gzips the instance bundle (asset transformer
// deskilo_asset_gzip); a run without the transformer reads the plain file.
// Either form gives the same bundle.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/core/instance/instance_bundle_asset.dart';
import 'package:deskilo_asset_gzip/deskilo_asset_gzip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plain = File('assets/instance/bundle.json').readAsBytesSync();

  test('the gzipped and the plain asset give the same bundle', () {
    final fromPlain = decodeInstanceBundleAsset(plain);
    final fromGzip = decodeInstanceBundleAsset(gzipDeterministic(plain));
    expect(fromGzip.schema.length, fromPlain.schema.length);
    expect(fromGzip.schemaVersion, fromPlain.schemaVersion);
    expect(
      jsonEncode([for (final m in fromGzip.schema) m.sql]),
      jsonEncode([for (final m in fromPlain.schema) m.sql]),
    );
  });

  test('the build ships a fraction of the plain size', () {
    final packed = gzipDeterministic(plain);
    expect(
      packed.length * 4,
      lessThan(plain.length),
      reason: '${plain.length} → ${packed.length} bytes',
    );
    expect(
      decodeInstanceBundleAsset(Uint8List.fromList(packed)).schema,
      isNotEmpty,
    );
  });
}
