// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the billing-access grants through the one command door and the
// in-memory repository that holds the server's rules (0910): the seller invites
// a billing customer once per request id, the account previews and accepts a
// code, an unusable code gets ONE answer, a revocation erases nothing, and a
// failure that is not a refusal claims nothing.
import 'dart:async';

import 'package:deskilo/core/demo/data/fake_billing_access.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/money/application/billing_access_commands.dart';
import 'package:deskilo/features/money/domain/billing_access.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = 'ws-1';
const _lumi = BillingParty(
  subjectId: 'c-1',
  revision: 1,
  draft: BillingPartyDraft(company: 'Atelier Lumi'),
);

(FakeBillingAccessRepository, BillingAccessCommands, _Clock) _build({
  bool Function()? mayManage,
}) {
  final clock = _Clock(DateTime.utc(2026, 11, 24, 9));
  final repo = FakeBillingAccessRepository(
    clock: clock.now,
    customerOf: (ws, id) => ws == _ws && id == _lumi.subjectId ? _lumi : null,
    workspaceNameOf: (_) => 'Atelier du Marché',
    mayManage: mayManage ?? () => true,
  );
  return (repo, BillingAccessCommands(repo), clock);
}

class _Clock {
  _Clock(this.at);
  DateTime at;
  DateTime now() => at;
}

T _done<T>(CommandOutcome<T> o) => (o as CommandDone<T>).value;

BillingAccessRefusalKind _refusedWith(CommandOutcome<Object?> o) =>
    ((o as CommandRefused<Object?>).refusal.cause! as BillingAccessRefusal).kind;

