// SPDX-License-Identifier: 0BSD
// #1093 — RealtimeInvalidator is keepAlive, so ONE instance is reused
// across rebuilds and `_sub` is a single shared field. Tearing down
// before the `await` means two overlapping builds both cancel the same
// (already-cancelled) subscription, then both assign: the first build's
// channel is left open and unreferenced, still feeding invalidations for
// a workspace the member has left.
import 'dart:async';

import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = Workspace(
  id: 'ws-a',
  name: 'A',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE22',
);
const _b = Workspace(
  id: 'ws-b',
  name: 'B',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE23',
);

/// Counts channels that are open and not yet torn down.
class _CountingSync implements RealtimeSync {
  int opened = 0;
  int closed = 0;
  int get live => opened - closed;

  @override
  Stream<String> watch(String workspaceId) {
    late StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () => opened++,
      onCancel: () => closed++,
    );
    return controller.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('overlapping builds leave exactly one live channel', () async {
    final sync = _CountingSync();
    // The workspace read the invalidator awaits: a completer per build,
    // so the second build can start while the first is still suspended.
    var gate = Completer<Workspace?>();
    final container = ProviderContainer(
      overrides: [
        realtimeSyncProvider.overrideWithValue(sync),
        currentWorkspaceProvider.overrideWith((ref) => gate.future),
      ],
    );
    addTearDown(container.dispose);

    // Build 1 starts and suspends on the await.
    final first = container.read(realtimeInvalidatorProvider.future);
    await Future<void>.delayed(Duration.zero);

    // Build 2 starts before build 1 has resolved.
    final firstGate = gate;
    gate = Completer<Workspace?>();
    container.invalidate(currentWorkspaceProvider);
    container.invalidate(realtimeInvalidatorProvider);
    final second = container.read(realtimeInvalidatorProvider.future);
    await Future<void>.delayed(Duration.zero);

    // Both resolve — the first one last, so its assignment lands last.
    gate.complete(_b);
    firstGate.complete(_a);
    await first;
    await second;
    await Future<void>.delayed(Duration.zero);

    expect(sync.live, 1,
        reason: 'a channel opened by a superseded build must be torn down');
  });
}
