// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3031 — the instance installer hands each migration to psql as one
// argument of at most `maxSqlBytes`. 0589 was 150 KB as first written and
// failed "Install, resume and upgrade" only in CI. Every migration stays
// under that limit, and every migration from 0589 on keeps a margin below
// it, so a restated function or a registry line does not tip it over.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance_lifecycle/psql_management.dart';

/// The first migration written under the margin rule (AGENT_RULES "Decide,
/// commit, never park"); older files predate it and only keep the hard limit.
const int marginFrom = 589;

/// Bytes a new migration may hold: the installer's limit minus room for the
/// next restatement.
const int marginBytes = 110000;

final _fileName = RegExp(r'^(\d{4})_[a-z0-9_]+\.sql$');

void main() {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => _fileName.hasMatch(f.uri.pathSegments.last))
      .toList();

  test('the migrations are found', () {
    expect(files.length, greaterThan(marginFrom));
  });

  test('every migration fits the installer argument limit', () {
    final over = [
      for (final f in files)
        if (f.lengthSync() > maxSqlBytes)
          '${f.uri.pathSegments.last}: ${f.lengthSync()}',
    ];
    expect(over, isEmpty, reason: 'split it into two migrations');
  });

  test('every migration from $marginFrom on keeps the margin', () {
    final over = [
      for (final f in files)
        if (int.parse(
                  _fileName.firstMatch(f.uri.pathSegments.last)!.group(1)!,
                ) >=
                marginFrom &&
            f.lengthSync() >= marginBytes)
          '${f.uri.pathSegments.last}: ${f.lengthSync()}',
    ];
    expect(over, isEmpty, reason: 'split it into two migrations');
  });
}
