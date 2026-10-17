// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2564 O5 -- one invalidator per target. A workspace channel's events
// refresh only workspace-scoped providers, the account feed's only
// account-scoped ones, and a late event of workspace A never reaches B.
import 'dart:async';

import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:deskilo/core/realtime/invalidation_registry.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/core/realtime/realtime_wiring.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

var _workspaceBuilds = 0;
var _accountBuilds = 0;
final _workspaceProbe = Provider<int>((ref) => ++_workspaceBuilds);
final _accountProbe = Provider<int>((ref) => ++_accountBuilds);

final _registry = InvalidationRegistry([
  InvalidationContribution(const ['t'], [_workspaceProbe]),
  InvalidationContribution(const [
    't',
  ], [_accountProbe], scope: InvalidationScope.account),
]);

class _Sync implements RealtimeSync {
  final workspaceChannels = <String, StreamController<String>>{};
  final account = StreamController<String>();

  @override
  Stream<String> watch(String workspaceId) =>
      (workspaceChannels[workspaceId] = StreamController<String>()).stream;

  @override
  Stream<String> watchAccount() => account.stream;
}

void main() {
  late _Sync sync;
  late String current;
  late ProviderContainer container;

  setUp(() {
    _workspaceBuilds = 0;
    _accountBuilds = 0;
    sync = _Sync();
    current = 'ws-a';
    container = ProviderContainer(
      overrides: [
        invalidationLookupProvider.overrideWithValue(
          (table, {scopes}) => scopes == null
              ? _registry.lookup(table)
              : _registry.lookup(table, scopes: scopes),
        ),
        realtimeWorkspaceIdProvider.overrideWith((ref) async => current),
        realtimeSyncProvider.overrideWithValue(sync),
        accountRealtimeSyncProvider.overrideWithValue(sync),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> arm(WidgetTester tester) async {
    for (final target in RealtimeTarget.values) {
      container.listen(realtimeInvalidatorProvider(target), (_, _) {});
    }
    await tester.pump();
    // Materialise the providers the events must (not) refresh.
    container
      ..read(_workspaceProbe)
      ..read(_accountProbe);
    expect([_workspaceBuilds, _accountBuilds], [1, 1]);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 10));
    await tester.pump();
    container
      ..read(_workspaceProbe)
      ..read(_accountProbe);
  }

  testWidgets('a workspace channel event refreshes workspace providers only', (
    tester,
  ) async {
    await arm(tester);
    sync.workspaceChannels['ws-a']!.add('t');
    await settle(tester);
    expect([_workspaceBuilds, _accountBuilds], [2, 1]);
  });

  testWidgets('the account feed refreshes account providers only', (
    tester,
  ) async {
    await arm(tester);
    sync.account.add('t');
    await settle(tester);
    expect([_workspaceBuilds, _accountBuilds], [1, 2]);
  });

  testWidgets('a resync signal on one target leaves the other alone', (
    tester,
  ) async {
    await arm(tester);
    sync.account.add(kResyncSignal);
    await settle(tester);
    // The sweep covers mappedTables; the probes' table is not among them,
    // so nothing is refreshed and nothing throws.
    expect([_workspaceBuilds, _accountBuilds], [1, 1]);
  });

  testWidgets('a late event of workspace A never refreshes workspace B', (
    tester,
  ) async {
    await arm(tester);
    final a = sync.workspaceChannels['ws-a']!;
    current = 'ws-b';
    container.invalidate(realtimeWorkspaceIdProvider);
    await container.read(
      realtimeInvalidatorProvider(RealtimeTarget.workspace).future,
    );
    await tester.pump();
    expect(sync.workspaceChannels.containsKey('ws-b'), isTrue);
    expect(a.hasListener, isFalse, reason: "A's channel is torn down");

    // A's late event goes nowhere.
    a.add('t');
    await settle(tester);
    expect([_workspaceBuilds, _accountBuilds], [1, 1]);

    // B's own events still apply (recovery).
    sync.workspaceChannels['ws-b']!.add('t');
    await settle(tester);
    expect([_workspaceBuilds, _accountBuilds], [2, 1]);
  });
}
