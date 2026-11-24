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
import '../../tool/migration_apps.dart';
import 'lint_sources.dart';

/// The first migration that must carry the `-- apps:` line: the ones before
/// it are classified by the consumer-contract check, not by a header.
const int _appsLineFrom = 898;


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
      expect(
        j.containsKey('unresolved'),
        isFalse,
        reason:
            '${f.path}: every call of the release must be named, '
            'by hand under "declared" when its tag cannot show it',
      );
    }
  });

  group('the extractor', () {
    test('reads a literal call with its parameters', () {
      final c = _of(
        '''f(c) => c.rpc<Object?>('fn_a', params: {'p_x': 1, 'p_y': 2});''',
      );
      expect(c.functions['fn_a']!.callSets, {'p_x,p_y'});
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

    test('each call site keeps its own parameter set', () {
      final c = _of('''
a(c) => c.rpc('fn_e', params: {'p_x': 1});
b(c) => c.rpc('fn_e', params: {'p_x': 1, 'p_y': 2});
d(c) => c.rpc('fn_e');''');
      expect(c.functions['fn_e']!.callSets, {'p_x', 'p_x,p_y', ''});
    });

    test('a select over adjacent strings, a star and an upsert key', () {
      final c = _of('''
f(c) => c.from('t').select('a, b, '
    'c').eq('d', 1);
g(c) => c.from('t').select();
h(c) => c.from('t').upsert({'e': 1}, onConflict: 'k1, k2');''');
      expect(c.tables['t']!.columns, {'a', 'b', 'c', 'd', 'e', 'k1', 'k2'});
    });

    test('a select of everything claims only the table', () {
      expect(selectColumns('*'), isNull);
      expect(selectColumns('id, rel(*)'), {'id'});
    });
  });

  test('every migration from $_appsLineFrom on says what it does to apps', () {
    final problems = <String>[];
    final earlier = <String, List<Map<String, bool>>>{};
    for (final f in sqlFiles('supabase/migrations')) {
      final name = f.uri.pathSegments.last;
      final n = int.tryParse(name.split('_').first);
      final sql = f.readAsStringSync();
      if (n != null && n >= _appsLineFrom) {
        problems.addAll(appsFindings(name, sql, earlier: earlier));
      }
      rememberFunctions(earlier, sql);
    }
    expect(
      problems,
      isEmpty,
      reason:
          'ADR 0053 section 4: `-- apps: additive`, '
          '`-- apps: needs app at least N` or `-- apps: breaks apps below N`',
    );
  });

  group('the apps line scanner', () {
    const head = '-- SPDX\n-- risk: additive\n';
    List<String> run(String line, String body, [String earlierSql = '']) {
      final earlier = <String, List<Map<String, bool>>>{};
      rememberFunctions(earlier, earlierSql);
      return appsFindings(
        '0999_x.sql',
        '$head$line\n$body',
        earlier: earlier,
      );
    }

    const old = 'create function public.fn_a(p_x int) returns int as \$\$ select 1 \$\$ language sql;';

    test('a file without the line is named', () {
      expect(appsFindings('0999_x.sql', '-- risk: additive\nselect 1;'), hasLength(1));
    });

    test('additive passes a new function and a defaulted new parameter', () {
      expect(run('-- apps: additive', 'create table t(a int);'), isEmpty);
      expect(
        run(
          '-- apps: additive',
          'create or replace function public.fn_a(p_x int, p_y int default 0) returns int as \$\$ select 1 \$\$ language sql;',
          old,
        ),
        isEmpty,
      );
    });

    test('additive that drops a table, column or function fails', () {
      for (final d in [
        'drop table t;',
        'alter table t drop column c;',
        'drop function public.fn_a(int);',
        'alter table t rename column a to b;',
      ]) {
        expect(run('-- apps: additive', d), hasLength(1), reason: d);
      }
      expect(run('-- apps: breaks apps below 5', 'drop table t;'), hasLength(1),
          reason: 'breaks needs the floor');
    });

    test('additive that drops a parameter or adds one without default fails', () {
      final dropped = run(
        '-- apps: additive',
        'create or replace function public.fn_a() returns int as \$\$ select 1 \$\$ language sql;',
        old,
      );
      expect(dropped.single, contains('fn_a'));
      final added = run(
        '-- apps: additive',
        'create or replace function public.fn_a(p_x int, p_y int) returns int as \$\$ select 1 \$\$ language sql;',
        old,
      );
      expect(added.single, contains('fn_a(p_x, p_y)'));
    });

    test('a comment that mentions drop table does not count', () {
      expect(run('-- apps: additive', '-- drop table t;\nselect 1;'), isEmpty);
    });

    test('breaks below N must raise the floor to N in the same file', () {
      expect(run('-- apps: breaks apps below 5', 'select 1;').single,
          contains('deskilo_app_floor'));
      const raise =
          'create or replace function public.deskilo_app_floor() returns int language sql as \$\$ select 5::int; \$\$;';
      expect(run('-- apps: breaks apps below 5', raise), isEmpty);
      expect(run('-- apps: breaks apps below 6', raise), hasLength(1));
    });

    test('needs app at least N asks nothing of the floor', () {
      expect(run('-- apps: needs app at least 3', 'select 1;'), isEmpty);
    });
  });
}
