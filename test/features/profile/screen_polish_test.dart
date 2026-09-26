// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The three screen-polish findings of the 2026-09-13 screenshot review.
// Each one is the same kind of defect: the screen said a true thing in
// a form that contradicted the form the screen next to it used.
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/profile/presentation/widgets/pair_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'backend_settings_test.dart' show pumpServerScreen;

void main() {
  group('#1194 — the Server screen', () {
    testWidgets('the connection test runs the full width, like every '
        'other button on the screen', (tester) async {
      await pumpServerScreen(tester);
      // #1651 — the test button belongs to a candidate; the operator
      // mode always has one on the form.
      await tester.tap(find.byKey(const ValueKey('backend-mode-operator')));
      await tester.pumpAndSettle();
      final test = find.byKey(const ValueKey('backend-test'));
      final save = find.byKey(const ValueKey('backend-save'));
      expect(test, findsOneWidget);
      expect(tester.getSize(test).width,
          closeTo(tester.getSize(save).width, 1),
          reason: 'a half-width button broke the column\'s right edge on '
              'the one row that matters most');
    });

    testWidgets('the how-to row carries ONE question mark, not two',
        (tester) async {
      await pumpServerScreen(tester);
      final row = find.byKey(const ValueKey('backend-howto'));
      expect(row, findsOneWidget);
      final leading = tester.widget<ExpansionTile>(row).leading;
      expect(leading, isA<Icon>());
      expect((leading! as Icon).icon, isNot(Icons.help_outline),
          reason: 'the LEADING icon says what the row is ABOUT; the help '
              'dot beside it is the help. Two help glyphs on one line, '
              'meaning different things, is the bug.');
    });
  });

  group('#1188 — a paired workspace row', () {
    testWidgets('puts the role in a chip, as an unpaired one does',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: WorkspacePairCard(
                dev: _workspace,
                prod: _workspace.copyWith(id: 'ws-prod', environment: 'prod'),
                roleLabel: 'Owner',
                activeId: 'ws-dev',
                onSelect: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(Chip, 'Owner'),
        findsOneWidget,
        reason: 'two adjacent rows styled the same fact two ways — one '
            'in a chip, one in plain text',
      );
    });
  });
}

const _workspace = Workspace(
  id: 'ws-dev',
  name: 'Pezenas Cowork',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'GOODCODE22',
  environment: 'dev',
);
