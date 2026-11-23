// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3731 (K4) — the consumer contract is complete, and every new migration
// says what it does to installed apps.
//
// 1. Every server call in lib/ and packages/ names its function or table in
//    a way tool/consumer_contract.dart can read: a string literal, an
//    operation spec (`rpc:` / `relation:`), a helper whose file spells the
//    name, or a `// consumer-contract: name` comment. Otherwise a release
//    would claim less than it calls, and the database job could not prove it.
// 2. The extractor reads what it says it reads (planted sources).
// 3. A migration after [_appsLineFrom] carries `-- apps:` beside its risk
//    line (ADR 0053, section 4); one that says `additive` drops and renames
//    nothing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/consumer_contract.dart';
import '../../tool/consumer_contract/extract.dart';
import 'lint_sources.dart';

/// The first migration that must carry the `-- apps:` line: the ones before
/// it are classified by the consumer-contract check, not by a header.
const int _appsLineFrom = 898;

final _appsLine = RegExp(
  r'^-- apps: (additive|needs app at least \d+|breaks apps below \d+)\s*$',
);
final _dropsOrRenames = RegExp(
  r'\b(drop\s+(table|column|function|view|materialized\s+view|type)|rename\s+(column|to))\b',
  caseSensitive: false,
);

ConsumerContract _of(String source) {
  final c = ConsumerContract();
  extractInto(
    c,
    'planted.dart',
    source,
    server: ServerNames({'helper_fn'}, {'held_table'}),
  );
  return c;
}

void main() {
  test('every server call in the app names what it calls', () {
    final contract = extractTree(Directory.current.path);
    expect(
      contract.unresolved,
      isEmpty,
      reason:
          'name it with a string literal, or put '
          '`// consumer-contract: <name>` on the call or the line above',
    );
    expect(contract.functions, isNotEmpty);
    expect(contract.tables, isNotEmpty);
  });

  test('a release contract exists and is one the check can read', () {
    final files = filesWithExtension('contracts/consumer/releases', '.json');
    expect(files, isNotEmpty);
    for (final f in files) {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      expect(j['format'], 'deskilo.consumer-contract', reason: f.path);
      expect(j['source'], isA<String>(), reason: f.path);
      expect(j['functions'], isA<Map<String, Object?>>(), reason: f.path);
      expect(j['tables'], isA<Map<String, Object?>>(), reason: f.path);
    }
  });

  group('the extractor', () {
    test('reads a literal call with its parameters', () {
      final c = _of(
        '''f(c) => c.rpc<Object?>('fn_a', params: {'p_x': 1, 'p_y': 2});''',
      );
      expect(c.functions['fn_a']!.params, {'p_x', 'p_y'});
      expect(c.functions['fn_a']!.optional, isFalse);
    });

    test('a call that reads a missing function as an answer is optional', () {
      final c = _of('''
f(c) async {
  try { await c.rpc('fn_b'); } on Object catch (e) { if (isMissingFunction(e)) return; }
}''');
      expect(c.functions['fn_b']!.optional, isTrue);
    });

    test('a helper call is attributed through the names its file spells', () {
      final c = _of('''
class R {
  Future<Object?> _call(String fn, Map<String, Object?> p) => c.rpc(fn, params: p);
  save() => _call('helper_fn', {'p_id': 1});
}''');
      expect(c.unresolved, isEmpty);
      expect(c.functions['helper_fn']!.params, {'p_id'});
    });

    test('a name no syntax and no comment shows is unresolved', () {
      final c = _of('''f(c, n) => c.rpc(n);''');
      expect(c.unresolved, ['planted.dart:1']);
    });

    test('a comment names what a variable holds', () {
      final c = _of('''
f(c, n) =>
    // consumer-contract: fn_c, fn_d
    c.rpc(n);''');
      expect(c.unresolved, isEmpty);
      expect(c.functions.keys, containsAll(['fn_c', 'fn_d']));
    });

    test('reads the columns a query selects, filters and writes', () {
      final c = _of('''
f(c) => c.from('t').select('a, label:b, d::text, rel(x, y)').eq('e', 1);
g(c) => c.from('t').insert({'w': 1});
h(c) => c.storage.from('bucket').list();''');
      expect(c.tables['t']!.columns, {'a', 'b', 'd', 'e', 'w'});
      expect(c.tables.containsKey('bucket'), isFalse);
    });

    test('a select of everything claims only the table', () {
      expect(selectColumns('*'), isNull);
      expect(selectColumns('id, rel(*)'), {'id'});
    });
  });

  test('every migration from $_appsLineFrom on says what it does to apps', () {
    final problems = <String>[];
    for (final f in sqlFiles('supabase/migrations')) {
      final name = f.uri.pathSegments.last;
      final n = int.tryParse(name.split('_').first);
      if (n == null || n < _appsLineFrom) continue;
      final lines = f.readAsLinesSync();
      final head = lines.take(8).where(_appsLine.hasMatch).toList();
      if (head.isEmpty) {
        problems.add('$name: no `-- apps:` line in its header');
        continue;
      }
      if (head.first.contains('additive')) {
        final body = lines
            .where((l) => !l.trimLeft().startsWith('--'))
            .where(_dropsOrRenames.hasMatch)
            .toList();
        if (body.isNotEmpty) {
          problems.add(
            '$name: says additive but drops or renames: '
            '${body.first.trim()}',
          );
        }
      }
    }
    expect(
      problems,
      isEmpty,
      reason:
          'ADR 0053 section 4: `-- apps: additive`, '
          '`-- apps: needs app at least N` or `-- apps: breaks apps below N`',
    );
  });
}
