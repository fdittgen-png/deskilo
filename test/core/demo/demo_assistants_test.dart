// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3962 — the assistants of the reference business: one connected with what
// it may do, a request waiting for its person and two answered; confirming
// decides the event the request was about, refusing changes nothing, and
// revoking the connection closes what still waits. Nothing leaves the device.
import 'package:deskilo/core/demo/seed/demo_flags.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:deskilo/features/mcp/providers/mcp_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_assistant_journeys.dart';

void main() {
  test('both assistant features are on in the reference business', () {
    expect(demoFeaturesLeftOff, isNot(contains(WorkspaceFeature.mcpAccess)));
    expect(demoFeaturesLeftOff, isNot(contains(WorkspaceFeature.webMcp)));
  });

  test(
    'the Demo opens with a connected assistant and three requests',
    () async {
      await withOwnerSession((f, c) async {
        expect(await assistantsPageHolds(c), isTrue);
        final waiting = await confirmationOf(c, waitingConfirmation);
        expect(waiting.operation, 'respond_to_validation');
        expect(waiting.arguments['event_id'], roomRequestEvent);
        expect(waiting.expiresAt!.isAfter(f.seededAt), isTrue);
        // The request is about a booking that is held until it is decided.
        expect(eventOf(f, roomRequestEvent).status, EventStatus.pending);
        expect(roomRequest(f).status, ReservationStatus.reserved);
        // No real endpoint is shown to anybody.
        final text = '${await c.read(myMcpConnectionsProvider.future)}$waiting';
        expect(text.contains('http'), isFalse);
      });
    },
  );

  test('confirming decides the event and the figures agree', () async {
    expect(await confirmRoomRequestJourney(), isTrue);
  });

  test(
    'refusing changes nothing and a second answer changes nothing',
    () async {
      await withOwnerSession((f, c) async {
        final waiting = await confirmationOf(c, waitingConfirmation);
        final answers = c.read(confirmationAnswersProvider);
        expect(
          await answers.answer(waiting, accept: false),
          ConfirmationStatus.declined,
        );
        expect(eventOf(f, roomRequestEvent).status, EventStatus.pending);
        expect(roomRequest(f).status, ReservationStatus.reserved);
        expect(
          await answers.answer(waiting, accept: true),
          ConfirmationStatus.declined,
          reason: 'an answered request is not answered twice',
        );
        expect(eventOf(f, roomRequestEvent).status, EventStatus.pending);
      });
    },
  );

  test('revoking the connection removes it and closes what waits', () async {
    await withOwnerSession((f, c) async {
      final connection = (await c.read(myMcpConnectionsProvider.future)).single;
      final out = await c.read(assistantAccessProvider).disconnect(connection);
      expect(out.workspaces, contains('ws-1'));
      c.invalidate(myMcpConnectionsProvider);
      expect(await c.read(myMcpConnectionsProvider.future), isEmpty);
      c.invalidate(actionConfirmationProvider(waitingConfirmation));
      expect(
        (await confirmationOf(c, waitingConfirmation)).status,
        ConfirmationStatus.revoked,
      );
      // An answered request keeps its answer.
      expect(
        (await confirmationOf(c, confirmedConfirmation)).status,
        ConfirmationStatus.acknowledged,
      );
      expect(eventOf(f, roomRequestEvent).status, EventStatus.pending);
    });
  });

  test(
    'connecting a new assistant offers the workspace and its operations',
    () async {
      await withOwnerSession((f, c) async {
        final options = await c.read(mcpConnectionRepositoryProvider).options();
        expect(options.eligible, isTrue);
        expect(options.workspaces.single.id, 'ws-1');
        expect(options.workspaces.single.operations, isNotEmpty);
      });
    },
  );

  test(
    'the page assistant books the meeting room on a Thursday morning',
    () async {
      expect(await webAssistantBooksJourney(), isTrue);
    },
  );
}
