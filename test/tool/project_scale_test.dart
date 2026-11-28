// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1334 — a measure nobody checks is the same rot in a new place.
//
// `docs/PROJECT_OVERVIEW.md` used to answer "how big is this?" from
// memory, and by the time anyone read it the answers were off by a
// factor of three. Replacing prose with a tool only helps if the tool
// is right, so each measure below is tied to an authority that already
// exists in the repository — the feature enum itself, the schema
// version marker, the inventory's own file list — rather than to a
// number this test made up.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/project_scale/scale.dart';
import '../../tool/test_inventory/inventory.dart' show testFiles;

/// Migration numbers taken by a lane at push time and never used, or taken by a branch not yet on this one.
/// A number listed here must have no file: the branch that brings it takes it off the list.
const _notUsed = {
  898, // till S4 (#4185), folded into 0897
  899, // till S4 (#4185), folded into 0897
  902, // standalone payments (#4165 B1), done in 0901
  903, // standalone payments (#4165 B1), done in 0901
  904, // standalone payments (#4165 B1), done in 0901
  912, // billing access (#4164 B1), done in 0910-0911
  913, // billing access (#4164 B1), done in 0910-0911
  914, // billing access (#4164 B1), done in 0910-0911
  924, // reserved with 0922-0923 (#4432), not needed
  932, // reserved for #4436, renumbered to 0939-0940
  933, // reserved for #4436, renumbered to 0939-0940
  992, // 2e's lane, on its own branch
};

int _valueOf(List<Measure> all, String startsWith) => all
    .firstWhere((m) => m.name.startsWith(startsWith),
        orElse: () => throw StateError('no measure named "$startsWith"'))
    .value;

void main() {
  final all = measures();

  test('every measure counted something', () {
    // A measure that reads a directory that moved answers 0 forever, and
    // 0 looks like a fact. This is the guard that makes the rest mean
    // anything.
    for (final m in all) {
      expect(m.value, greaterThan(0),
          reason: '"${m.name}" measured 0 from ${m.how} — either the '
              'repository really holds none, or the path moved and this '
              'measure has quietly stopped measuring');
    }
  });

  test('the features measure agrees with the enum itself', () {
    expect(_valueOf(all, 'Toggleable per-workspace features'),
        WorkspaceFeature.values.length,
        reason: 'the scale tool parses the enum as text, because it runs '
            'over a checkout rather than inside the app. When the two '
            'disagree the parse is wrong, not the enum');
  });

  test('the migrations measure agrees with the schema version the app needs',
      () {
    // `requiredSchemaVersion` equals the highest migration by the rule
    // `migration_version_marker_test` enforces, so counting the files is
    // the same answer from the other side — unless a number was skipped.
    expect(_valueOf(all, 'SQL migrations') + _notUsed.length, requiredSchemaVersion,
        reason: 'the migration files and requiredSchemaVersion disagree: '
            'either a number was skipped in supabase/migrations (list it in '
            '_notUsed if it is never used) or the marker was not bumped');
  });

  test('a migration number listed as not used has no file', () {
    final present = {
      for (final f in Directory('supabase/migrations').listSync())
        if (RegExp(r'/(\d{4})_[^/]*\.sql$').firstMatch(f.path) case final m?) int.parse(m.group(1)!),
    };
    expect(_notUsed.intersection(present), isEmpty,
        reason: 'a migration with this number exists now: take it off _notUsed');
  });

  test('the test-files measure is the set the inventory classifies', () {
    expect(_valueOf(all, 'Test files'), testFiles().length,
        reason: 'two tools counting the same tests must count the same '
            'tests, or one of the two documents is lying');
  });

  test('the ARB measure counts keys, not their metadata', () {
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    expect(_valueOf(all, 'ARB translation keys'),
        arb.keys.where((k) => !k.startsWith('@')).length);
    expect(_valueOf(all, 'ARB translation keys'), lessThan(arb.keys.length),
        reason: 'every key has an @-description, so counting both would '
            'roughly double the answer');
  });

  test('the table renders one row per measure', () {
    final rows = render(all)
        .trim()
        .split('\n')
        .where((l) => l.startsWith('|'))
        .length;
    expect(rows, all.length + 2, reason: 'a header and its separator, '
        'then one row each');
  });
}
