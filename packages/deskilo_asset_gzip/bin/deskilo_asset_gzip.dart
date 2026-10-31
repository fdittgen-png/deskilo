// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Flutter runs an asset transformer as
//   dart run deskilo_asset_gzip --input=<file> --output=<file>
import 'dart:io';

import 'package:deskilo_asset_gzip/deskilo_asset_gzip.dart';

void main(List<String> args) {
  String? value(String name) {
    for (final a in args) {
      if (a.startsWith('--$name=')) return a.substring(name.length + 3);
    }
    return null;
  }

  final input = value('input');
  final output = value('output');
  if (input == null || output == null) {
    stderr.writeln('usage: deskilo_asset_gzip --input=<file> --output=<file>');
    exitCode = 64;
    return;
  }
  File(output).writeAsBytesSync(gzipDeterministic(File(input).readAsBytesSync()));
}
