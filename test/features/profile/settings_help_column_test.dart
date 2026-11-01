// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3215 — on Settings the help symbols of the rows share ONE x position, at a
// phone and a desktop width, in the languages with the longest labels: a
// switch row, a value row and a row with no trailing widget all line up, the
// symbol is reachable, and no label overflows.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/help/help_dot.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/settings_sections.dart';

void main() {
  for (final width in [360.0, 1192.0]) {
    for (final locale in ['fr', 'de', 'it', 'es']) {
      testWidgets('$locale at ${width.toInt()} dp: Settings has one help column',
          (tester) async {
        tester.view.physicalSize = Size(width, 4800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final workspace = FakeWorkspaceRepository.withWorkspace()
          ..myMember = const Member(
            id: 'member-1',
            workspaceId: 'ws-1',
            userId: 'user-1',
            isAdmin: false,
            isOwner: false,
            status: MemberStatus.active,
          );
        await tester.pumpWidget(
          ProviderScope(
            overrides: standardTestOverrides(
              workspace: workspace,
              deviceLocale: Locale(locale),
            ),
            child: const DeskiloApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        await openSettingsSection(tester, 'advanced');
        final front = find.byKey(const ValueKey('settings-front-camera'));
        await tester.ensureVisible(front);
        await tester.pump(const Duration(milliseconds: 300));

        final dots = find.byType(HelpDot).evaluate().length;
        expect(dots, greaterThanOrEqualTo(4));
        final xs = [
          for (final e in find.byType(HelpDot).evaluate())
            tester.getRect(find.byWidget(e.widget)).left,
        ];
        for (final x in xs) {
          expect(x, closeTo(xs.first, 0.5));
        }
        // A switch row and a row with a value under its title are among them.
        expect(
          find.descendant(of: front, matching: find.byType(HelpDot)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('settings-profile-status-title')),
            matching: find.byType(HelpDot),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
