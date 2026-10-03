// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 C — a saved view is a bounded definition, read as untrusted
// input; opening it checks it against what this reader may see now and
// names what it leaves out; the reader's own default wins over the
// team's; a relative period resolves on the day it is opened, a fixed
// one never moves, and a month is bounded by local midnights across a
// DST change.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:flutter_test/flutter_test.dart';

BiSavedView _view(
  String id,
  BiViewScope scope, {
  bool mine = true,
  bool isDefault = false,
  BiViewDefinition? definition = const BiViewDefinition(),
}) => BiSavedView(
  id: id,
  scope: scope,
  name: id,
  definition: definition,
  isDefault: isDefault,
  revision: 1,
  mine: mine,
);

void main() {
  test('a definition round-trips, keeps its cards apart, and refuses what '
      'it does not understand', () {
    const query = BiQueryContext(
      groupBy: 'level',
      cards: ['capacity.seat_utilisation'],
    );
    final d = BiViewDefinition.of(query);
    expect(d.toJson(), {
      'v': 1,
      'query': {'by': 'level'},
      'cards': ['capacity.seat_utilisation'],
    });
    final back = BiViewDefinition.fromJson(d.toJson())!;
    expect(checkView(back, {'capacity.seat_utilisation'}).query, query);
    expect(
      BiViewDefinition.fromJson({'v': 2, 'query': <String, Object?>{}}),
      isNull,
    );
    expect(
      BiViewDefinition.fromJson({
        'v': 1,
        'query': {'by': 3},
      }),
      isNull,
    );
    expect(BiViewDefinition.fromJson({'v': 1, 'cards': 'x'}), isNull);
    expect(
      BiViewDefinition.fromJson({
        'v': 1,
        'cards': [for (var i = 0; i < 21; i++) 'm$i'],
      }),
      isNull,
      reason: 'oversized',
    );
    expect(BiViewDefinition.fromJson('drop table'), isNull);
  });

  test('opening checks against the analyses this reader may see now', () {
    const d = BiViewDefinition(
      query: {'cmp': 'previous'},
      cards: ['capacity.seat_utilisation', 'finance.gone'],
    );
    final partial = checkView(d, {'capacity.seat_utilisation'});
    expect(partial.query!.cards, ['capacity.seat_utilisation']);
    expect(partial.query!.comparison, BiComparison.previousPeriod);
    expect(partial.unavailableCards, ['finance.gone']);
    expect(partial.complete, isFalse);
    expect(
      checkView(d, const {}).query,
      isNull,
      reason: 'with every card gone, nothing else is shown instead',
    );
    expect(checkView(null, const {}).unreadable, isTrue);
    expect(
      checkView(
        const BiViewDefinition(query: {'by': 'member'}),
        const {},
      ).query,
      isNull,
    );
  });

  test('my own default wins over the team default; none means standard', () {
    final team = _view('team', BiViewScope.workspace, isDefault: true);
    final mine = _view('mine', BiViewScope.private, isDefault: true);
    expect(defaultView([team, mine])!.id, 'mine');
    expect(defaultView([team, _view('mine', BiViewScope.private)])!.id, 'team');
    expect(
      defaultView([
        _view('theirs', BiViewScope.private, mine: false, isDefault: true),
      ]),
      isNull,
    );
    expect(defaultView(const []), isNull);
  });

  test(
    'a relative view resolves on the day it opens; a fixed one does not',
    () {
      final last = checkView(
        const BiViewDefinition(query: {'at': '-1'}),
        const {},
      ).query!;
      expect(last.current(DateTime(2026, 3, 31)).wire, '2026-02');
      expect(last.current(DateTime(2026, 4, 1)).wire, '2026-03');
      final fixed = checkView(
        const BiViewDefinition(query: {'at': '2026-02'}),
        const {},
      ).query!;
      expect(fixed.current(DateTime(2026, 4, 1)).wire, '2026-02');
    },
  );

  test('a month across the DST change runs from local midnight to local '
      'midnight', () {
    WorkspaceTime.install('Europe/Paris');
    addTearDown(WorkspaceTime.reset);
    final march = biInterval(const BiPeriod(BiGrain.month, 2026, 3));
    expect(march.from.toUtc(), DateTime.utc(2026, 2, 28, 23));
    expect(march.to.toUtc(), DateTime.utc(2026, 3, 31, 22));
    final q4 = biInterval(const BiPeriod(BiGrain.quarter, 2026, 4));
    expect(q4.from.toUtc(), DateTime.utc(2026, 9, 30, 22));
    expect(q4.to.toUtc(), DateTime.utc(2026, 12, 31, 23));
  });

  test('the in-memory store refuses like the server: a stale revision, a '
      'taken name, a team view without the right', () async {
    final repo = InMemoryBiViewRepository(canManage: false);
    const d = BiViewDefinition();
    final v = await repo.save(
      'ws',
      scope: BiViewScope.private,
      name: 'A',
      definition: d,
      expectedRevision: 0,
    );
    await repo.save(
      'ws',
      id: v.id,
      scope: BiViewScope.private,
      name: 'A2',
      definition: d,
      expectedRevision: 1,
    );
    await expectLater(
      repo.save(
        'ws',
        id: v.id,
        scope: BiViewScope.private,
        name: 'lost update',
        definition: d,
        expectedRevision: 1,
      ),
      throwsA(
        isA<BiViewRefused>().having((e) => e.failure, 'f', BiViewFailure.stale),
      ),
    );
    await expectLater(
      repo.save(
        'ws',
        scope: BiViewScope.private,
        name: 'a2',
        definition: d,
        expectedRevision: 0,
      ),
      throwsA(
        isA<BiViewRefused>().having(
          (e) => e.failure,
          'f',
          BiViewFailure.nameTaken,
        ),
      ),
    );
    await expectLater(
      repo.save(
        'ws',
        scope: BiViewScope.workspace,
        name: 'Team',
        definition: d,
        expectedRevision: 0,
      ),
      throwsA(
        isA<BiViewRefused>().having(
          (e) => e.failure,
          'f',
          BiViewFailure.forbidden,
        ),
      ),
    );
  });
}
