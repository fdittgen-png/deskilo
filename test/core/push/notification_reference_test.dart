// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C2 — a notification's data is a claim, never an authority. Only a
// complete version-1 reference is read; it opens its record only on a
// workspace of the signed-in account (on the installation it names);
// everything else is the neutral landing.
import 'package:deskilo/core/push/notification_reference.dart';
import 'package:flutter_test/flutter_test.dart';

const _data = {
  'v': '1',
  'kind': 'pending_request',
  'src': 'w',
  'inst': 'inst-a',
  'ws': 'ws-1',
  'ref_kind': 'event',
  'ref_id': 'ev-1',
};

TapFacts _facts({
  String home = 'inst-a',
  Set<String> workspaces = const {'ws-1'},
  Map<String, String> connected = const {},
  bool Function(String source, String workspaceId)? verify,
}) =>
    TapFacts(
      homeInstallationId: home,
      homeWorkspaceIds: () async => workspaces,
      connectedSourceOf: (id) async => connected[id],
      verifyConnected: (source, ws) async =>
          verify?.call(source, ws) ?? (throw StateError('session expired')),
    );

void main() {
  group('parse', () {
    test('a complete reference round-trips through its wire form', () {
      final reference = NotificationReference.parse(_data)!;
      expect(reference.toData(), _data);
      expect(reference.objectKind, NotificationObjectKind.event);
    });

    for (final (name, change) in <(String, Map<String, Object?>)>[
      ('another version', {'v': '2'}),
      ('a personal source', {'src': 'p'}),
      ('no installation', {'inst': null}),
      ('an empty workspace', {'ws': ''}),
      ('an unknown record kind', {'ref_kind': 'invoice'}),
      ('an id that is a URL', {'ref_id': 'https://evil.example/x'}),
      ('an id with a space', {'ws': 'ws 1'}),
      ('a kind that is not a word', {'kind': 'Pending Request!'}),
    ]) {
      test('$name is not a reference', () {
        expect(NotificationReference.parse({..._data, ...change}), isNull);
      });
    }

    test('extra keys are ignored, never read', () {
      final reference = NotificationReference.parse(
          {..._data, 'body': 'SENTINEL-MESSAGE-BODY', 'token': 'secret'})!;
      expect(reference.toData(), _data);
      expect(reference.toString(), isNot(contains('ev-1')));
    });

    test('the dedup key names the source: equal local ids on two '
        'installations are two records', () {
      final a = NotificationReference.parse(_data)!;
      final b = NotificationReference.parse({..._data, 'inst': 'inst-b'})!;
      expect(a.objectId, b.objectId);
      expect(a.dedupKey, isNot(b.dedupKey));
      expect(a, isNot(b));
    });
  });

  group('resolve', () {
    test('a workspace of the account on its own installation opens the '
        'kind\'s screen there', () async {
      final d = await resolveNotificationTap(_data, () async => _facts());
      expect(d, isA<OpenInWorkspace>());
      d as OpenInWorkspace;
      expect(d.location, '/pending');
      expect(d.source, isNull);
      expect(d.reference.workspaceId, 'ws-1');
    });

    test('signed out: the neutral landing', () async {
      final d = await resolveNotificationTap(_data, () async => null);
      expect((d as NeutralLanding).reason, NeutralTapReason.signedOut);
    });

    test('a workspace this account is not a member of (another account\'s '
        'notification) is never opened', () async {
      final d = await resolveNotificationTap(
          _data, () async => _facts(workspaces: {'ws-2'}));
      expect((d as NeutralLanding).reason, NeutralTapReason.unknownSource);
    });

    test('the same workspace id on an installation the account does not '
        'know is not this account\'s workspace', () async {
      final d = await resolveNotificationTap(
          {..._data, 'inst': 'inst-z'}, () async => _facts());
      expect((d as NeutralLanding).reason, NeutralTapReason.unknownSource);
    });

    test('a connected installation opens only after its own verification',
        () async {
      final verified = <(String, String)>[];
      final d = await resolveNotificationTap(
        {..._data, 'inst': 'inst-b', 'kind': 'member_note'},
        () async => _facts(
          connected: {'inst-b': 'https://b.example'},
          verify: (source, ws) {
            verified.add((source, ws));
            return true;
          },
        ),
      );
      d as OpenInWorkspace;
      expect(d.source, 'https://b.example');
      expect(d.location, '/messages');
      expect(verified, [('https://b.example', 'ws-1')]);
    });

    test('a connected workspace the account no longer reaches (revoked) '
        'is not opened', () async {
      final d = await resolveNotificationTap(
        {..._data, 'inst': 'inst-b'},
        () async => _facts(
          connected: {'inst-b': 'https://b.example'},
          verify: (_, _) => false,
        ),
      );
      expect((d as NeutralLanding).reason, NeutralTapReason.unknownSource);
    });

    test('an expired connected session is a neutral landing, not a crash',
        () async {
      final d = await resolveNotificationTap(
        {..._data, 'inst': 'inst-b'},
        () async => _facts(connected: {'inst-b': 'https://b.example'}),
      );
      expect((d as NeutralLanding).reason, NeutralTapReason.unavailable);
    });

    test('malformed data never reads the account at all', () async {
      var asked = false;
      final d = await resolveNotificationTap({'kind': 'member_note'},
          () async {
        asked = true;
        return _facts();
      });
      expect((d as NeutralLanding).reason, NeutralTapReason.malformed);
      expect(asked, isFalse);
    });

    test('each kind has its screen; an unknown kind opens the workspace',
        () {
      expect(notificationLocation('member_mention'), '/messages');
      expect(notificationLocation('invoice_reminder'), '/invoices');
      expect(notificationLocation('reservation_cancelled'), '/reserve');
      expect(notificationLocation('from_a_newer_server'), '/reserve');
    });
  });
}
