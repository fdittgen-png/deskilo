// SPDX-License-Identifier: AGPL-3.0-or-later
//
// tool/contract_predict.dart — a migration that defines its routines WHOLE
// can carry its contract digest on the first push; an anchored patch is
// refused (its digest still comes from the CI artifact). The splice
// reproduces the committed contract byte for byte, so it can only change
// the entries the migration owns.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract_predict/predict.dart';

void main() {
  final contract = File('assets/instance/contract.txt').readAsStringSync();
  String migration(String prefix) =>
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .firstWhere((f) => f.uri.pathSegments.last.startsWith(prefix))
          .readAsStringSync();

  test('a whole-function migration is fully predictable', () {
    final s = scan(migration('0330_'));
    expect(s.routines, {'open_payment_intent'});
    expect(s.unsafe, isEmpty);
    expect(scan(migration('0332_')).routines, {'plan_media_orphans'});
  });

  test('an anchored patch is refused, a commented name is not code', () {
    final s = scan('''
-- create or replace function public.ghost(
do \$\$ begin
  select pg_get_functiondef(p.oid) into v from pg_proc p where proname = 'calendar_items';
end \$\$;
create or replace function public.fresh(p int) returns int language sql as \$f\$ select p \$f\$;
''');
    expect(s.routines, {'fresh'});
    expect(s.unsafe, ['routine calendar_items is patched by anchor']);
  });

  test('a new constraint on an existing table is refused; a new table is '
      'owned with its constraints and triggers', () {
    final s = scan('''
create table public.things (id uuid primary key);
alter table public.things add constraint things_x check (true);
alter table public.reservations add constraint r_y check (true);
''');
    expect(s.tables, {'things'});
    expect(s.unsafe, ['constraints of existing table reservations change']);
  });

  test('the query is the contract query, narrowed to the owned entries', () {
    final sql = predictionSql(
      File('scripts/contract_check.sh').readAsStringSync(),
      scan(migration('0330_')),
    );
    expect(sql, contains('json_agg(line order by line collate "C")'));
    expect(sql, contains("'routine public.open_payment_intent(%'"));
    expect(sql, contains('body:'));
  });

  test('splicing the entries already there reproduces the contract', () {
    final scope = scan(migration('0330_'));
    final mine = [
      for (final l in contract.split('\n'))
        if (l.startsWith('routine public.open_payment_intent(')) l,
    ];
    expect(mine, hasLength(1));
    expect(splice(contract, scope, mine), contract);
    // Dropped from the file and spliced back: the same file again.
    final without = contract.replaceFirst('${mine.single}\n', '');
    expect(splice(without, scope, mine), contract);
  });

  test('multi-line constraint entries keep their place', () {
    final scope = MigrationScope({'zzz_new'}, {}, []);
    final out = splice(contract, scope, ['routine public.zzz_new() -> void']);
    expect(
      out.replaceFirst('routine public.zzz_new() -> void\n', ''),
      contract,
    );
  });

  test('the pasted MCP row and a bare array both parse', () {
    expect(parseEntries('[{"lines": ["a", "b"]}]'), ['a', 'b']);
    expect(parseEntries('["a"]'), ['a']);
    expect(parseEntries('[{"lines": null}]'), isEmpty);
  });
}
