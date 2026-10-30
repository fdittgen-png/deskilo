// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3098 (PERF-1) — a focus change is not a resume. On web every alt-tab
// is `inactive → resumed`; each one resynced every mapped table and
// busted the plan cache. Counted on the demo fakes: a focus change costs
// nothing, a real absence past the workspace's threshold costs exactly
// one resync per target, and a short absence costs nothing.
import 'dart:async';

import 'package:deskilo/app/realtime_invalidations.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/core/realtime/resume_resync.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = Workspace(
  id: 'ws-a',
  name: 'ws-a',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE22',
);

class _Sync implements RealtimeSync {
  @override
  Stream<String> watch(String workspaceId) => StreamController<String>().stream;
  @override
  Stream<String> watchAccount() => StreamController<String>().stream;
}

/// The demo plan repository, counting how often the plan cache is busted.
class _CountingPlans extends FakeFloorPlanRepository {
  int busts = 0;
  @override
  Future<void> invalidateCache() async => busts++;
}

class _Clock implements Clock {
  DateTime instant = DateTime.utc(2026, 10, 30, 9);
  @override
  DateTime now() => instant;
}

/// The sequence a browser tab or a phone runs through when it leaves the
/// screen and comes back after [away].
Future<void> _leaveAndReturn(
  WidgetTester tester,
  _Clock clock,
  Duration away,
) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  clock.instant = clock.instant.add(away);
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 10));
  await tester.pump();
}

void main() {
  late _Clock clock;
  late _CountingPlans plans;
  late ProviderContainer container;

  Future<List<RealtimeInvalidator>> start(WidgetTester tester) async {
    clock = _Clock();
    plans = _CountingPlans();
    container = ProviderContainer(
      overrides: [
        ...realtimeWiringFromApp,
        ...realtimeSyncOverrides(_Sync()),
        floorPlanRepositoryProvider.overrideWithValue(plans),
        currentWorkspaceProvider.overrideWith((ref) async => _ws),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    final notifiers = <RealtimeInvalidator>[];
    for (final target in RealtimeTarget.values) {
      final provider = realtimeInvalidatorProvider(target);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      notifiers.add(container.read(provider.notifier));
    }
    await tester.pump();
    return notifiers;
  }

  testWidgets('5 × inactive → resumed (alt-tab): no resync, no bust', (
    tester,
  ) async {
    final notifiers = await start(tester);
    for (var i = 0; i < 5; i++) {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 10));
    }
    await tester.pump();
    expect([for (final n in notifiers) n.appliedBatches], [0, 0]);
    expect(plans.busts, 0);
  });

  testWidgets('away past the threshold: exactly one resync per target', (
    tester,
  ) async {
    final notifiers = await start(tester);
    final threshold = container.read(resumeResyncAfterProvider);
    await _leaveAndReturn(tester, clock, threshold);
    expect([for (final n in notifiers) n.appliedBatches], [1, 1]);
    // The kiosk asleep overnight (#577) wakes up fresh as well.
    await _leaveAndReturn(tester, clock, const Duration(hours: 10));
    expect([for (final n in notifiers) n.appliedBatches], [2, 2]);
  });

  testWidgets('away for less than the threshold: no resync', (tester) async {
    final notifiers = await start(tester);
    final threshold = container.read(resumeResyncAfterProvider);
    await _leaveAndReturn(
      tester,
      clock,
      threshold - const Duration(seconds: 1),
    );
    expect([for (final n in notifiers) n.appliedBatches], [0, 0]);
    expect(plans.busts, 0);
  });
}
