// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4423 -- a server name the app calls is spelled once. An RPC, a table or a storage
// bucket quoted in two or more files is a second caller that should go through the
// owning repository, or share one constant in the owning data file. The lists only
// shrink: today's are recorded below, and a name that joins them fails.
//
// (The class where the literal stays: a row mapper names its column.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _rpc = RegExp(r'''\.rpc(?:<[^>(]*>)?\(\s*['"]([A-Za-z0-9_]+)['"]''');
final _bucket = RegExp(r'''\.storage\s*\.from\(\s*['"]([A-Za-z0-9_-]+)['"]''');
final _table = RegExp(r'''(?<!storage)(?<!storage\s)\.from(?:<[^>(]*>)?\(\s*['"]([A-Za-z0-9_]+)['"]''');

/// The names [pattern] finds in [source].
Set<String> namesIn(String source, RegExp pattern) => {
  for (final m in pattern.allMatches(source)) m.group(1)!,
};

/// For each name, the files that quote it: only the names of two or more files.
Map<String, Set<String>> sharedNames(
  Map<String, String> sources,
  RegExp pattern,
) {
  final byName = <String, Set<String>>{};
  for (final MapEntry(key: file, value: source) in sources.entries) {
    for (final name in namesIn(source, pattern)) {
      (byName[name] ??= {}).add(file);
    }
  }
  return {
    for (final e in byName.entries)
      if (e.value.length >= 2) e.key: e.value,
  };
}

/// RATCHET: the RPC, table and bucket names quoted in two or more files of `lib/`. Only falls.
const _sharedRpcBudget = 0;
const _sharedTableBudget = 0;
const _sharedBucketBudget = 0;

Map<String, String> _libSources() => {
  for (final f in handWrittenDartFiles('lib'))
    f.path: f.readAsStringSync(),
};

void main() {
  test('a name is found in a file, and in two files it is shared', () {
    final files = {
      'a.dart': "await db.rpc('book_seat'); db.from('seats');",
      'b.dart': "await db.rpc('book_seat'); db.storage.from('plans');",
      'c.dart': "db.storage.from('plans');",
    };
    expect(sharedNames(files, _rpc).keys, ['book_seat']);
    expect(sharedNames(files, _table).keys, isEmpty);
    expect(sharedNames(files, _bucket).keys, ['plans']);
    expect(namesIn('x.rpc("with_double")', _rpc), {'with_double'});
  });

  test('the RPC, table and bucket names shared by two files only fall', () {
    final sources = _libSources();
    final rpc = sharedNames(sources, _rpc);
    final table = sharedNames(sources, _table);
    final bucket = sharedNames(sources, _bucket);
    stdout.writeln(
      'data names shared: rpc ${rpc.length} table ${table.length} bucket ${bucket.length}',
    );
    expect(
      rpc.length,
      lessThanOrEqualTo(_sharedRpcBudget),
      reason:
          'an RPC called from two files: give it one constant in the owning '
          'data file and call it through the repository: ${rpc.keys.join(', ')}',
    );
    expect(
      table.length,
      lessThanOrEqualTo(_sharedTableBudget),
      reason: 'a table read from two files: ${table.keys.join(', ')}',
    );
    expect(
      bucket.length,
      lessThanOrEqualTo(_sharedBucketBudget),
      reason: 'a bucket named in two files: ${bucket.keys.join(', ')}',
    );
  });
}
