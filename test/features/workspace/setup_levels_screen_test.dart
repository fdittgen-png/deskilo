// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — the levels screen: nothing changes before the owner answers; an
// answer sets each process's level with its reason and applying writes
// exactly the planned change; switching anything off asks first, and a
// "no" writes nothing.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/setup_level_change.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/feature_copy.dart';
import 'package:deskilo/features/workspace/presentation/feature_names.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_levels_screen.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<FakeWorkspaceRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeWorkspaceRepository.withWorkspace();
  await pumpApp(
    tester,
    const SetupLevelsScreen(),
    overrides: standardTestOverrides(workspace: repo),
  );
  await tester.pumpAndSettle();
  for (final (key, child) in [
    ('setup-questions-money', 'setup-question-issue_invoices'),
    ('setup-questions-operations', 'setup-question-door_tablet'),
    ('setup-choices-advanced', 'setup-level-bookings'),
  ]) {
    if (find.byKey(ValueKey(child)).evaluate().isEmpty) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  return repo;
}

SetupLevelChange _planFor(FakeWorkspaceRepository repo, SetupLevelVector v) {
  final stored = resolveEnabledFeatures(repo.workspaces.first.featureFlags);
  // #3300 — the screen plans for the space's country.
  final country = repo.workspaces.first.countryCode;
  final current = currentSetupLevels(stored, country: country);
  return planSetupLevels(
    stored: stored,
    current: current,
    chosen: {...current, ...v},
    country: country,
  );
}

void main() {
  testWidgets('answering a question preserves deliberate levels until reset', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('setup-preset-complet')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final before = tester
        .widget<DropdownButton<String>>(
          find.byKey(const ValueKey('setup-level-bookings')),
        )
        .value;
    await tester.tap(
      find.byKey(const ValueKey('setup-question-approve_bookings')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('setup-level-bookings')),
          )
          .value,
      before,
    );
    expect(find.byKey(const ValueKey('setup-choices-reset')), findsOneWidget);
  });

  testWidgets('before an answer, nothing changes', (tester) async {
    await _pump(tester);
    expect(
      find.text('Nothing changes: the space already does this.'),
      findsOneWidget,
    );
    final apply = tester.widget<FilledButton>(
      find.byKey(const ValueKey('setup-levels-apply')),
    );
    expect(apply.onPressed, isNull);
  });

  testWidgets('a quick start writes exactly the planned change', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final expected = _planFor(repo, setupPresets[SetupPreset.complet]!);
    expect(expected.isEmpty, isFalse, reason: 'the fixture must move');
    await tester.tap(find.byKey(const ValueKey('setup-preset-complet')));
    await tester.pumpAndSettle();
    await _unfoldDetails(tester);
    expect(find.byKey(const ValueKey('setup-levels-on')), findsOneWidget);
    // #2871: the preview names the guide's steps that set those features up.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('setup-levels-steps')))
          .data,
      startsWith('Then set them up in the guide: '),
    );
    await tester.tap(find.byKey(const ValueKey('setup-levels-apply')));
    await tester.pumpAndSettle();
    if (expected.switchOff.isNotEmpty) {
      await tester.tap(
        find.byKey(const ValueKey('setup-levels-confirm-off-yes')),
      );
      await tester.pumpAndSettle();
    }
    expect(repo.flagWrites, [expected.flags]);
  });

  testWidgets('the preview speaks in what the space gets, never switch names', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final expected = _planFor(repo, setupPresets[SetupPreset.complet]!);
    await tester.tap(find.byKey(const ValueKey('setup-preset-complet')));
    await tester.pumpAndSettle();
    // #3283 — folded until asked for.
    expect(find.byKey(const ValueKey('setup-levels-on')), findsNothing);
    await _unfoldDetails(tester);
    final l10n = AppLocalizationsEn();
    final bullets = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('setup-levels-preview')),
            matching: find.textContaining('• '),
          ),
        )
        .map((t) => t.data)
        .toList();
    expect(bullets, [
      for (final f in expected.switchOn)
        '• ${l10n.labelWithValue(featureName(l10n, f), featureDescription(l10n, f))}',
    ]);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('setup-levels-on'))).data,
      'Your space gets:',
    );
  });

  testWidgets('switching off asks first, and a no writes nothing', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final expected = _planFor(repo, setupPresets[SetupPreset.essentiel]!);
    expect(expected.switchOff, isNotEmpty, reason: 'the fixture must lower');
    await tester.tap(find.byKey(const ValueKey('setup-preset-essentiel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-levels-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('setup-levels-confirm-off')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.flagWrites, isEmpty);
  });

  testWidgets('an answer gives its process a level and says why', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(
      find.byKey(const ValueKey('setup-question-issue_invoices')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Because you issue invoices'), findsOneWidget);
  });

  // #3283 — a save that cannot land says why and writes nothing; Apply
  // stays to try again, and a retry writes the planned change once.
  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('setup-levels-apply')));
    await tester.pumpAndSettle();
    final yes = find.byKey(const ValueKey('setup-levels-confirm-off-yes'));
    if (yes.evaluate().isNotEmpty) {
      await tester.tap(yes);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a conflicting save writes nothing and says so', (tester) async {
    final repo = await _pump(tester);
    repo.flagConflictNext = true;
    await tester.tap(find.byKey(const ValueKey('setup-preset-complet')));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(repo.flagWrites, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a right withdrawn meanwhile: refused, nothing written', (
    tester,
  ) async {
    final repo = await _pump(tester);
    repo.flagWriteErrorNext = const PostgrestException(
      message: 'permission denied',
      code: '42501',
    );
    await tester.tap(find.byKey(const ValueKey('setup-preset-complet')));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(repo.flagWrites, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Workspace saved.'), findsNothing);
  });

  testWidgets('a failed save says so; Try again writes the change once', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final expected = _planFor(repo, setupPresets[SetupPreset.complet]!);
    repo.flagWriteErrorNext = TimeoutException('offline');
    await tester.tap(find.byKey(const ValueKey('setup-preset-complet')));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(repo.flagWrites, isEmpty);
    expect(
      find.text('The choices could not be saved. Try again.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6)); // the notice leaves
    await tester.pumpAndSettle();
    await apply(tester);
    expect(repo.flagWrites, [expected.flags]);
  });

  testWidgets('each question carries a business example', (tester) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-question-issue_invoices')),
        matching: find.textContaining('numbered invoice'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the summary counts the open answers and takes the focus to '
      'the first, unfolding its group', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('form-error-summary-go')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('setup-question-door_tablet-unknown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('form-error-summary-go')));
    await tester.pumpAndSettle();
    final question = find.byKey(const ValueKey('setup-question-door_tablet'));
    expect(question, findsOneWidget);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused != null &&
          find
              .ancestor(
                of: find.byElementPredicate((e) => e == focused),
                matching: question,
              )
              .evaluate()
              .isNotEmpty,
      isTrue,
      reason: 'the focus is on the first open question',
    );
  });
}

/// #3283 — the exact switches are behind the review's disclosure.
Future<void> _unfoldDetails(WidgetTester tester) async {
  final details = find.byKey(const ValueKey('setup-levels-details'));
  await tester.ensureVisible(details);
  await tester.tap(details);
  await tester.pumpAndSettle();
}
