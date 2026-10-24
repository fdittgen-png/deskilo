// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C2 — the tap inbox: a launch tap waits for the router; each tap is
// handed on once, so a resume or a second delivery never opens twice.
import 'package:deskilo/core/notifications/notification_taps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tap = NotificationTap(id: 'push:m-1', data: {'kind': 'member_note'});

  test('a tap before anyone listens waits, then is handed on once', () {
    final taps = NotificationTaps()..add(tap);
    final received = <NotificationTap>[];
    taps.listen(received.add);
    expect(received.map((t) => t.id), ['push:m-1']);

    taps.add(tap); // the same tap again: a resume, a second delivery
    expect(received, hasLength(1));

    taps.add(const NotificationTap(id: 'push:m-2', data: {}));
    expect(received.map((t) => t.id), ['push:m-1', 'push:m-2']);
  });

  test('after cancel, taps wait for the next listener', () {
    final taps = NotificationTaps();
    final first = <NotificationTap>[];
    taps
      ..listen(first.add)
      ..cancel()
      ..add(tap);
    expect(first, isEmpty);
    final second = <NotificationTap>[];
    taps.listen(second.add);
    expect(second.single.id, 'push:m-1');
  });

  test('a local payload decodes to its flat string map, or to nothing', () {
    expect(NotificationTap.decodePayload('{"v":"1","ws":"w","n":2}'),
        {'v': '1', 'ws': 'w'});
    expect(NotificationTap.decodePayload(null), isNull);
    expect(NotificationTap.decodePayload(''), isNull);
    expect(NotificationTap.decodePayload('not json'), isNull);
    expect(NotificationTap.decodePayload('[1,2]'), isNull);
  });
}
