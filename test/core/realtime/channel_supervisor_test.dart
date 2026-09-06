// SPDX-License-Identifier: 0BSD
//
// #961 — the realtime reconnect policy, driven through the exact
// re-entrant sequence a pilot device recorded with its network down:
// removing a channel unsubscribes it, unsubscribing fires `closed` on the
// same channel, and the old callback removed it again — 140 000 frames
// deep. A channel is now handled at most once.

import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<String> trace;
  late List<String> removed;
  late int resyncs;
  late int created;
  late ChannelSupervisor<String> supervisor;

  /// A dead socket: removing a channel closes it synchronously, from
  /// inside the removal, exactly as realtime_client's push timeout does.
  void deadSocketRemove(String channel) {
    removed.add(channel);
    supervisor.onStatus(channel, RealtimeSubscribeStatus.closed);
  }

  setUp(() {
    trace = [];
    removed = [];
    resyncs = 0;
    created = 0;
    supervisor = ChannelSupervisor<String>(
      create: () => 'ch-${++created}',
      subscribe: (_) {},
      remove: deadSocketRemove,
      trace: trace.add,
      onResync: () => resyncs++,
      delayFor: (_) => Duration.zero,
    );
  });

  tearDown(() => supervisor.dispose());

  test('a closed channel is torn down ONCE and one reconnect is scheduled '
      '— the teardown that re-enters with `closed` is ignored', () async {
    supervisor.start();
    expect(supervisor.current, 'ch-1');

    supervisor.onStatus('ch-1', RealtimeSubscribeStatus.closed);
    expect(supervisor.current, isNull, reason: 'forgotten before teardown');
    await Future<void>.delayed(Duration.zero); // microtask + zero timer

    expect(removed, ['ch-1'], reason: 'removed exactly once, no recursion');
    expect(supervisor.attempt, 1, reason: 'ONE reconnect counted, not two');
    expect(created, 2, reason: 'the reconnect opened a fresh channel');
    expect(supervisor.current, 'ch-2');
  });

  test('a stale channel reporting late changes nothing', () async {
    supervisor.start();
    supervisor.onStatus('ch-1', RealtimeSubscribeStatus.channelError, 'x');
    await Future<void>.delayed(Duration.zero);
    expect(supervisor.current, 'ch-2');

    supervisor.onStatus('ch-1', RealtimeSubscribeStatus.closed);
    supervisor.onStatus('ch-1', RealtimeSubscribeStatus.subscribed);
    await Future<void>.delayed(Duration.zero);
    expect(supervisor.current, 'ch-2', reason: 'ch-1 is history');
    expect(supervisor.attempt, 1);
    expect(created, 2);
  });

  test('a re-join after an outage asks for one resync; the first join '
      'does not', () async {
    supervisor.start();
    supervisor.onStatus('ch-1', RealtimeSubscribeStatus.subscribed);
    expect(resyncs, 0);
    expect(supervisor.everJoined, isTrue);

    supervisor.onStatus('ch-1', RealtimeSubscribeStatus.timedOut);
    await Future<void>.delayed(Duration.zero);
    supervisor.onStatus('ch-2', RealtimeSubscribeStatus.subscribed);
    expect(resyncs, 1);
    expect(supervisor.attempt, 0, reason: 'a join resets the back-off');
  });

  test('the back-off grows with consecutive failures and is traced',
      () async {
    final delays = <int>[];
    supervisor = ChannelSupervisor<String>(
      create: () => 'ch-${++created}',
      subscribe: (_) {},
      remove: deadSocketRemove,
      trace: trace.add,
      onResync: () => resyncs++,
      delayFor: (attempt) {
        delays.add(attempt);
        return Duration.zero;
      },
    );
    supervisor.start();
    for (var i = 1; i <= 3; i++) {
      supervisor.onStatus('ch-$i', RealtimeSubscribeStatus.closed);
      await Future<void>.delayed(Duration.zero);
    }
    expect(delays, [0, 1, 2]);
    expect(trace.where((m) => m.startsWith('reconnecting')).length, 3);
    expect(reconnectDelay(0).inSeconds, 2);
    expect(reconnectDelay(10).inSeconds, 30);
  });

  test('dispose removes the live channel and stops the reconnects',
      () async {
    supervisor.start();
    supervisor.onStatus('ch-1', RealtimeSubscribeStatus.closed);
    supervisor.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(created, 1, reason: 'the pending reconnect was cancelled');
    supervisor.start();
    expect(created, 1, reason: 'a disposed supervisor never reopens');
  });
}
