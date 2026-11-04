// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3293 — who did it, and who may see it, in the Demo.
//
// Each test acts through the Demo's own composition (the fixture a
// session builds, and the scope's per-space overrides) as one persona, and
// asserts the actor the act is recorded under, or the refusal the server
// gives that persona. The matrix these rows prove is
// docs/testing/DEMO_PERSONA_MATRIX.md.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/payment_terms.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _ada = 'member-1', _bruno = 'member-2', _chiara = 'member-3';

Matcher _refused(String message) => isA<PostgrestException>().having(
  (e) => e.message,
  'message',
  contains(message),
);

DemoFixture _as(DemoPersona persona) =>
    DemoFixture.build()..becomePersona(persona);

/// The scope's routed repositories, read as the fixture's persona.
Future<ProviderContainer> _scope(DemoFixture fixture) async {
  final container = ProviderContainer(overrides: demoOverrides(fixture));
  addTearDown(container.dispose);
  container.listen(currentWorkspaceProvider, (_, _) {});
  await container.read(currentWorkspaceProvider.future);
  await container.read(myMemberProvider.future);
  return container;
}

Reservation _futureBookingOf(DemoFixture fixture, String memberId) =>
    fixture.reservations.reservations.firstWhere(
      (r) =>
          r.memberId == memberId &&
          r.status == ReservationStatus.reserved &&
          r.seatId != null &&
          r.startsAt.isAfter(fixture.seededAt),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('requests and decisions carry the acting persona', () {
    test('a request is the member\'s, stamped on the session clock', () async {
      final fixture = _as(DemoPersona.member);
      final id = await fixture.events.requestQuotaExtension(
        'ws-1',
        period: '2026-05',
        halfDays: 2,
      );
      final event = (await fixture.events.fetchEvent(id))!;
      expect(event.actorMemberId, _bruno);
      expect(event.subjectMemberId, _bruno);
      expect(event.createdAt, fixture.seededAt);
    });

    test('the member cannot decide their own request; the administrator '
        'decides it under her own name', () async {
      final fixture = _as(DemoPersona.member);
      final id = await fixture.events.requestQuotaExtension(
        'ws-1',
        period: '2026-05',
        halfDays: 2,
      );
      await expectLater(
        fixture.events.respond(id, accept: true),
        throwsA(_refused('not allowed to decide')),
      );

      fixture.becomePersona(DemoPersona.admin);
      await fixture.events.respond(id, accept: true);
      final decision = (await fixture.events.fetchDecisions('ws-1', [
        id,
      ]))[id]!.single;
      expect(decision.memberId, _chiara);
      expect(decision.decidedAt, fixture.seededAt);
      expect(
        (await fixture.events.fetchEvent(id))!.status,
        EventStatus.confirmed,
      );
    });

    test('the wall tablet decides nothing', () async {
      final fixture = _as(DemoPersona.member);
      final id = await fixture.events.requestQuotaExtension(
        'ws-1',
        period: '2026-05',
        halfDays: 1,
      );
      fixture.becomePersona(DemoPersona.kiosk);
      await expectLater(
        fixture.events.respond(id, accept: false),
        throwsA(_refused('not allowed to decide')),
      );
    });

    test('a payment-terms request is filed by whoever asks', () async {
      final fixture = _as(DemoPersona.admin);
      final id = await fixture.events.requestPaymentTermsChange(
        _bruno,
        terms: const PaymentTerms(paymentTerms: '30 days'),
      );
      expect((await fixture.events.fetchEvent(id))!.actorMemberId, _chiara);
    });

    test('a request asked in Leipzig is Leipzig\'s', () async {
      final fixture = _as(DemoPersona.owner);
      final id = await fixture.secondSpace.events.requestInvoiceWriteoff(
        'de-inv-1',
        reason: 'demo',
      );
      final feed = await fixture.secondSpace.events.fetchEvents(
        demoSecondSpaceId,
      );
      final event = feed.singleWhere((e) => e.id == id);
      expect(event.workspaceId, demoSecondSpaceId);
      expect(event.actorMemberId, _ada);
    });
  });

  group('bookings for and of someone else', () {
    test('a member cannot book for another member', () async {
      final fixture = _as(DemoPersona.member);
      final repo = (await _scope(fixture)).read(reservationRepositoryProvider);
      final seat = _futureBookingOf(fixture, _chiara);
      await expectLater(
        repo.createFor(
          workspaceId: 'ws-1',
          subjectMemberId: _ada,
          seatId: seat.seatId,
          startsAt: seat.startsAt.add(const Duration(days: 400)),
          endsAt: seat.endsAt.add(const Duration(days: 400)),
        ),
        throwsA(_refused('not an admin')),
      );
    });

    test('the administrator books for an active member, never for a '
        'stranger', () async {
      final fixture = _as(DemoPersona.admin);
      final repo = (await _scope(fixture)).read(reservationRepositoryProvider);
      final seat = _futureBookingOf(fixture, _chiara);
      final at = seat.startsAt.add(const Duration(days: 400));
      final to = seat.endsAt.add(const Duration(days: 400));
      await expectLater(
        repo.createFor(
          workspaceId: 'ws-1',
          subjectMemberId: 'nobody',
          seatId: seat.seatId,
          startsAt: at,
          endsAt: to,
        ),
        throwsA(_refused('unknown subject member')),
      );
      await repo.createFor(
        workspaceId: 'ws-1',
        subjectMemberId: _bruno,
        seatId: seat.seatId,
        startsAt: at,
        endsAt: to,
      );
      expect(
        fixture.reservations.reservations
            .where((r) => r.startsAt == at && r.seatId == seat.seatId)
            .single
            .memberId,
        _bruno,
      );
    });

    test('a member cancels their own booking, not somebody else\'s', () async {
      final fixture = _as(DemoPersona.member);
      final repo = (await _scope(fixture)).read(reservationRepositoryProvider);
      final theirs = _futureBookingOf(fixture, _chiara);
      await expectLater(
        repo.cancel(theirs.id),
        throwsA(_refused('not your reservation')),
      );
      final mine = _futureBookingOf(fixture, _bruno);
      await repo.cancel(mine.id);
      expect(
        fixture.reservations.reservations
            .firstWhere((r) => r.id == mine.id)
            .status,
        ReservationStatus.cancelled,
      );
    });

    test('the tablet treats the badge member\'s own booking as theirs, and '
        'another member\'s as taken', () async {
      final fixture = _as(DemoPersona.kiosk);
      final own = _futureBookingOf(fixture, _bruno);
      await fixture.reservations.kioskAct(
        workspaceId: 'ws-1',
        badgeToken: 'badge-bruno',
        action: 'reserve',
        seatId: own.seatId,
        startsAt: own.startsAt,
        endsAt: own.endsAt,
      );
      final other = _futureBookingOf(fixture, _chiara);
      await expectLater(
        fixture.reservations.kioskAct(
          workspaceId: 'ws-1',
          badgeToken: 'badge-bruno',
          action: 'reserve',
          seatId: other.seatId,
          startsAt: other.startsAt,
          endsAt: other.endsAt,
        ),
        throwsA(_refused('already reserved')),
      );
    });
  });

  group('messages are signed by, and shown to, the right people', () {
    test('a message Bruno sends is signed Bruno', () async {
      final fixture = _as(DemoPersona.member);
      final group = await fixture.messenger.createGroup('Desk swap', const []);
      await fixture.messenger.sendGroupMessage(group, 'Can we swap Friday?');
      final sent = (await fixture.messenger.groupMessages(group)).first;
      expect(sent.authorName, 'Bruno Kessler');
    });

    test('a note is from whoever sends it', () async {
      final fixture = _as(DemoPersona.member);
      await fixture.workspaces.sendMemberNote(
        'ws-1',
        toMemberId: _ada,
        body: 'Running late',
      );
      expect(fixture.workspaces.memberNotes.last.fromMemberId, _bruno);
    });

    test('Ada and Bruno\'s direct thread is theirs: Chiara neither lists '
        'nor reads it', () async {
      final fixture = _as(DemoPersona.admin);
      final listed = await fixture.workspaces.fetchConversations('ws-1');
      expect(listed.map((c) => c.id), isNot(contains('demo-conv-bruno')));
      expect(listed.map((c) => c.id), contains('demo-conv-studio'));
      expect(
        await fixture.workspaces.fetchConversationMessages('demo-conv-bruno'),
        isEmpty,
      );
      expect(
        (await fixture.workspaces.fetchMyNotes('ws-1'))
            .where((n) => n.conversationId == 'demo-conv-bruno'),
        isEmpty,
      );
    });

    test('Bruno sees the same thread with Ada as the other person', () async {
      final fixture = _as(DemoPersona.member);
      final thread = (await fixture.workspaces.fetchConversations('ws-1'))
          .singleWhere((c) => c.id == 'demo-conv-bruno');
      expect(thread.otherMemberId, _ada);
      expect(
        await fixture.workspaces.fetchConversationMessages('demo-conv-bruno'),
        isNotEmpty,
      );
    });
  });

  group('roles', () {
    test('a role is never assigned to yourself, whoever you are', () async {
      final fixture = _as(DemoPersona.admin);
      final role = fixture.roles.roles.first.id;
      expect(
        () => fixture.roles.assignRole(
          memberId: _chiara,
          roleId: role,
          assign: true,
        ),
        throwsStateError,
      );
      await fixture.roles.assignRole(
        memberId: _ada,
        roleId: role,
        assign: true,
      );
      expect(fixture.roles.assignments[role], contains(_ada));
    });

    test('editing Leipzig\'s matrix is decided by the rights held in '
        'Leipzig, not in the main space', () async {
      final fixture = _as(DemoPersona.owner);
      final space = fixture.secondSpace.workspaces;
      final leipzig = space.workspaces.singleWhere(
        (w) => w.id == demoSecondSpaceId,
      );
      final may = effectivePermissions(
        space.myMember,
        leipzig,
      ).contains(WorkspacePermission.manageRoles);
      final edit = space.setRolePermission(
        demoSecondSpaceId,
        'member',
        'viewFinances',
        enabled: true,
      );
      if (may) {
        await edit;
      } else {
        await expectLater(edit, throwsStateError);
      }

      fixture.becomePersona(DemoPersona.member);
      expect(
        effectivePermissions(
          space.myMember,
          leipzig,
        ).contains(WorkspacePermission.manageRoles),
        isFalse,
      );
      await expectLater(
        space.setRolePermission(
          demoSecondSpaceId,
          'member',
          'viewFinances',
          enabled: false,
        ),
        throwsStateError,
      );
    });
  });

  test(
    'a reset forgets what the persona did, and starts as the owner again',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(demoSessionControllerProvider.notifier)
        ..viewAs(DemoPersona.member);
      final before = container.read(demoSessionControllerProvider).fixture;
      final id = await before.events.requestQuotaExtension(
        'ws-1',
        period: '2026-05',
        halfDays: 1,
      );
      controller.reset();
      final after = container.read(demoSessionControllerProvider);
      expect(after.persona, DemoPersona.owner);
      expect(await after.fixture.events.fetchEvent(id), isNull);
      expect(after.fixture.activeMemberId, _ada);
    },
  );
}
