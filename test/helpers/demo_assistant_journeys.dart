// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3962 — the assistants of the reference business, through the app's own
// providers: what the person may offer, the request an assistant left for
// confirmation, the answer, and what it leaves in the Demo's events and
// bookings. Shared by the scenario checklist and the assistants test.
import 'package:deskilo/app/webmcp_writes.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:deskilo/features/mcp/providers/mcp_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The owner of the reference business, signed in on a session of the Demo.
Future<T> withOwnerSession<T>(
  Future<T> Function(DemoFixture fixture, ProviderContainer container) use,
) async {
  final fixture = DemoFixture.build()..becomePersona(DemoPersona.owner);
  final workspace = fixture.workspaces.workspaces.firstWhere(
    (w) => w.id == 'ws-1',
  );
  final container = ProviderContainer(
    overrides: [
      ...demoOverrides(fixture),
      currentWorkspaceProvider.overrideWith((ref) async => workspace),
    ],
  );
  try {
    // The signed-in account is read through a stream: it needs a listener.
    container.listen(authStateProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await container.read(currentWorkspaceProvider.future);
    await container.read(myMemberProvider.future);
    return await use(fixture, container);
  } finally {
    container.dispose();
  }
}

const waitingConfirmation = 'demo-confirm-room';
const confirmedConfirmation = 'demo-confirm-quota';
const refusedConfirmation = 'demo-confirm-expense';
const roomRequestEvent = 'demo-room-request-event';
const roomRequestReservation = 'demo-room-request';
const assistantId = 'demo-assistant';

Reservation roomRequest(DemoFixture f) => f.reservations.reservations
    .firstWhere((r) => r.id == roomRequestReservation);

WorkspaceEvent eventOf(DemoFixture f, String id) =>
    f.events.events.firstWhere((e) => e.id == id);

Future<ActionConfirmation> confirmationOf(ProviderContainer c, String id) =>
    c.read(actionConfirmationProvider(id).future);

/// The page of the assistants: eligible, one assistant connected with its
/// operations, and the three requests it left.
Future<bool> assistantsPageHolds(ProviderContainer c) async {
  final caps = await c.read(myDatabaseCapabilitiesProvider.future);
  final connections = await c.read(myMcpConnectionsProvider.future);
  final waiting = await confirmationOf(c, waitingConfirmation);
  final confirmed = await confirmationOf(c, confirmedConfirmation);
  final refused = await confirmationOf(c, refusedConfirmation);
  final one = connections.singleOrNull;
  return caps.eligibility == McpEligibility.eligible &&
      one != null &&
      one.clientId == assistantId &&
      one.workspaces.single.id == 'ws-1' &&
      one.workspaces.single.operations.contains('respond_to_validation') &&
      waiting.status == ConfirmationStatus.pending &&
      confirmed.status == ConfirmationStatus.acknowledged &&
      refused.status == ConfirmationStatus.declined;
}

/// The owner confirms the waiting request: the Demo's event is decided, the
/// booking it held stays on the plan, and the request reads as done. The
/// event, the room's booking and the member's bookings tell one story.
Future<bool> confirmRoomRequestJourney() => withOwnerSession((f, c) async {
  if (!await assistantsPageHolds(c)) return false;
  final before = roomRequest(f);
  final waiting = await confirmationOf(c, waitingConfirmation);
  final answer = await c
      .read(confirmationAnswersProvider)
      .answer(waiting, accept: true);
  final after = roomRequest(f);
  final mine = f.reservations.reservations
      .where((r) => r.memberId == after.memberId && r.id == after.id)
      .length;
  // The screen reads it again after an answer, as the page does.
  c.invalidate(actionConfirmationProvider(waitingConfirmation));
  final checks = {
    'answer': answer == ConfirmationStatus.acknowledged,
    'event': eventOf(f, roomRequestEvent).status == EventStatus.confirmed,
    'held before': before.status == ReservationStatus.reserved,
    'held after': after.status == ReservationStatus.reserved,
    'same room': after.officeId == before.officeId,
    'member bookings': mine == 1,
    'request done':
        (await confirmationOf(c, waitingConfirmation)).status ==
        ConfirmationStatus.acknowledged,
  };
  final failed = [
    for (final e in checks.entries)
      if (!e.value) e.key,
  ];
  if (failed.isNotEmpty) throw StateError('failed: $failed');
  return true;
});

/// A booking made from the page's assistant (the web tools): Thursday
/// morning of the Demo's week in the meeting room, as the page books it.
Future<bool> webAssistantBooksJourney() => withOwnerSession((f, c) async {
  final day = f.seededAt.add(
    Duration(days: (DateTime.thursday - f.seededAt.weekday + 7) % 7 + 7),
  );
  final date =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  final before = f.reservations.reservations.length;
  final out = await webMcpWriteRunners['create_reservation']!(
    c.read(_refProvider),
    {
      'request_id': '6f1c2a3e-0000-4000-8000-000000000001',
      'office_id': 'demo-office-meeting',
      'date': date,
      'period': 'morning',
    },
  );
  final booked = f.reservations.reservations
      .where(
        (r) =>
            r.officeId == 'demo-office-meeting' &&
            r.startsAt.year == day.year &&
            r.startsAt.month == day.month &&
            r.startsAt.day == day.day,
      )
      .toList();
  return out['reservation_id'] != null &&
      f.reservations.reservations.length == before + 1 &&
      booked.any((r) => r.id == out['reservation_id']);
});

final _refProvider = Provider<Ref>((ref) => ref);
