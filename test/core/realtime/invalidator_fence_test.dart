// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2019 — a change batch belongs to the workspace it was collected for.
// Workspace A's batch is stuck in the plan-cache bust when the member
// switches to B: when the bust finishes, A's batch must invalidate
// nothing (B's build owns the providers now). Signals still pending at a
// switch are dropped with the old channel, and one burst invalidates each
// provider once.
import 'dart:async';

import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace _ws(String id) => Workspace(
  id: id,
  name: id,
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE22',
);

class _Sync implements RealtimeSync {
  final channels = <String, StreamController<String>>{};
  @override
  Stream<String> watch(String workspaceId) =>
      (channels[workspaceId] = StreamController<String>()).stream;
}

/// A plan repository whose cache bust waits for the test.
class _SlowBust extends FakeFloorPlanRepository {
  Completer<void>? gate;
  @override
  Future<void> invalidateCache() => gate?.future ?? Future.value();
}

void main() {
  testWidgets('a batch collected for A invalidates nothing once B owns '
      'the providers', (tester) async {
    final sync = _Sync();
    final plans = _SlowBust()..gate = Completer<void>();
    var current = _ws('ws-a');
    final container = ProviderContainer(
      overrides: [
        realtimeSyncProvider.overrideWithValue(sync),
        floorPlanRepositoryProvider.overrideWithValue(plans),
        currentWorkspaceProvider.overrideWith((ref) async => current),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(realtimeInvalidatorProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.pump();
    final notifier = container.read(realtimeInvalidatorProvider.notifier);

    sync.channels['ws-a']!.add('seat_accessories');
    await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 10));
    // A's batch is now awaiting the bust. The member switches to B.
    current = _ws('ws-b');
    container.invalidate(currentWorkspaceProvider);
    await container.read(realtimeInvalidatorProvider.future);
    await tester.pump();
    expect(sync.channels.containsKey('ws-b'), isTrue,
        reason: 'B owns the channel now');
    plans.gate!.complete();
    await tester.pump();
    expect(
      notifier.appliedBatches,
      0,
      reason: "A's batch must not invalidate B's providers",
    );

    // B's own changes still apply.
    plans.gate = null;
    sync.channels['ws-b']!.add('seat_accessories');
    await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 10));
    await tester.pump();
    expect(notifier.appliedBatches, 1);
  });

  testWidgets('signals pending at a switch are dropped with the old channel', (
    tester,
  ) async {
    final sync = _Sync();
    var current = _ws('ws-a');
    final container = ProviderContainer(
      overrides: [
        realtimeSyncProvider.overrideWithValue(sync),
        floorPlanRepositoryProvider.overrideWithValue(_SlowBust()),
        currentWorkspaceProvider.overrideWith((ref) async => current),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(realtimeInvalidatorProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.pump();
    final notifier = container.read(realtimeInvalidatorProvider.notifier);

    sync.channels['ws-a']!.add('reservations');
    // Switch BEFORE the debounce fires.
    current = _ws('ws-b');
    container.invalidate(currentWorkspaceProvider);
    await container.read(realtimeInvalidatorProvider.future);
    await tester.pump(kRealtimeDebounce * 2);
    expect(notifier.appliedBatches, 0);
  });
}
