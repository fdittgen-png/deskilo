// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — the storyboard review a person actually uses.
//
// Invariant: the preview shows every frame with its provenance, draws
// the recreated illustrations through the real renderer (labelled for
// screen readers with the frame's alt text), and each affordance —
// include, approve, move — reports the next revision through onChanged;
// moving an outcome before its command is refused with a message and no
// new revision. It builds in all five languages and at 2x text.
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_preview.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/real_async.dart';
import '../fixtures/recording_fixtures.dart';

Storyboard _storyboard(String code) => buildStoryboard(
  decodeRecordingText(fixtureText(BookingJourney.planConfirmed.file))
      .recording!,
  lookupAppLocalizations(Locale(code)),
);

Widget _app(
  Storyboard sb,
  ValueChanged<Storyboard> onChanged, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 1200),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: StoryboardPreview(storyboard: sb, onChanged: onChanged),
    ),
  ),
);

void main() {
  testWidgets('illustrations draw and edits report the next revision', (
    tester,
  ) async {
    final sb = _storyboard('en');
    final l = lookupAppLocalizations(const Locale('en'));
    Storyboard? changed;
    await tester.pumpWidget(_app(sb, (s) => changed = s));
    await tester.runAsync(
      () => untilReal(() async {
        await tester.pump();
        return find
            .bySemanticsLabel(RegExp(RegExp.escape(sb.frames.first.altText)))
            .evaluate()
            .isNotEmpty;
      }, what: 'the first illustration'),
    );
    await tester.pump();
    expect(find.text(l.taskExportStoryboardSourceScene), findsWidgets);

    // Approve the first frame's illustration.
    final firstTile = find.byKey(const ValueKey('storyboard-frame-1'));
    await tester.tap(
      find.descendant(
        of: firstTile,
        matching: find.text(l.taskExportStoryboardApprove),
      ),
    );
    expect(changed!.revision, sb.revision + 1);
    expect(changed!.frames.first.approved, isTrue);

    // Leave it out.
    await tester.tap(
      find.descendant(
        of: firstTile,
        matching: find.text(l.taskExportStoryboardInclude),
      ),
    );
    expect(changed!.frames.first.omitted, isTrue);

    // Move frame 1 down.
    await tester.tap(
      find.descendant(
        of: firstTile,
        matching: find.byTooltip(l.taskExportStoryboardMoveDown),
      ),
    );
    expect(changed!.frames[1].stepSeq, 1);
  });

  testWidgets('an outcome cannot be moved before its command', (tester) async {
    final sb = _storyboard('en');
    final l = lookupAppLocalizations(const Locale('en'));
    final outcome = sb.frames.firstWhere((f) => f.attemptSeq != null);
    var calls = 0;
    await tester.pumpWidget(_app(sb, (_) => calls++));
    final tile = find.byKey(ValueKey('storyboard-frame-${outcome.stepSeq}'));
    await tester.scrollUntilVisible(tile, 300);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: tile,
        matching: find.byTooltip(l.taskExportStoryboardMoveUp),
      ),
    );
    await tester.pump();
    expect(calls, 0);
    expect(find.text(l.taskExportStoryboardOrderRefused), findsOneWidget);
  });

  for (final code in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$code at 2x text builds without overflow', (tester) async {
      await tester.pumpWidget(
        _app(_storyboard(code), (_) {}, locale: Locale(code), textScale: 2),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final l = lookupAppLocalizations(Locale(code));
      expect(find.text(l.taskExportStoryboardInclude), findsWidgets);
    });
  }
}
