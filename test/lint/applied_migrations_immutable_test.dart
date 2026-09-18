// SPDX-License-Identifier: 0BSD
//
// #1455 — an applied migration is history.
//
// `supabase/APPLIED.sha256` records the digest of every file
// applied to the reference project. Editing one of them cannot change what
// the hosted schema holds — it only makes the replay build a different
// database than the one people run — and a new file inserted below the
// baseline would replay in an order the reference never saw. Both fail
// here. Files above the baseline are drafts and stay free.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/applied_migrations/applied.dart';

void main() {
  final dir = Directory(migrationsDir);
  final baseline = parseBaseline(File(baselinePath).readAsStringSync());

  test('the baseline records every applied migration, and the tree honours it', () {
    expect(baseline, isNotEmpty);
    final problems = auditBaseline(dir, baseline);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('an edited applied file, a removed one and one slipped in below the '
      'baseline are each caught', () {
    final tmp = Directory.systemTemp.createTempSync('applied');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File('${tmp.path}/0001_a.sql').writeAsStringSync('select 1;\n');
    File('${tmp.path}/0002_b.sql').writeAsStringSync('select 2;\n');
    final recorded = parseBaseline(recordApplied(tmp));
    expect(auditBaseline(tmp, recorded), isEmpty);

    File('${tmp.path}/0001_a.sql').writeAsStringSync('select 1; -- edited\n');
    expect(auditBaseline(tmp, recorded).single, contains('0001_a.sql was applied'));
    File('${tmp.path}/0001_a.sql').writeAsStringSync('select 1;\n');

    File('${tmp.path}/0001_z.sql').writeAsStringSync('select 0;\n');
    expect(auditBaseline(tmp, recorded).single, contains('below the applied baseline'));
    File('${tmp.path}/0001_z.sql').deleteSync();

    File('${tmp.path}/0003_c.sql').writeAsStringSync('select 3;\n');
    expect(auditBaseline(tmp, recorded), isEmpty, reason: 'a draft above the baseline is free');

    File('${tmp.path}/0002_b.sql').deleteSync();
    expect(auditBaseline(tmp, recorded).single, contains('the file is gone'));
  });

  test('--through leaves later files out of the record', () {
    final tmp = Directory.systemTemp.createTempSync('applied');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File('${tmp.path}/0001_a.sql').writeAsStringSync('select 1;\n');
    File('${tmp.path}/0002_b.sql').writeAsStringSync('select 2;\n');
    expect(parseBaseline(recordApplied(tmp, through: '0001')).keys, ['0001_a.sql']);
  });
}
