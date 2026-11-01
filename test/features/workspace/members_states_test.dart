// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3061 — the members list's states: loading is not empty; a failed or
// refused read is never an empty roster and Try again repeats the same read;
// a refresh keeps the rows; the broadcast the screen owns keeps what was
// typed when it fails and goes out once however often it is activated.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/members_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import '../../helpers/read_probe.dart';

final _en = AppLocalizationsEn();
const _retry = ValueKey('inline-banner-action');

/// A workspace whose broadcast the test controls.
class _Workspace extends FakeWorkspaceRepository {
  _Workspace() : super.withWorkspace();

  final List<String> sent = [];
  Completer<void>? hold;
  Exception? failure;

  @override
  Future<void> sendMemberNote(
    String workspaceId, {
    required String? toMemberId,
    required String body,
  }) async {
    sent.add(body);
    await hold?.future;
    if (failure case final error?) throw error;
  }
}

const _ana = Member(
  id: 'member-2',
  workspaceId: 'ws-1',
  userId: 'user-2',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

Future<(ReadProbe<List<Member>>, _Workspace)> _pump(
  WidgetTester tester,
) async {
  final probe = ReadProbe<List<Member>>();
  final workspace = _Workspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
  await pumpStateScreen(
    tester,
    const MembersScreen(),
    overrides: [
      ...standardTestOverrides(workspace: workspace),
      workspaceMembersProvider.overrideWith((ref) => probe()),
    ],
  );
  await tester.pump();
  return (probe, workspace);
}

void main() {
  testWidgets('loading is not empty: a spinner, then the roster', (
    tester,
  ) async {
    final (probe, _) = await _pump(tester);
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text(_en.directoryEmpty), findsNothing);

    probe.answer([_ana]);
    await tester.pump();
    expect(find.byType(LoadingView), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('a successful empty roster says so', (tester) async {
    final (probe, _) = await _pump(tester);
    probe.answer(const []);
    await tester.pump();
    expect(find.byKey(const ValueKey('members-empty')), findsOneWidget);
    expect(find.text(_en.directoryEmpty), findsOneWidget);
  });

  testWidgets('a connectivity failure is not an empty roster; Try again asks '
      'the same read once more', (tester) async {
    final (probe, _) = await _pump(tester);
    probe.fail(const SocketException('no route'));
    await tester.pump();
    expect(find.text(_en.readStateOffline), findsOneWidget);
    expect(find.text(_en.directoryEmpty), findsNothing);
    expect(find.textContaining('SocketException'), findsNothing);

    await tester.tap(find.byKey(_retry));
    await tester.pump();
    expect(probe.calls, 2);
    probe.answer([_ana]);
    await tester.pump();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text(_en.readStateOffline), findsNothing);
  });

  testWidgets('a refused read says access is missing, not that nobody is '
      'here', (tester) async {
    final (probe, _) = await _pump(tester);
    probe.fail(const PostgrestException(message: 'rls', code: '42501'));
    await tester.pump();
    expect(find.text(_en.readStateDenied), findsOneWidget);
    expect(find.text(_en.directoryEmpty), findsNothing);
    expect(find.textContaining('rls'), findsNothing);
  });

  testWidgets('a refresh keeps the roster with a thin progress line', (
    tester,
  ) async {
    final (probe, _) = await _pump(tester);
    probe.answer([_ana]);
    await tester.pump();
    ProviderScope.containerOf(
      tester.element(find.byType(MembersScreen)),
    ).invalidate(workspaceMembersProvider);
    await tester.pump();
    expect(probe.calls, 2);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.byKey(const ValueKey('read-refreshing')), findsOneWidget);
    expect(find.byType(LoadingView), findsNothing);
    probe.answer([_ana]);
    await tester.pump();
    expect(find.byKey(const ValueKey('read-refreshing')), findsNothing);
  });

  testWidgets('a failed broadcast keeps what was typed; activated twice while '
      'it is in flight it goes out once', (tester) async {
    final (probe, workspace) = await _pump(tester);
    probe.answer([_ana]);
    await tester.pump();
    workspace
      ..hold = Completer<void>()
      ..failure = Exception('server said no');

    await tester.tap(find.byKey(const ValueKey('members-notify-admins')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(const ValueKey('member-note-body')),
      'Printer is out of toner.',
    );
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('member-note-send')), warnIfMissed: false);
    await tester.pump();
    expect(workspace.sent, hasLength(1), reason: 'one effective command');

    workspace.hold!.complete();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('member-note-body')))
          .controller!
          .text,
      'Printer is out of toner.',
      reason: 'the input survives the failure',
    );
    expect(find.text(_en.workspaceGenericError), findsOneWidget);
    expect(find.textContaining('server said no'), findsNothing);
  });
}
