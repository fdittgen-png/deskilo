// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 — the approvals waiting on a member are a section of their own with
// a header a screen reader can jump to, wherever it is shown (the events
// page, or the calendar when the events bell is off).
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/widgets/pending_decisions_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets('the approvals have a named header', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: PendingDecisionsSection(
            pending: [
              WorkspaceEvent(
                id: 'expense-1',
                workspaceId: 'ws-1',
                type: EventType.expense,
                action: EventAction.created,
                status: EventStatus.pending,
                actorMemberId: 'member-2',
                subjectMemberId: 'member-2',
                payload: const {},
                createdAt: kTestNow.subtract(const Duration(minutes: 1)),
              ),
            ],
          ),
        ),
      ),
      overrides: standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(),
      ),
    );
    await tester.pumpAndSettle();
    final node = tester.getSemantics(
      find.text('Waiting for your confirmation'),
    );
    expect(node.flagsCollection.isHeader, isTrue);
    expect(node.label, 'Waiting for your confirmation');
    handle.dispose();
  });
}