void main() {
  test('an invitation hands out its code; the same request answers the same '
      'invitation, a new request a new one', () async {
    final (_, commands, _) = _build();
    final first = _done(await commands.invite(_ws, 'c-1', 'r-1'));
    final again = _done(await commands.invite(_ws, 'c-1', 'r-1'));
    expect(again.grantId, first.grantId);
    expect(again.code, first.code);
    expect(again.replayed, isTrue);
    final other = _done(await commands.invite(_ws, 'c-1', 'r-2'));
    expect(other.grantId, isNot(first.grantId));
    expect(other.replayed, isFalse);
  });

  test('a request id used for another subject is refused (DKH05)', () async {
    final (_, commands, _) = _build();
    await commands.invite(_ws, 'c-1', 'r-1');
    expect(
      _refusedWith(await commands.invite(_ws, 'other', 'r-1')),
      BillingAccessRefusalKind.requestReused,
    );
  });

  test('only a billing customer can be invited, and only with the right '
      '(DKH02, DKN01)', () async {
    final (_, commands, _) = _build();
    expect(
      _refusedWith(await commands.invite(_ws, 'a-member', 'r-1')),
      BillingAccessRefusalKind.notACustomer,
    );
    final (repo, denied, _) = _build(mayManage: () => false);
    expect(
      _refusedWith(await denied.invite(_ws, 'c-1', 'r-1')),
      BillingAccessRefusalKind.notAllowed,
    );
    expect(
      _refusedWith(await denied.grantsOf(_ws, 'c-1')),
      BillingAccessRefusalKind.notAllowed,
    );
    expect(repo.heldSubjects, isEmpty);
  });

  test('the account previews, then accepts; accepting again answers the same '
      'grant and holds the subject once', () async {
    final (repo, commands, _) = _build();
    final code = _done(await commands.invite(_ws, 'c-1', 'r-1')).code;
    final preview = _done(await commands.preview(' ${code.toLowerCase()} '));
    expect(preview.workspaceName, 'Atelier du Marché');
    expect(preview.billedAs, 'Atelier Lumi');
    expect(preview.accepted, isFalse);
    expect(repo.heldSubjects, isEmpty, reason: 'a preview grants nothing');

    final accepted = _done(await commands.accept(code));
    expect(accepted.subjectId, 'c-1');
    expect(accepted.replayed, isFalse);
    final again = _done(await commands.accept(code));
    expect(again.grantId, accepted.grantId);
    expect(again.replayed, isTrue);
    expect(repo.heldSubjects, {'c-1'});
    expect(_done(await commands.preview(code)).accepted, isTrue);
  });

  test(
    'a second code of a subject the account holds answers the first grant',
    () async {
      final (repo, commands, _) = _build();
      final a = _done(await commands.invite(_ws, 'c-1', 'r-1')).code;
      final b = _done(await commands.invite(_ws, 'c-1', 'r-2')).code;
      final held = _done(await commands.accept(a));
      final second = _done(await commands.accept(b));
      expect(second.grantId, held.grantId);
      expect(second.replayed, isTrue);
      expect(repo.heldSubjects, {'c-1'});
    },
  );

  test('an unknown, expired or revoked code gets ONE answer (DKH01)', () async {
    final (_, commands, clock) = _build();
    expect(
      _refusedWith(await commands.accept('NOPE')),
      BillingAccessRefusalKind.codeUnusable,
    );
    final old = _done(await commands.invite(_ws, 'c-1', 'r-1'));
    clock.at = clock.at.add(const Duration(days: 15));
    expect(
      _refusedWith(await commands.preview(old.code)),
      BillingAccessRefusalKind.codeUnusable,
    );
    final fresh = _done(await commands.invite(_ws, 'c-1', 'r-2'));
    await commands.revoke(fresh.grantId);
    expect(
      _refusedWith(await commands.accept(fresh.code)),
      BillingAccessRefusalKind.codeUnusable,
    );
  });

  test('an empty code is refused before anything is sent', () async {
    final (repo, commands, _) = _build();
    final outcome = await commands.preview('   ');
    expect(_refusedWith(outcome), BillingAccessRefusalKind.codeUnusable);
    expect(repo.calls, isEmpty);
  });

  test('a revocation ends the access and erases nothing; an unknown grant and '
      'a long reason are refused (DKH03, DKH04)', () async {
    final (repo, commands, _) = _build();
    final inv = _done(await commands.invite(_ws, 'c-1', 'r-1'));
    await commands.accept(inv.code);
    expect(repo.heldSubjects, {'c-1'});
    expect(
      await commands.revoke(inv.grantId, reason: 'left'),
      isA<CommandDone<void>>(),
    );
    expect(repo.heldSubjects, isEmpty);
    final grants = _done(await commands.grantsOf(_ws, 'c-1'));
    expect(
      grants.single.stateAt(DateTime.utc(2026, 11, 24)),
      BillingGrantState.revoked,
    );
    expect(grants.single.revokeReason, 'left');
    expect(
      _refusedWith(await commands.revoke('ghost')),
      BillingAccessRefusalKind.unknownGrant,
    );
    final tooLong = 'x' * (billingRevokeReasonMax + 1);
    expect(
      _refusedWith(await commands.revoke(inv.grantId, reason: tooLong)),
      BillingAccessRefusalKind.reasonTooLong,
    );
  });

  test(
    'a failure that is not a refusal claims nothing and a retry recovers',
    () async {
      final (repo, commands, _) = _build();
      // #4413 -- a lost answer is a transport failure: not reached.
      repo.failNext = TimeoutException('offline');
      expect(
        await commands.invite(_ws, 'c-1', 'r-1'),
        isA<CommandUnreached<BillingAccessInvitation>>(),
      );
      final retried = _done(await commands.invite(_ws, 'c-1', 'r-1'));
      expect(retried.code, isNotEmpty);
      expect(_done(await commands.grantsOf(_ws, 'c-1')), hasLength(1));
    },
  );

  test(
    'a grant reads as invited, active, expired or revoked from its stamps',
    () {
      final t = DateTime.utc(2026, 11, 24);
      BillingAccessGrant grant({DateTime? accepted, DateTime? revoked}) =>
          BillingAccessGrant(
            id: 'g',
            subjectId: 's',
            invitedAt: t,
            expiresAt: t.add(const Duration(days: 14)),
            acceptedAt: accepted,
            revokedAt: revoked,
          );
      expect(grant().stateAt(t), BillingGrantState.invited);
      expect(
        grant().stateAt(t.add(const Duration(days: 15))),
        BillingGrantState.expired,
      );
      expect(
        grant(accepted: t).stateAt(t.add(const Duration(days: 40))),
        BillingGrantState.active,
      );
      expect(
        grant(accepted: t, revoked: t).stateAt(t),
        BillingGrantState.revoked,
      );
    },
  );

  test('the server\'s answers are read as they are sent', () {
    final grant = BillingAccessGrant.fromJson({
      'id': 'g-1',
      'financial_subject_id': 's-1',
      'invited_at': '2026-11-24T09:00:00Z',
      'expires_at': '2026-12-08T09:00:00Z',
      'accepted_at': null,
      'revoked_at': null,
      'revoke_reason': '',
    });
    expect(grant.subjectId, 's-1');
    final invitation = BillingAccessInvitation.fromJson({
      'grant_id': 'g-1',
      'code': 'ABCD2345',
      'expires_at': '2026-12-08T09:00:00Z',
      'replayed': true,
    });
    expect(invitation.code, 'ABCD2345');
    expect(invitation.replayed, isTrue);
    final accepted = BillingAccessAccepted.fromJson({
      'grant_id': 'g-1',
      'workspace_id': 'w',
      'financial_subject_id': 's-1',
      'replayed': false,
    });
    expect(accepted.workspaceId, 'w');
    expect(
      BillingAccessPreview.fromJson({
        'workspace_name': 'A',
        'billed_as': null,
        'purpose': 'billing_documents',
        'accepted': false,
        'expires_at': '2026-12-08T09:00:00Z',
      }).billedAs,
      '',
    );
  });
}
