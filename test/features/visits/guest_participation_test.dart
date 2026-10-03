// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1835 — the guest's projection of a visit, as the app reads it: every
// field the server sends, nothing it does not (no host note, no decider),
// an unknown status kept as unknown, a malformed row dropped rather than
// invented, and the one action the status allows.
import 'package:deskilo/features/visits/domain/guest_participation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final row = <String, Object?>{
    'id': 'v-1',
    'workspace_id': 'w-1',
    'workspace_name': 'Kraftwerk',
    'site_id': 's-1',
    'site_name': 'Hall',
    'status': 'confirmed',
    'starts_at': '2026-10-10T08:00:00+00:00',
    'ends_at': '2026-10-10T12:00:00+00:00',
    'message': 'hello',
    'requested_at': '2026-10-01T09:00:00+00:00',
    'decided_at': '2026-10-02T09:00:00+00:00',
    'cancelled_at': null,
    'revision': 2,
  };

  test('a projected row is read field by field', () {
    final v = GuestParticipation.fromJson(row)!;
    expect(v.id, 'v-1');
    expect(v.workspaceName, 'Kraftwerk');
    expect(v.siteName, 'Hall');
    expect(v.status, GuestVisitStatus.confirmed);
    expect(v.startsAt, DateTime.utc(2026, 10, 10, 8));
    expect(v.endsAt, DateTime.utc(2026, 10, 10, 12));
    expect(v.message, 'hello');
    expect(v.decidedAt, DateTime.utc(2026, 10, 2, 9));
    expect(v.cancelledAt, isNull);
    expect(v.revision, 2);
  });

  test('an unknown status is kept as unknown, never promoted', () {
    final v = GuestParticipation.fromJson({...row, 'status': 'admitted_vip'})!;
    expect(v.status, GuestVisitStatus.unknown);
    expect(v.status.cancellable, isFalse);
  });

  test('a row without an id, a workspace or a window is dropped', () {
    expect(GuestParticipation.fromJson({...row}..remove('id')), isNull);
    expect(GuestParticipation.fromJson({...row, 'workspace_id': 7}), isNull);
    expect(
      GuestParticipation.fromJson({...row, 'starts_at': 'yesterday'}),
      isNull,
    );
    expect(
      GuestParticipation.listFromJson([
        row,
        {'name': 'no id'},
        'x',
      ]).length,
      1,
    );
    expect(GuestParticipation.listFromJson(null), isEmpty);
  });

  test('only a requested or confirmed visit can still be cancelled', () {
    expect(GuestVisitStatus.requested.cancellable, isTrue);
    expect(GuestVisitStatus.confirmed.cancellable, isTrue);
    for (final s in [
      GuestVisitStatus.declined,
      GuestVisitStatus.cancelled,
      GuestVisitStatus.expired,
      GuestVisitStatus.unknown,
    ]) {
      expect(s.cancellable, isFalse, reason: s.name);
    }
  });

  test('the projection carries no host note and no decider', () {
    // The server's self view (0351) names exactly these keys; a host note
    // or a decider in a row is a server bug the app must not paper over —
    // the model simply has no field for them.
    final v = GuestParticipation.fromJson({
      ...row,
      'host_note': 'CANARY',
      'decided_by': 'u-9',
    })!;
    expect(v.toString(), isNot(contains('CANARY')));
  });
}
