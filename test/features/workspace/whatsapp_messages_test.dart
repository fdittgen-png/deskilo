// SPDX-License-Identifier: 0BSD
//
// Messages on WhatsApp (0106): the opt-in switch in Settings, the
// migration/trigger contract, and the deep links a mirrored message
// carries — /msg/:id opens the conversation, /res/:id the reservation.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pump(
  WidgetTester tester, {
  FakeProfileRepository? profile,
}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..otherMembers.add(const Member(
      id: 'member-2',
      workspaceId: 'ws-1',
      userId: 'user-2',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    ))
    ..memberNotes.add(MemberNote(
      id: 'note-in',
      workspaceId: 'ws-1',
      fromMemberId: 'member-2',
      toMemberId: 'member-1',
      body: 'See you at ten!',
      createdAt: DateTime.utc(2026, 5, 12, 9),
    ));
  final plan = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository()
    ..reservations.add(Reservation(
      id: 'res-link-1',
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: 'member-1',
      startsAt:
          DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1, 9),
      endsAt:
          DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1, 11),
      status: ReservationStatus.reserved,
    ));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        floorPlan: plan,
        reservations: reservations,
        profile: profile,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  test('pins the WhatsApp mirror contract against migration 0106', () {
    final sql = File('supabase/migrations/0106_whatsapp_messages.sql')
        .readAsStringSync();
    expect(sql, contains('add column whatsapp_notes'));
    expect(sql, contains('notify_member_note_whatsapp'));
    expect(sql, contains('/send-whatsapp'));
    expect(sql, contains('after insert on public.member_notes'));
    // The edge function ships with the repo and renders the deep links.
    final fn = File('supabase/functions/send-whatsapp/index.ts')
        .readAsStringSync();
    expect(fn, contains('whatsapp_notes'));
    expect(fn, contains('/msg/'));
    expect(fn, contains('graph.facebook.com'));
  });

  testWidgets(
      'the Settings switch appears once a number is shared and writes '
      'the opt-in through the repository (0106)', (tester) async {
    final profile = FakeProfileRepository(profiles: [
      const Profile(id: 'user-1', whatsapp: '+491701234567'),
    ]);
    await _pump(tester, profile: profile);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final swtch = find.byKey(const ValueKey('whatsapp-notes-switch'));
    await tester.scrollUntilVisible(swtch, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(swtch);
    await tester.pumpAndSettle();
    expect(profile.profiles.single.whatsappNotes, isTrue);

    await tester.tap(swtch);
    await tester.pumpAndSettle();
    expect(profile.profiles.single.whatsappNotes, isFalse);
  });

  testWidgets('no shared number → no switch', (tester) async {
    await _pump(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('whatsapp-notes-switch')), findsNothing);
  });

  testWidgets(
      '/msg/:id (the WhatsApp link target) opens the conversation with '
      'the sender directly', (tester) async {
    await _pump(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go('/msg/note-in');
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('conversation-sheet')), findsOneWidget);
    expect(find.text('See you at ten!', findRichText: true), findsOneWidget);
  });

  testWidgets('/msg with an unknown id lands on the inbox affordance',
      (tester) async {
    await _pump(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go('/msg/gone-note');
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('message-link-inbox')), findsOneWidget);
  });

  testWidgets(
      '/res/:id (a reference link) opens that reservation detail sheet',
      (tester) async {
    await _pump(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go('/res/res-link-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reservation-cancel')), findsOneWidget);
  });

  testWidgets(
      'an UNCONFIGURED server channel warns under the switch instead of '
      'silently promising delivery (#538)', (tester) async {
    final profile = FakeProfileRepository(profiles: [
      const Profile(id: 'user-1', whatsapp: '+491701234567'),
    ]);
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..whatsappMirrorConfigured = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
            workspace: workspace, profile: profile),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final swtch = find.byKey(const ValueKey('whatsapp-notes-switch'));
    await tester.scrollUntilVisible(swtch, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('whatsapp-notes-unconfigured')),
        findsOneWidget);
  });

  testWidgets('a configured channel shows no warning (#538)',
      (tester) async {
    final profile = FakeProfileRepository(profiles: [
      const Profile(id: 'user-1', whatsapp: '+491701234567'),
    ]);
    await _pump(tester, profile: profile);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final swtch = find.byKey(const ValueKey('whatsapp-notes-switch'));
    await tester.scrollUntilVisible(swtch, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('whatsapp-notes-unconfigured')),
        findsNothing);
  });
}
