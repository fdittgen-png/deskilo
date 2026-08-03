// SPDX-License-Identifier: 0BSD
//
// Push-driven freshness (#413, migration 0080): a DB change event
// invalidates the cached providers and the UI repaints WITHOUT any user
// action — no restart, no pull-to-refresh, on every device including
// the one that made the change. The FakeRealtimeSync stands in for the
// Supabase channel; emitting a table name is what a postgres_changes
// callback does.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_realtime_sync.dart';
import '../helpers/mock_providers.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';

void main() {
  testWidgets(
      'a members-table change appears in the directory with NO user '
      'action — the push IS the refresh', (tester) async {
    final realtime = FakeRealtimeSync();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo'};
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: workspace,
          realtime: realtime,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(ShellBottomBar), matching: find.text('Members')));
    await tester.pumpAndSettle();

    expect(find.text('Ana Lima'), findsNothing);
    expect(realtime.watched, contains('ws-1'),
        reason: 'the shell subscribes for the active workspace');

    // Another device adds Ana. The DB emits; nobody touches this app.
    workspace
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
      ..otherMembers.add(const Member(
        id: 'member-2',
        workspaceId: 'ws-1',
        userId: 'user-2',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ));
    realtime
      ..emit('members')
      ..emit('members'); // burst: coalesced by the debounce
    await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Ana Lima'), findsOneWidget);
  });

  testWidgets('a profiles change refreshes the directory too',
      (tester) async {
    final realtime = FakeRealtimeSync();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo'};
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: workspace,
          realtime: realtime,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(ShellBottomBar), matching: find.text('Members')));
    await tester.pumpAndSettle();

    workspace.memberNames = {'member-1': 'Florian'};
    realtime.emit('profiles');
    await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Florian'), findsOneWidget);
  });
}
