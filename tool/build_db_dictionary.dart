// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1911 — regenerates the data dictionary's renderings from the committed
// catalogue extraction, docs/database/dictionary.json.
//
//   dart run tool/build_db_dictionary.dart          write what differs
//   dart run tool/build_db_dictionary.dart --check  fail when anything differs
//
// The JSON itself is written by scripts/db_dictionary.sh from a database's
// catalogues; `test/tool/db_dictionary_test.dart` fails when a committed
// rendering is not what this writes.
import 'dart:convert';
import 'dart:io';

import 'db_dictionary/render.dart';

// Dart ignores what `main` returns; the exit code is set here.
void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  final source = File('docs/database/dictionary.json');
  if (!source.existsSync()) {
    stderr.writeln('docs/database/dictionary.json is missing');
    return 2;
  }
  final dictionary =
      jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final problems = verifyDictionary(dictionary);
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    return 1;
  }
  final check = args.contains('--check');
  var drift = 0;
  for (final entry in renderDictionary(dictionary).entries) {
    final file = File(entry.key)..parent.createSync(recursive: true);
    final same = file.existsSync() && file.readAsStringSync() == entry.value;
    if (same) continue;
    drift++;
    if (check) {
      stderr.writeln('${entry.key} is not what the dictionary renders');
    } else {
      file.writeAsStringSync(entry.value);
      stdout.writeln('wrote ${entry.key}');
    }
  }
  return check && drift > 0 ? 1 : 0;
}
