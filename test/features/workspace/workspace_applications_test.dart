// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: a refusal remains readable and discussable with no active workspace;
// failed sends retain the draft, and switching accounts hides the old thread.
import 'package:deskilo/core/demo/data/workspace_application_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_application.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_applications_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

FakeWorkspaceApplicationRepository fixture() =>
    FakeWorkspaceApplicationRepository()
      ..applications.add(
        WorkspaceApplication(
          id: 'request-one',
          workspaceName: 'A quiet office',
          applicantName: 'Applicant',
          status: 'rejected',
          createdAt: DateTime.utc(2026, 9, 28),
          isApplicant: true,
        ),
      )
      ..messages['request-one'] = [
        ApplicationMessage(
          id: 'message-one',
          authorName: 'Reviewer',
          kind: 'discussion',
          body: 'No desks this month. Please ask about October.',
          createdAt: DateTime.utc(2026, 9, 28, 12),
          isMine: false,
        ),
      ];

Future<void> showApplications(
  WidgetTester tester,
  FakeWorkspaceApplicationRepository repo,
  FakeAuthRepository auth, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...standardTestOverrides(auth: auth, applications: repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const WorkspaceApplicationsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'refusal explanation and applicant reply need no active workspace',
    (tester) async {
      final repo = fixture();
      await showApplications(tester, repo, FakeAuthRepository.signedIn());
      expect(find.textContaining('Refused'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('application-request-one')));
      await tester.pumpAndSettle();
      expect(
        find.text('No desks this month. Please ask about October.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('application-reply')),
        ' Is October available? ',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(repo.sent, [(id: 'request-one', body: 'Is October available?')]);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('application-reply')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed reply keeps its draft and another account cannot see the thread',
    (tester) async {
      final repo = fixture()..failSend = true;
      final auth = FakeAuthRepository.signedIn();
      await showApplications(tester, repo, auth);
      await tester.tap(find.byKey(const ValueKey('application-request-one')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('application-reply')),
        'Please reconsider.',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('application-reply')))
            .controller!
            .text,
        'Please reconsider.',
      );
      expect(repo.sent, isEmpty);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(
        find.text('No desks this month. Please ask about October.'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('application-reply')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('320px and a visible keyboard keep the discussion usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await showApplications(
      tester,
      fixture(),
      FakeAuthRepository.signedIn(),
      scale: 1.5,
    );
    await tester.tap(find.byKey(const ValueKey('application-request-one')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('application-reply')),
      'Can we discuss another date?',
    );
    expect(find.byTooltip('Send').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
