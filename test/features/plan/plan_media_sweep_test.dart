// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2012 B — the cleanup removes exactly what the server named, does
// nothing when nothing is named, and never fails the write it follows:
// a failed list or a failed removal is deferred to the next sweep.
import 'package:deskilo/features/plan/data/plan_media_sweep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes exactly the named objects', () async {
    final removed = <List<String>>[];
    final n = await sweepPlanMediaOrphans(
      list: () async => ['ws/img/a', 'ws/l1'],
      remove: (p) async => removed.add(p),
    );
    expect(n, 2);
    expect(removed, [
      ['ws/img/a', 'ws/l1'],
    ]);
  });

  test('nothing named: no removal call', () async {
    var calls = 0;
    expect(
      await sweepPlanMediaOrphans(
        list: () async => [],
        remove: (_) async => calls++,
      ),
      0,
    );
    expect(calls, 0);
  });

  test('a failed list or removal is deferred, never thrown', () async {
    expect(
      await sweepPlanMediaOrphans(
        list: () async => throw Exception('rpc down'),
        remove: (_) async {},
      ),
      0,
    );
    expect(
      await sweepPlanMediaOrphans(
        list: () async => ['ws/img/a'],
        remove: (_) async => throw Exception('storage down'),
      ),
      0,
    );
  });
}
