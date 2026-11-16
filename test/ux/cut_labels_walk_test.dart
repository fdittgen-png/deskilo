// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4078 — the cut-text walk over the places the review found: no text of the
// page is painted past its last line (an ellipsis, a clip) at 320 and 390 px
// wide with text at 1.0 and 1.3.
import 'package:deskilo/core/i18n/workspace_locale_fields.dart';
import 'package:deskilo/core/theme/app_spacing.dart';
import 'package:deskilo/core/ui/edge_fade_scroll.dart';
import 'package:deskilo/features/me/presentation/me_home_tab.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/money/presentation/widgets/report_template_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/me/me_app.dart';
import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';
import 'experience_guards.dart' show loadRealFonts;

/// Every text on screen that did not paint all of its lines.
List<String> _cutTexts() => [
  for (final e in find.byType(RichText).evaluate())
    if (e.renderObject case final RenderParagraph box
        when box.hasSize && box.attached && box.didExceedMaxLines)
      '"${box.text.toPlainText()}" in ${box.size.width}',
];

void main() {
  // Measured in the app's own font, not the test font.
  setUpAll(loadRealFonts);

  for (final width in const [320.0, 390.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
        'Me at ${width.toInt()} px and text $scale: no text is cut',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpMeApp(tester, size: Size(width, 844));
          await tester.pump(const Duration(seconds: 1));
          expect(_cutTexts(), isEmpty);
        },
      );

      testWidgets('the legacy Home at ${width.toInt()} px and text $scale: '
          'no text is cut', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(
          tester,
          const MeHomeTab(),
          size: Size(width, 844),
          overrides: [
            ...standardTestOverrides(),
            personalShellEnabledProvider.overrideWithValue(false),
          ],
        );
        await tester.pump(const Duration(seconds: 1));
        expect(_cutTexts(), isEmpty);
      });

      testWidgets('the currency field at ${width.toInt()} px and text $scale: '
          'its helper is whole', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final currency = TextEditingController(text: 'EUR');
        final timezone = TextEditingController(text: 'Europe/Paris');
        addTearDown(currency.dispose);
        addTearDown(timezone.dispose);
        await pumpApp(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: WorkspaceLocaleFields(
                currency: currency,
                timezone: timezone,
                enabled: true,
                onTimezonePicked: (_) {},
              ),
            ),
          ),
          size: Size(width, 844),
          overrides: standardTestOverrides(),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text(
            'Defaults from the country — override if your community bills in '
            'another currency.',
          ),
          findsOneWidget,
        );
        expect(_cutTexts(), isEmpty);
      });

      testWidgets('the report editor\'s chips at ${width.toInt()} px and text '
          '$scale: no chip\'s words are cut, and the row scrolls to its last chip', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(
          tester,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ReportTemplateLanguageChips(
                  selected: 'fr',
                  overridden: (lang) => lang == 'fr',
                  canClear: true,
                  onSelect: (_) {},
                  onClear: () {},
                ),
                ReportTemplateDocChips(
                  docs: const [
                    ('invoice', 'Invoice'),
                    ('credit_note', 'Credit note'),
                    ('r1', 'Reminder 1'),
                    ('r2', 'Reminder 2'),
                    ('r3', 'Final notice'),
                    ('purchase_order', 'Purchase order'),
                  ],
                  selected: 'invoice',
                  onSelect: (_) {},
                ),
              ],
            ),
          ),
          size: Size(width, 844),
          overrides: standardTestOverrides(),
        );
        await tester.pump(const Duration(seconds: 1));
        // #4078, decided: the chips stay ONE row that scrolls sideways, its
        // edge faded where more follows. Wrapping them took the editor's
        // height on a phone (four rows of chips above the page). What must
        // hold is that no chip's own words are cut and every chip is reached.
        final chips = find.byType(ChoiceChip);
        expect(chips, findsAtLeastNWidgets(8));
        expect(find.byType(EdgeFadeScroll), findsNWidgets(2));
        expect(_cutTexts(), isEmpty);
        // The selected document is in view when the editor opens.
        final selected = tester.getRect(
          find.byKey(const ValueKey('invoice-template-doc-invoice')),
        );
        expect(selected.left, greaterThanOrEqualTo(0));
        expect(selected.right, lessThanOrEqualTo(width));
        // The last document is reached by scrolling the row.
        final last = find.byKey(
          const ValueKey('invoice-template-doc-purchase_order'),
        );
        await tester.ensureVisible(last);
        await tester.pump(const Duration(milliseconds: 300));
        final reached = tester.getRect(last);
        expect(reached.left, greaterThanOrEqualTo(0));
        expect(reached.right, lessThanOrEqualTo(width));
        expect(_cutTexts(), isEmpty);
      });
    }
  }
}
