// SPDX-License-Identifier: MIT
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

Member member(String id, {bool admin = false, bool owner = false}) => Member(
      id: id,
      workspaceId: 'ws-1',
      userId: 'u-$id',
      isAdmin: admin,
      isOwner: owner,
      status: MemberStatus.active,
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

void main() {
  final admin = member('m-flo', admin: true, owner: true);
  final submitterAdmin = member('m-flo2', admin: true);
  final worker = member('m-worker');

  group('isDecidedBy — expenses (the #107 bug)', () {
    test('the submitter never decides while another admin exists', () {
      expect(
        event().isDecidedBy(submitterAdmin, hasOtherActiveAdmin: true),
        isFalse,
      );
    });

    test('another admin decides', () {
      expect(event().isDecidedBy(admin, hasOtherActiveAdmin: true), isTrue);
    });

    test('workers never decide expenses, even as subject', () {
      expect(
        event(actor: 'm-worker').isDecidedBy(worker, hasOtherActiveAdmin: true),
        isFalse,
      );
    });

    test('solo-admin escape hatch: the only admin may self-decide', () {
      expect(
        event().isDecidedBy(submitterAdmin, hasOtherActiveAdmin: false),
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
      expect(e.isDecidedBy(worker, hasOtherActiveAdmin: true), isTrue);
      expect(e.isDecidedBy(admin, hasOtherActiveAdmin: true), isFalse);
    });

    test('admin-recorded payment is decided by the member', () {
      final e = event(
        type: EventType.payment,
        actor: 'm-flo',
        subject: 'm-worker',
      );
      expect(e.isDecidedBy(worker, hasOtherActiveAdmin: true), isTrue);
      expect(e.isDecidedBy(admin, hasOtherActiveAdmin: true), isFalse);
    });

    test('self-reported service charge is decided by another admin (#129)',
        () {
      final e = event(type: EventType.serviceCharge);
      expect(e.isDecidedBy(submitterAdmin, hasOtherActiveAdmin: true),
          isFalse);
      expect(e.isDecidedBy(admin, hasOtherActiveAdmin: true), isTrue);
      expect(e.isDecidedBy(worker, hasOtherActiveAdmin: true), isFalse);
    });

    test('solo admin may decide their own service charge (escape hatch)', () {
      final e = event(type: EventType.serviceCharge);
      expect(
        e.isDecidedBy(submitterAdmin, hasOtherActiveAdmin: false),
        isTrue,
      );
    });

    test('admin-added service charge is decided by the subject member', () {
      final e = event(
        type: EventType.serviceCharge,
        actor: 'm-flo',
        subject: 'm-worker',
      );
      expect(e.isDecidedBy(worker, hasOtherActiveAdmin: true), isTrue);
      expect(e.isDecidedBy(admin, hasOtherActiveAdmin: true), isFalse);
    });

    test('decided events are nobody to decide', () {
      expect(
        event(status: EventStatus.confirmed)
            .isDecidedBy(admin, hasOtherActiveAdmin: true),
        isFalse,
      );
    });
  });
}
