// SPDX-License-Identifier: MIT
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

Member member(
  String id, {
  bool admin = false,
  bool owner = false,
  MemberStatus status = MemberStatus.active,
}) =>
    Member(
      id: id,
      workspaceId: 'ws-1',
      userId: 'u-$id',
      isAdmin: admin,
      isOwner: owner,
      status: status,
    );

WorkspaceEvent event({
  EventType type = EventType.expense,
  String actor = 'm-flo2',
  String? subject,
  EventStatus status = EventStatus.pending,
}) =>
    WorkspaceEvent(
      id: 'e1',
      workspaceId: 'ws-1',
      type: type,
      action: EventAction.submitted,
      actorMemberId: actor,
      subjectMemberId: subject ?? actor,
      payload: const {'amount_cents': 20000},
      status: status,
      createdAt: DateTime.utc(2026, 7, 8),
    );

/// Pre-#130 plumbing: no stored policy rows behave like the old protocol,
/// so `hasOtherActiveAdmin` maps 1:1 to `hasOtherEligibleValidator`.
final noPolicy = ValidationPolicy.defaults('ws-1', null);

void main() {
  final admin = member('m-flo', admin: true, owner: true);
  final submitterAdmin = member('m-flo2', admin: true);
  final worker = member('m-worker');

  group('isDecidedBy — expenses (the #107 bug)', () {
    test('the submitter never decides while another admin exists', () {
      expect(
        event().isDecidedBy(
          submitterAdmin,
          policy: noPolicy,
          hasOtherEligibleValidator: true,
        ),
        isFalse,
      );
    });

    test('another admin decides', () {
      expect(
        event().isDecidedBy(
          admin,
          policy: noPolicy,
          hasOtherEligibleValidator: true,
        ),
        isTrue,
      );
    });

    test('workers never decide expenses, even as subject', () {
      expect(
        event(actor: 'm-worker').isDecidedBy(
          worker,
          policy: noPolicy,
          hasOtherEligibleValidator: true,
        ),
        isFalse,
      );
    });

    test('solo-admin escape hatch: the only admin may self-decide', () {
      expect(
        event().isDecidedBy(
          submitterAdmin,
          policy: noPolicy,
          hasOtherEligibleValidator: false,
        ),
        isTrue,
      );
    });
  });

  group('isDecidedBy — other event types', () {
    test('reservation-for-other is decided by the subject', () {
      final e = event(
        type: EventType.reservation,
        actor: 'm-flo',
        subject: 'm-worker',
      );
      expect(
        e.isDecidedBy(worker, policy: noPolicy, hasOtherEligibleValidator: true),
        isTrue,
      );
      expect(
        e.isDecidedBy(admin, policy: noPolicy, hasOtherEligibleValidator: true),
        isFalse,
      );
    });

    test('admin-recorded payment is decided by the member', () {
      final e = event(
        type: EventType.payment,
        actor: 'm-flo',
        subject: 'm-worker',
      );
      expect(
        e.isDecidedBy(worker, policy: noPolicy, hasOtherEligibleValidator: true),
        isTrue,
      );
      expect(
        e.isDecidedBy(admin, policy: noPolicy, hasOtherEligibleValidator: true),
        isFalse,
      );
    });

    test('self-reported service charge is decided by another admin (#129)',
        () {
      final e = event(type: EventType.serviceCharge);
      expect(
        e.isDecidedBy(
          submitterAdmin,
          policy: noPolicy,
          hasOtherEligibleValidator: true,
        ),
        isFalse,
      );
      expect(
        e.isDecidedBy(admin, policy: noPolicy, hasOtherEligibleValidator: true),
        isTrue,
      );
      expect(
        e.isDecidedBy(worker, policy: noPolicy, hasOtherEligibleValidator: true),
        isFalse,
      );
    });

    test('solo admin may decide their own service charge (escape hatch)', () {
      final e = event(type: EventType.serviceCharge);
      expect(
        e.isDecidedBy(
          submitterAdmin,
          policy: noPolicy,
          hasOtherEligibleValidator: false,
        ),
        isTrue,
      );
    });

    test('admin-added service charge is decided by the subject member', () {
      final e = event(
        type: EventType.serviceCharge,
        actor: 'm-flo',
        subject: 'm-worker',
      );
      expect(
        e.isDecidedBy(worker, policy: noPolicy, hasOtherEligibleValidator: true),
        isTrue,
      );
      expect(
        e.isDecidedBy(admin, policy: noPolicy, hasOtherEligibleValidator: true),
        isFalse,
      );
    });

    test('decided events are nobody to decide', () {
      expect(
        event(status: EventStatus.confirmed).isDecidedBy(
          admin,
          policy: noPolicy,
          hasOtherEligibleValidator: true,
        ),
        isFalse,
      );
    });
  });

  group('isDecidedBy — quorum policies (#130)', () {
    // An expense submitted by a worker: only the validator pool decides.
    final e = event(actor: 'm-worker');
    final plainAdmin = member('m-a1', admin: true);
    final otherAdmin = member('m-a2', admin: true);
    final owner = member('m-owner', owner: true);

    test('owner-only policy: admins see no buttons, the owner does', () {
      final policy = noPolicy.copyWith(adminsMayValidate: false);
      expect(
        e.isDecidedBy(plainAdmin,
            policy: policy, hasOtherEligibleValidator: true),
        isFalse,
      );
      expect(
        e.isDecidedBy(owner, policy: policy, hasOtherEligibleValidator: true),
        isTrue,
      );
    });

    test('specific eligible admins: only listed admins validate', () {
      final policy = noPolicy.copyWith(eligibleAdminIds: ['m-a1']);
      expect(
        e.isDecidedBy(plainAdmin,
            policy: policy, hasOtherEligibleValidator: true),
        isTrue,
      );
      expect(
        e.isDecidedBy(otherAdmin,
            policy: policy, hasOtherEligibleValidator: true),
        isFalse,
      );
      // Owners always may, listed or not.
      expect(
        e.isDecidedBy(owner, policy: policy, hasOtherEligibleValidator: true),
        isTrue,
      );
    });

    test('an already-decided member sees no buttons', () {
      expect(
        e.isDecidedBy(
          plainAdmin,
          policy: noPolicy,
          hasOtherEligibleValidator: true,
          alreadyDecided: true,
        ),
        isFalse,
      );
    });

    test('owner_required: the pending event shows for the owner', () {
      final policy = noPolicy.copyWith(ownerRequired: true, requiredCount: 2);
      expect(
        e.isDecidedBy(owner, policy: policy, hasOtherEligibleValidator: true),
        isTrue,
      );
      expect(
        e.isDecidedBy(
          owner,
          policy: policy,
          hasOtherEligibleValidator: true,
          alreadyDecided: true,
        ),
        isFalse,
      );
    });

    test(
        'a non-actor admin may also validate a subject-decides event '
        '(their accept counts toward the quorum)', () {
      final forOther = event(
        type: EventType.reservation,
        actor: 'm-flo',
        subject: 'm-worker',
      );
      expect(
        forOther.isDecidedBy(plainAdmin,
            policy: noPolicy, hasOtherEligibleValidator: true),
        isTrue,
      );
    });

    test('inactive members never decide', () {
      final paused = member('m-a1', admin: true, status: MemberStatus.paused);
      expect(
        e.isDecidedBy(paused,
            policy: noPolicy, hasOtherEligibleValidator: true),
        isFalse,
      );
    });
  });

  group('hasOtherEligibleValidator', () {
    final e = event(actor: 'm-worker');

    test('counts owners and eligible admins, never actor or subject', () {
      final members = [
        member('m-worker'), // actor+subject
        member('m-a1', admin: true),
      ];
      expect(e.hasOtherEligibleValidator(members, noPolicy), isTrue);
      expect(
        e.hasOtherEligibleValidator(
          members,
          noPolicy.copyWith(adminsMayValidate: false),
        ),
        isFalse,
      );
      expect(
        e.hasOtherEligibleValidator(
          members,
          noPolicy.copyWith(eligibleAdminIds: ['m-a2']),
        ),
        isFalse,
      );
    });

    test('owners count even when admins may not validate', () {
      final members = [member('m-owner', owner: true)];
      expect(
        e.hasOtherEligibleValidator(
          members,
          noPolicy.copyWith(adminsMayValidate: false),
        ),
        isTrue,
      );
    });

    test('the pool is empty when only the actor could validate (#107)', () {
      final members = [member('m-worker', admin: true)];
      expect(e.hasOtherEligibleValidator(members, noPolicy), isFalse);
    });
  });
}
