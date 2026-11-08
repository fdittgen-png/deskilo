// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3293 — who did it, and who may see it, in the Demo.
//
// Each test acts through the Demo's own composition (the fixture a
// session builds, and the scope's per-space overrides) as one persona, and
// asserts the actor the act is recorded under, or the refusal the server
// gives that persona. The matrix these rows prove is
// docs/testing/DEMO_PERSONA_MATRIX.md.
import 'package:deskilo/core/demo/data/event_visibility.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
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

  group('conversations deliver to their participants only', () {
    const direct = 'demo-conv-bruno', studio = 'demo-conv-studio';

    Future<bool> reads(DemoFixture f, String conversation, String body) async =>
        (await f.workspaces.fetchConversationMessages(conversation))
            .any((n) => n.body == body);

    test(
      'a reply in a direct thread goes to the other person, both ways',
      () async {
        final fixture = _as(DemoPersona.member);
        await fixture.workspaces.sendConversationMessage(
          direct,
          'See you at 9',
        );
        expect(fixture.workspaces.memberNotes.last.toMemberId, _ada);
        fixture.becomePersona(DemoPersona.owner);
        expect(await reads(fixture, direct, 'See you at 9'), isTrue);

        await fixture.workspaces.sendConversationMessage(direct, 'Perfect');
        expect(fixture.workspaces.memberNotes.last.toMemberId, _bruno);
        fixture.becomePersona(DemoPersona.member);
        expect(await reads(fixture, direct, 'Perfect'), isTrue);
      },
    );

    test('a third person cannot write into a direct thread', () async {
      final fixture = _as(DemoPersona.admin);
      await expectLater(
        fixture.workspaces.sendConversationMessage(direct, 'Hello?'),
        throwsA(_refused('not a participant')),
      );
      expect(
        fixture.workspaces.memberNotes.where((n) => n.body == 'Hello?'),
        isEmpty,
      );
    });

    test('a group message reaches every current member of the group, '
        'ordinary members included', () async {
      final fixture = _as(DemoPersona.admin);
      await fixture.workspaces.sendConversationMessage(studio, 'Screen is up');
      expect(fixture.workspaces.memberNotes.last.conversationId, studio);
      fixture.becomePersona(DemoPersona.member);
      expect(await reads(fixture, studio, 'Screen is up'), isTrue);
      expect(
        (await fixture.workspaces.fetchMyNotes('ws-1'))
            .any((n) => n.body == 'Screen is up'),
        isTrue,
      );
    });

    test('a member removed from a group no longer lists it, sends into it '
        'or reads what is written after', () async {
      final fixture = _as(DemoPersona.owner);
      await fixture.workspaces.removeParticipant(studio, _bruno);
      await fixture.workspaces.sendConversationMessage(studio, 'After Bruno');
      fixture.becomePersona(DemoPersona.member);
      expect(
        (await fixture.workspaces.fetchConversations('ws-1')).map((c) => c.id),
        isNot(contains(studio)),
      );
      expect(await reads(fixture, studio, 'After Bruno'), isFalse);
      expect(
        await reads(fixture, studio, 'Perfect, I will set up the screen.'),
        isTrue,
        reason: 'what was written while he was a member stays his to read',
      );
      await expectLater(
        fixture.workspaces.sendConversationMessage(studio, 'Still here?'),
        throwsA(_refused('not a participant')),
      );
    });
  });

  test('Leipzig\'s requests are read by its members only: after a switch to '
      'a persona with no membership there, the routed feed is empty', () async {
    final fixture = _as(DemoPersona.owner);
    final container = await _scope(fixture);
    container
        .read(activeWorkspaceIdProvider.notifier)
        .activate(demoSecondSpaceId);
    await container.read(currentWorkspaceProvider.future);
    final routed = container.read(eventRepositoryProvider);
    expect(routed, same(fixture.secondSpace.events));
    expect(await routed.fetchEvents(demoSecondSpaceId), isNotEmpty);

    fixture.becomePersona(DemoPersona.admin);
    expect(await routed.fetchEvents(demoSecondSpaceId), isEmpty);
    expect(await routed.fetchEvent('de-quota-ada'), isNull);
  });

  group('what an administrator reads is what their matrix reads', () {
    // A type only the two finance rights read (a payment, a service
    // charge): a quota is also manageReservations', an expense
    // approveExpenses'.
    bool finance(WorkspaceEvent e) => eventTypeViewPermissions(e.type.dbName)
        .difference({
          WorkspacePermission.viewFinances,
          WorkspacePermission.issueInvoices,
        })
        .isEmpty;

    test('an administrator explicitly without viewFinances and '
        'issueInvoices reads nobody else\'s payment events nor their '
        'decisions', () async {
      final fixture = _as(DemoPersona.admin);
      final others = [
        for (final e in fixture.events.events)
          if (e.workspaceId == 'ws-1' &&
              finance(e) &&
              e.actorMemberId != _chiara &&
              e.subjectMemberId != _chiara &&
              policyFor(
                    e.type.dbName,
                    fixture.events.policies,
                  ).validatorScope ==
                  'admins')
            e.id,
      ];
      expect(others, isNotEmpty, reason: 'the Demo seeds such events');
      final open = await fixture.events.fetchEvents('ws-1');
      expect(
        open.map((e) => e.id),
        containsAll(others),
        reason: 'the default administrator matrix reads finances',
      );

      final i = fixture.workspaces.workspaces.indexWhere((w) => w.id == 'ws-1');
      final ws = fixture.workspaces.workspaces[i];
      // The legacy adminInvoicing switch grants issueInvoices to every
      // administrator, as has_permission_raw does: off, for a matrix that
      // means what it says.
      fixture.workspaces.workspaces[i] = ws.copyWith(
        featureFlags: {
          ...ws.featureFlags,
          WorkspaceFeature.adminInvoicing.name: false,
        },
        rolePermissions: {
          ...ws.rolePermissions,
          'admin': [
            for (final p in defaultPermissionsFor(PermissionRole.admin))
              if (p != WorkspacePermission.viewFinances &&
                  p != WorkspacePermission.issueInvoices)
                p.name,
          ],
        },
      );
      final held = effectivePermissions(
        fixture.workspaces.memberOf(_chiara),
        fixture.workspaces.workspaces[i],
      );
      expect(held, isNot(contains(WorkspacePermission.viewFinances)));
      expect(held, isNot(contains(WorkspacePermission.issueInvoices)));
      final restricted = await fixture.events.fetchEvents('ws-1');
      expect(restricted.map((e) => e.id), isNot(contains(anyOf(others))));
      expect(await fixture.events.fetchDecisions('ws-1', others), isEmpty);
      expect(await fixture.events.fetchEvent(others.first), isNull);
      expect(
        restricted.where((e) => e.type == EventType.memberJoin),
        isNotEmpty,
        reason: 'what manageMembers reads stays readable',
      );
    });

    test('a permission given by an enabled custom role reads like the '
        'matrix\'s: granted, revoked, and gone with customRoles off', () async {
      final fixture = _as(DemoPersona.owner);
      // Elise's payment, recorded by Ada: nothing of it is Bruno's.
      fixture.events.events.add(
        WorkspaceEvent(
          id: 'demo-payment-elise',
          workspaceId: 'ws-1',
          type: EventType.invoicePayment,
          action: EventAction.created,
          actorMemberId: _ada,
          subjectMemberId: 'member-5',
          payload: const {'paid_cents': 4800},
          status: EventStatus.pending,
          createdAt: fixture.seededAt,
        ),
      );
      const others = ['demo-payment-elise'];
      Future<bool> brunoReads() async =>
          (await fixture.events.fetchEvents('ws-1'))
              .any((e) => others.contains(e.id));

      fixture.roles.roles.add(
        const WorkspaceRole(
          id: 'demo-role-finance-reader',
          key: 'finance_reader',
          names: {'en': 'Finance reader'},
          permissions: {WorkspacePermission.viewFinances},
        ),
      );
      fixture.becomePersona(DemoPersona.member);
      expect(await brunoReads(), isFalse, reason: 'a plain member');

      fixture.becomePersona(DemoPersona.owner);
      await fixture.roles.assignRole(
        memberId: _bruno,
        roleId: 'demo-role-finance-reader',
        assign: true,
      );
      fixture.becomePersona(DemoPersona.member);
      expect(await brunoReads(), isTrue, reason: 'granted by the role');

      fixture.becomePersona(DemoPersona.owner);
      await fixture.roles.assignRole(
        memberId: _bruno,
        roleId: 'demo-role-finance-reader',
        assign: false,
      );
      fixture.becomePersona(DemoPersona.member);
      expect(await brunoReads(), isFalse, reason: 'revoked');

      fixture.becomePersona(DemoPersona.owner);
      await fixture.roles.assignRole(
        memberId: _bruno,
        roleId: 'demo-role-finance-reader',
        assign: true,
      );
      final i = fixture.workspaces.workspaces.indexWhere((w) => w.id == 'ws-1');
      final ws = fixture.workspaces.workspaces[i];
      fixture.workspaces.workspaces[i] = ws.copyWith(
        featureFlags: {
          ...ws.featureFlags,
          WorkspaceFeature.customRoles.name: false,
        },
      );
      fixture.becomePersona(DemoPersona.member);
      expect(await brunoReads(), isFalse, reason: 'customRoles is off');
    });

    test(
      'a privacy incident is read with managePrivacy held now, and by '
      'nobody else: not its former holder, a validator or its actor',
      () async {
        final fixture = _as(DemoPersona.owner);
        WorkspaceEvent incident(String id, String actor) => WorkspaceEvent(
          id: id,
          workspaceId: 'ws-1',
          type: EventType.privacyIncident,
          action: EventAction.created,
          actorMemberId: actor,
          subjectMemberId: actor,
          payload: const {'kind': 'lost_device', 'note': 'demo'},
          status: EventStatus.applied,
          createdAt: fixture.seededAt,
        );
        fixture.events.events.addAll([
          incident('demo-incident-bruno', _bruno),
          incident('demo-incident-chiara', _chiara),
        ]);
        // Every member validates incidents under this rule: still no read.
        fixture.events.policies.add(
          const ValidationPolicy(
            workspaceId: 'ws-1',
            eventType: 'privacy_incident',
            requiredCount: 1,
            adminsMayValidate: true,
            eligibleAdminIds: [],
            ownerRequired: false,
            validatorScope: 'members',
          ),
        );
        Future<Set<String>> incidents() async => {
          for (final e in await fixture.events.fetchEvents('ws-1'))
            if (e.type == EventType.privacyIncident) e.id,
        };
        expect(await incidents(), {
          'demo-incident-bruno',
          'demo-incident-chiara',
        }, reason: 'the owner holds managePrivacy');

        fixture.roles.roles.add(
          const WorkspaceRole(
            id: 'demo-role-privacy',
            key: 'privacy_holder',
            names: {'en': 'Privacy'},
            permissions: {WorkspacePermission.managePrivacy},
          ),
        );
        await fixture.roles.assignRole(
          memberId: _bruno,
          roleId: 'demo-role-privacy',
          assign: true,
        );
        fixture.becomePersona(DemoPersona.member);
        expect(
          await incidents(),
          contains('demo-incident-bruno'),
          reason: 'a current holder through a custom role',
        );

        fixture.becomePersona(DemoPersona.owner);
        await fixture.roles.assignRole(
          memberId: _bruno,
          roleId: 'demo-role-privacy',
          assign: false,
        );
        fixture.becomePersona(DemoPersona.member);
        expect(
          await incidents(),
          isEmpty,
          reason: 'a former holder, though actor, subject and validator',
        );
        expect(await fixture.events.fetchEvent('demo-incident-bruno'), isNull);

        fixture.becomePersona(DemoPersona.admin);
        expect(
          await incidents(),
          isEmpty,
          reason: 'an administrator without the right, its own actor',
        );
        expect(
          await fixture.events.fetchDecisions('ws-1', ['demo-incident-chiara']),
          isEmpty,
        );
      },
    );

    test('a decision of a Leipzig request is read by Leipzig\'s members '
        'only, and only in Leipzig', () async {
      final fixture = _as(DemoPersona.owner);
      final leipzig = fixture.secondSpace.events;
      expect(
        await leipzig.fetchDecisions(demoSecondSpaceId, ['de-join-ada']),
        isNotEmpty,
      );
      expect(
        await leipzig.fetchDecisions('ws-1', ['de-join-ada']),
        isEmpty,
        reason: 'asked under another space',
      );

      fixture.becomePersona(DemoPersona.admin);
      expect(
        await leipzig.fetchDecisions(demoSecondSpaceId, ['de-join-ada']),
        isEmpty,
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
