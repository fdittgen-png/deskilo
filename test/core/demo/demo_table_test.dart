// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4404 -- the two helpers every Demo fake shares: a table of rows that is still a plain list (a test reads and fills it as before)
// and finds, replaces and numbers its rows by id; and the replay of a request id, which answers the first answer again and does not
// run the body a second time.
import 'package:deskilo/core/demo/demo_replay.dart';
import 'package:deskilo/core/demo/demo_table.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Row = ({String? id, String name});

void main() {
  group('DemoTable', () {
    late DemoTable<_Row> table;
    setUp(() => table = DemoTable<_Row>((r) => r.id)..add((id: 'a', name: 'first'))..add((id: 'b', name: 'second')));

    test('is a list: it counts, reads, sorts and is spread like one', () {
      expect(table.length, 2);
      expect(table.first.name, 'first');
      expect([...table].map((r) => r.id), ['a', 'b']);
      table.sort((x, y) => y.name.compareTo(x.name));
      expect(table.first.id, 'b');
    });

    test('finds a row by its id, and says so when there is none', () {
      expect(table.indexOfId('b'), 1);
      expect(table.byId('a')?.name, 'first');
      expect(table.indexOfId('zz'), -1);
      expect(table.byId('zz'), isNull);
      expect(table.indexOfId(null), -1, reason: 'a row that has no id yet is nobody\'s');
    });

    test('upsert puts a row in the place of the one with its id, or adds it', () {
      expect(table.upsert((id: 'a', name: 'changed')), 0);
      expect(table.length, 2);
      expect(table.byId('a')?.name, 'changed');
      expect(table.upsert((id: 'c', name: 'third')), 2);
      expect(table.length, 3);
    });

    test('the next id is one more than the rows held', () {
      expect(table.nextId('supplier'), 'demo-supplier-3');
    });
  });

  group('Replay', () {
    test('the same request id answers the first answer and does not run again', () async {
      final replay = Replay<int>();
      var runs = 0;
      expect(await replay.once('r1', () async => ++runs), 1);
      expect(await replay.once('r1', () async => ++runs), 1);
      expect(runs, 1);
      expect(await replay.once('r2', () async => ++runs), 2);
    });

    test('a synchronous body is kept the same way, and an answer can be kept and seen', () {
      final replay = Replay<String>();
      expect(replay.seen('r1'), isNull);
      expect(replay.onceSync('r1', () => 'first'), 'first');
      expect(replay.onceSync('r1', () => 'second'), 'first');
      expect(replay.keep('r2', 'kept'), 'kept');
      expect(replay.seen('r2'), 'kept');
    });
  });
}
