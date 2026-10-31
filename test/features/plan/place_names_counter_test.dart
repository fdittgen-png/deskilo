// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3100 (PERF-3) — place names do not change when someone books. A
// `reservations` signal used to re-read every seat, desk and office name
// (three selects) and level, while a rename (`seats`) left the names
// stale. Counted on the demo plan repository.
import 'dart:async';

import 'package:deskilo/app/realtime_invalidations.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
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
  final feed = StreamController<String>();
  @override
  Stream<String> watch(String workspaceId) => feed.stream;
  @override
  Stream<String> watchAccount() => const Stream.empty();
}

class _CountingPlans extends FakeFloorPlanRepository {
  int names = 0;
  int levelReads = 0;

  @override
  Future<Map<String, String>> fetchTargetNames(String workspaceId) {
    names++;
    return super.fetchTargetNames(workspaceId);
  }

  @override
  Future<Map<String, String>> fetchTargetLevels(String workspaceId) {
    levelReads++;
    return super.fetchTargetLevels(workspaceId);
  }
}

void main() {
  late _Sync sync;
  late _CountingPlans plans;

  Future<void> start(WidgetTester tester) async {
    sync = _Sync();
    plans = _CountingPlans();
    final container = ProviderContainer(
      overrides: [
        ...realtimeWiringFromApp,
        ...realtimeSyncOverrides(sync),
        floorPlanRepositoryProvider.overrideWithValue(plans),
        currentWorkspaceProvider.overrideWith((ref) async => _ws),
      ],
    );
    addTearDown(container.dispose);
    final subs = [
      container.listen(
        realtimeInvalidatorProvider(RealtimeTarget.workspace),
        (_, _) {},
      ),
      container.listen(targetNamesProvider, (_, _) {}),
      container.listen(targetLevelsProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });
    await container.read(
      realtimeInvalidatorProvider(RealtimeTarget.workspace).future,
    );
    await container.read(targetNamesProvider.future);
    await container.read(targetLevelsProvider.future);
    await tester.pump();
    plans
      ..names = 0
      ..levelReads = 0;
  }

  Future<void> signal(WidgetTester tester, String table) async {
    sync.feed.add(table);
    await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 10));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a booking re-reads no place name and no level', (tester) async {
    await start(tester);
    await signal(tester, 'reservations');
    expect(plans.names, 0);
    expect(plans.levelReads, 0);
  });

  testWidgets('renaming a seat refreshes the names', (tester) async {
    await start(tester);
    await signal(tester, 'seats');
    expect(plans.names, 1);
  });
}
