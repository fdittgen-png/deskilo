// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1455 — the protected baseline of applied migrations.
//
// A migration that has been applied to the reference project is history:
// editing its file cannot change what the hosted schema holds, and a file
// that differs from what was applied is a replay that no longer builds
// the same database. So every applied file's digest is recorded here, and
// `test/lint/applied_migrations_immutable_test.dart` fails when a recorded
// file changes or when a new file is slipped in below the baseline.
//
//   dart run tool/record_applied_migrations.dart          # record every file
//   dart run tool/record_applied_migrations.dart --through 0245
//
// Run it as the last step of applying a migration to the reference project
// (the ritual in deskilo-supabase-migration): a file that is not applied
// yet — a branch's draft — is left out and stays free to change.
import 'dart:io';

import 'applied_migrations/applied.dart';

// Dart ignores what `main` returns; the exit code is set here.
void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  final i = args.indexOf('--through');
  final through = i < 0 || i + 1 >= args.length ? null : args[i + 1];
  final recorded = recordApplied(
    Directory(migrationsDir),
    through: through,
  );
  File(baselinePath).writeAsStringSync(recorded);
  final n = recorded.split('\n').where((l) => l.isNotEmpty && !l.startsWith('#')).length;
  stdout.writeln('wrote $baselinePath: $n applied migrations');
  return 0;
}
