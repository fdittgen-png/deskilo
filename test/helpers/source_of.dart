// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';

/// The source of the library at [path] with every part it names (#2386):
/// a test that reads a screen's source keeps reading all of it after the
/// screen is split across part files.
String sourceOf(String path) {
  final file = File(path);
  final text = file.readAsStringSync();
  final parts = RegExp(r"^part '([^']+)';", multiLine: true).allMatches(text);
  return [
    text,
    for (final m in parts)
      File('${file.parent.path}/${m.group(1)}').readAsStringSync(),
  ].join('\n');
}
