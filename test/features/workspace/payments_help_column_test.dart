// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3215 — in Payments & billing the help symbols (reminder rules, billing
// schedule) share ONE x position, whatever follows the row (a chevron or
// nothing), at a phone and a desktop width, in the longest-label languages.
import 'package:deskilo/core/help/help_dot.dart';
import 'package:deskilo/core/ui/help_row.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/screens/workspace_settings_screen.dart';

void main() {
  for (final width in [360.0, 1192.0]) {
    for (final locale in ['fr', 'de', 'it', 'es']) {
      testWidgets('$locale at ${width.toInt()} dp: Payments has one help column',
          (tester) async {
        await pumpWorkspaceSettings(
          tester,
          size: Size(width, 6000),
          deviceLocale: Locale(locale),
          repository: FakeWorkspaceRepository.withWorkspace(featureFlags: {
            for (final f in [
              WorkspaceFeature.moneyTab,
              WorkspaceFeature.invoicing,
              WorkspaceFeature.subscriptionInvoices,
              WorkspaceFeature.configurableSettings,
            ])
              f.name: true,
          }),
        );
        final group = find.byKey(const ValueKey('workspace-group-payments'));
        final dots = find.descendant(of: group, matching: find.byType(HelpDot));
        expect(dots, findsNWidgets(2));
        final xs = [
          for (final e in dots.evaluate())
            tester.getRect(find.byWidget(e.widget)).left,
        ];
        expect(xs[1], closeTo(xs[0], 0.5));
        // The chevron rows line up with each other too.
        final a = tester.getRect(find.descendant(
            of: find.byKey(const Key('workspaceSettingsPaymentMethods')),
            matching: find.byIcon(Icons.chevron_right)));
        final b = tester.getRect(find.descendant(
            of: find.byKey(const Key('workspaceSettingsLegalIdentity')),
            matching: find.byIcon(Icons.chevron_right)));
        expect(a.right, closeTo(b.right, 0.5));
        // The symbol sits one trailing slot before that column.
        final dot = tester.getRect(dots.first);
        expect(dot.right, closeTo(a.right - HelpRow.trailingSlotWidth, 0.5));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
