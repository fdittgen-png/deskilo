// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C2 — XNOTIF / XPRIV-SPLIT at the opener: a tap for W-A while W-B is
// open selects W-A and opens the kind's screen there; a tap for a workspace
// of another account, of an unknown host or while signed out opens the
// neutral landing and selects nothing. A connected workspace is selected by
// its own verification, never by the opener.
import 'package:deskilo/app/notification_tap_routing.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/core/push/notification_reference.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _tap(String installation, String workspace,
        {String kind = 'pending_request'}) =>
    {
      'v': '1',
      'kind': kind,
      'src': 'w',
      'inst': installation,
      'ws': workspace,
      'ref_kind': 'event',
      'ref_id': 'ev-1',
    };

class _Harness {
  _Harness({
    this.signedIn = true,
    this.mine = const {'ws-a', 'ws-b'},
    this.connected = const {},
  });

  final bool signedIn;
  final Set<String> mine;
  final Map<String, String> connected;
  final selected = <String>[];
  final went = <String>[];

  late final opener = NotificationTapOpener(
    facts: () async => signedIn
        ? TapFacts(
            homeInstallationId: 'inst-home',
            homeWorkspaceIds: () async => mine,
            connectedSourceOf: (id) async => connected[id],
            verifyConnected: (_, _) async => true,
          )
        : null,
    selectLocal: selected.add,
    go: went.add,
  );
}

void main() {
  test('W-A tapped while W-B is open: W-A is selected, its screen opens',
      () async {
    final h = _Harness();
    final d = await h.opener.open(_tap('inst-home', 'ws-a'));
    expect(d, isA<OpenInWorkspace>());
    expect(h.selected, ['ws-a']);
    expect(h.went, ['/pending']);
  });

  test('another account\'s workspace: neutral landing, nothing selected',
      () async {
    final h = _Harness(mine: {'ws-b'});
    await h.opener.open(_tap('inst-home', 'ws-a'));
    expect(h.selected, isEmpty);
    expect(h.went, [kMeHome]);
  });

  test('signed out: neutral landing, nothing selected', () async {
    final h = _Harness(signedIn: false);
    await h.opener.open(_tap('inst-home', 'ws-a'));
    expect(h.selected, isEmpty);
    expect(h.went, [kMeHome]);
  });

  test('the same workspace id from another host is not this one', () async {
    final h = _Harness();
    await h.opener.open(_tap('inst-elsewhere', 'ws-a'));
    expect(h.selected, isEmpty);
    expect(h.went, [kMeHome]);
  });

  test('a connected host\'s workspace opens without a local selection',
      () async {
    final h = _Harness(connected: {'inst-c': 'https://c.example'});
    await h.opener.open(_tap('inst-c', 'ws-c', kind: 'member_mention'));
    expect(h.selected, isEmpty);
    expect(h.went, ['/messages']);
  });

  test('a malformed tap lands neutrally', () async {
    final h = _Harness();
    await h.opener.open(const {'kind': 'member_note'});
    expect(h.selected, isEmpty);
    expect(h.went, [kMeHome]);
  });
}
