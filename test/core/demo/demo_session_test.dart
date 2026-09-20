// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1375 — Demo behaves like a real workspace, and Reset puts it back.
//
// The four claims the issue makes, each proved against the real fixture
// rather than a stand-in: a mutation is seen by a later read, a reset
// restores the canonical dataset, a mutation already in flight when the
// reset happened cannot reach the new one, and nothing a Demo session
// does touches a repository outside it.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  DemoSession session() => container.read(demoSessionControllerProvider);
  DemoSessionController controller() =>
      container.read(demoSessionControllerProvider.notifier);

  test('a session starts at generation 0 on the canonical dataset', () {
    expect(session().generation, 0);
    expect(session().fixture.workspaces.workspaces, isNotEmpty);
  });

  test('a mutation is visible to a later read — the same repository serves '
      'both, which is what makes a Demo screen behave like a real one',
      () async {
    final before = await session().fixture.floorPlan.fetchLevels('ws-1');
    await session().fixture.floorPlan.createLevel('ws-1', 'Mezzanine', 9);
    final after = await session().fixture.floorPlan.fetchLevels('ws-1');
    expect(after.length, before.length + 1);
    expect(after.map((l) => l.name), contains('Mezzanine'));
  });

  test('reset restores the canonical dataset and advances the generation',
      () async {
    await session().fixture.floorPlan.createLevel('ws-1', 'Mezzanine', 9);
    final dirty = await session().fixture.floorPlan.fetchLevels('ws-1');

    controller().reset();

    expect(session().generation, 1);
    final fresh = await session().fixture.floorPlan.fetchLevels('ws-1');
    expect(fresh.length, lessThan(dirty.length));
    expect(
      fresh.map((l) => l.name),
      isNot(contains('Mezzanine')),
      reason: 'the added level belonged to the discarded fixture',
    );
  });

  test('a reset keeps the instant the session believes it is, so the '
      'bookings the visitor was looking at come back where they were', () {
    final seededAt = session().fixture.seededAt;
    controller().reset();
    expect(session().fixture.seededAt, seededAt);
  });

  test('the fence is the object graph: a write held from before the reset '
      'lands in the discarded fixture and cannot reach the new one',
      () async {
    // Exactly what an in-flight mutation holds — a reference taken
    // before the reset, used after it.
    final inFlight = session().fixture.floorPlan;
    controller().reset();
    await inFlight.createLevel('ws-1', 'Ghost', 9);

    final fresh = await session().fixture.floorPlan.fetchLevels('ws-1');
    expect(fresh.map((l) => l.name), isNot(contains('Ghost')));
  });

  test('resetting twice is the same as resetting once, and each reset is a '
      'different fixture', () async {
    final first = session().fixture;
    controller().reset();
    final second = session().fixture;
    controller().reset();
    final third = session().fixture;

    expect(identical(first, second), isFalse);
    expect(identical(second, third), isFalse);
    expect(session().generation, 2);
    final plan = await third.floorPlan.fetchLevels('ws-1');
    final canonical = await DemoFixture.build(now: first.seededAt)
        .floorPlan
        .fetchLevels('ws-1');
    expect(plan.length, canonical.length);
  });

  test('a Demo session writes to nothing outside itself — two fixtures '
      'share no repository instance', () async {
    final other = DemoFixture.build(now: session().fixture.seededAt);
    await session().fixture.floorPlan.createLevel('ws-1', 'Only here', 9);
    final elsewhere = await other.floorPlan.fetchLevels('ws-1');
    expect(elsewhere.map((l) => l.name), isNot(contains('Only here')));
  });
}
