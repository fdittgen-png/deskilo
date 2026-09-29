// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1652 — an invitation kept across a server switch comes back only on the
// server it names, only while fresh, and a legacy code is never kept.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/application/pending_invitation.dart';
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:flutter_test/flutter_test.dart';

const _here = BackendEndpoint(
  'https://here.example.org',
  'sb_publishable_here_key_0001',
);
const _there = BackendEndpoint(
  'https://there.example.org',
  'sb_publishable_there_key_0002',
);

void main() {
  final now = DateTime.utc(2026, 9, 28, 10);
  final link = InviteUriCodec.encode(
    code: 'GOODCODE22',
    role: InviteRole.user,
    target: _there,
  );

  test(
    'offered on its own server while fresh, kept for it elsewhere',
    () async {
      final store = InMemoryPendingInvitationStore();
      await PendingInvitations(
        store,
        FixedClock(now),
      ).keep(InvitationReader.read(link), link);
      expect(
        await PendingInvitations(store, FixedClock(now)).offeredOn(_here),
        isNull,
      );
      expect(store.value, isNotNull, reason: 'another server does not drop it');
      expect(
        await PendingInvitations(
          store,
          FixedClock(now.add(const Duration(minutes: 59))),
        ).offeredOn(_there),
        link,
      );
    },
  );

  test('stale or unreadable is dropped; a legacy code is never kept', () async {
    final store = InMemoryPendingInvitationStore();
    await PendingInvitations(
      store,
      FixedClock(now),
    ).keep(InvitationReader.read(link), link);
    expect(
      await PendingInvitations(
        store,
        FixedClock(now.add(PendingInvitations.lifetime)),
      ).offeredOn(_there),
      isNull,
    );
    expect(store.value, isNull);
    store.value = '{not json';
    expect(
      await PendingInvitations(store, FixedClock(now)).offeredOn(_there),
      isNull,
    );
    expect(store.value, isNull);
    await PendingInvitations(
      store,
      FixedClock(now),
    ).keep(InvitationReader.read('GOODCODE22'), 'GOODCODE22');
    expect(store.value, isNull);
  });
}
