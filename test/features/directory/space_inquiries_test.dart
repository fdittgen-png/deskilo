// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1824 — inquiries: an outside person writes to a SPACE, not to one
// admin's private inbox.
//
// The invariants: the person sees who will read the message (the host
// roster) BEFORE writing, and a space with nobody answering offers no
// field to write in; the message opens the inquiry's thread. The hosts
// find it in the space's Inquiries view — shown to owners and admins
// while the workspace has `spaceInquiries` on — and can close it.
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/messages_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const origin = 'https://demo.invalid';

Future<void> pump(
  WidgetTester tester,
  Widget home, {
  required FakeMessengerRepository messenger,
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: standardTestOverrides(
        messenger: messenger,
        workspace: workspace,
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The app's router keeps the auth stream alive; here a watcher
        // does, so "signed in" is known before the first tap.
        home: Consumer(
          builder: (context, ref, _) {
            ref.watch(authStateProvider);
            return home;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const space = PublicWorkspace('ws-remote', origin, 'key', {
  'name': 'La Serre',
  'host_type': 'company',
});

void main() {
  testWidgets('the roster is shown before writing, and the inquiry opens '
      'its thread', (tester) async {
    final messenger = FakeMessengerRepository()
      ..roster['ws-remote'] = const [
        HostRosterEntry(name: 'Alice', role: 'owner'),
        HostRosterEntry(name: 'Bruno', role: 'admin'),
      ];
    await pump(
      tester,
      const PublicWorkspaceView(workspace: space),
      messenger: messenger,
    );
    await tester.tap(find.byKey(const ValueKey('write-to-hosts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inquiry-sheet')), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('inquiry-body')),
      'Do you have a day pass?',
    );
    await tester.tap(find.byKey(const ValueKey('inquiry-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-thread')), findsOneWidget);
    expect(find.text('Do you have a day pass?'), findsOneWidget);
    expect(find.text('Your inquiry to La Serre'), findsOneWidget);
    expect(
      messenger.inboxRows.single['context_kind'],
      MessageContextKind.inquiryOut.wire,
    );
  });

  testWidgets('a space nobody answers offers nothing to write in', (
    tester,
  ) async {
    await pump(
      tester,
      const PublicWorkspaceView(workspace: space),
      messenger: FakeMessengerRepository(),
    );
    await tester.tap(find.byKey(const ValueKey('write-to-hosts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inquiry-no-hosts')), findsOneWidget);
    expect(find.byKey(const ValueKey('inquiry-body')), findsNothing);
  });

  testWidgets('the preview of my own page offers no inquiry', (tester) async {
    await pump(
      tester,
      const PublicWorkspaceView(workspace: space, preview: true),
      messenger: FakeMessengerRepository(),
    );
    expect(find.byKey(const ValueKey('write-to-hosts')), findsNothing);
  });

  group('the space\'s Inquiries view', () {
    FakeMessengerRepository hosted() => FakeMessengerRepository()
      ..inquiries.add(
        InquirySummary(
          id: 'inq-1',
          workspaceId: 'ws-1',
          requesterName: 'Chloé',
          lastBody: 'Is the meeting room free on Friday?',
          lastAt: DateTime.utc(2026, 7, 15, 8),
          unread: 1,
        ),
      )
      ..threads[FakeMessengerRepository.threadKey(
        MessageContextKind.inquiryIn,
        'inq-1',
      )] = [
        ContextMessage(
          id: 'q1',
          kind: MessageKind.inquiryMessage,
          body: 'Is the meeting room free on Friday?',
          mine: false,
          authorName: 'Chloé',
          createdAt: DateTime.utc(2026, 7, 15, 8),
        ),
      ];

    const on = {'publicListings': true, 'spaceInquiries': true};

    testWidgets('a host opens an inquiry, answers and closes it', (
      tester,
    ) async {
      final messenger = hosted();
      await pump(
        tester,
        const MessagesScreen(),
        messenger: messenger,
        workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: on),
      );
      await tester.tap(find.byKey(const ValueKey('space-inquiries-entry')));
      await tester.pumpAndSettle();
      expect(find.text('From Chloé'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('space-inquiry-inq-1')));
      await tester.pumpAndSettle();
      expect(find.text('Is the meeting room free on Friday?'), findsOneWidget);
      expect(messenger.reads, ['inq-1']);
      await tester.enterText(
        find.byKey(const ValueKey('context-composer')),
        'Yes, from 9.',
      );
      await tester.tap(find.byKey(const ValueKey('context-send')));
      await tester.pumpAndSettle();
      expect(find.text('Yes, from 9.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inquiry-close')));
      await tester.pumpAndSettle();
      expect(messenger.closed, ['inq-1']);
    });

    testWidgets('off, or for a plain member, there is no Inquiries view', (
      tester,
    ) async {
      await pump(
        tester,
        const MessagesScreen(),
        messenger: hosted(),
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'publicListings': true, 'spaceInquiries': false},
        ),
      );
      expect(find.byKey(const ValueKey('space-inquiries-entry')), findsNothing);

      final member = FakeWorkspaceRepository.withWorkspace(featureFlags: on)
        ..myMember = const Member(
          id: 'member-1',
          workspaceId: 'ws-1',
          userId: 'user-1',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.active,
        );
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(
        tester,
        const MessagesScreen(),
        messenger: hosted(),
        workspace: member,
      );
      expect(find.byKey(const ValueKey('space-inquiries-entry')), findsNothing);
    });
  });
}
