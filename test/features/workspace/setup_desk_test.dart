// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3629 (desk M10) — the setup guide at the desk: its steps beside the page
// the address names, a list where the room allows and a rail of numbers
// where it does not, and the phone's pages as before. A step's draft is its
// own: leaving a step whose answers are a draft asks first by every way out
// — the steps beside it, Next and Back by the keys, Escape and the
// browser's history — and the draft read afterwards is the step's own.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/demo/seed/demo_setup_status.dart';
import 'package:deskilo/core/ui/app_durations.dart';
import 'package:deskilo/features/workspace/domain/launch_review.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/setup_step_words.dart';
import 'package:deskilo/features/workspace/presentation/widgets/setup_steps_pane.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/dictionary_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

const _workspace = 'ws-1';

/// The Demo's rules over the catalogue, the space's look switched on: the
/// basics and the hours done.
final SetupStatus _status = demoSetupStatus(
  const {'workspaceBranding': true},
  ready: {'basics', 'hours'},
);

final _steps = find.byKey(const ValueKey('setup-desk-steps'));
final _keep = find.byKey(const ValueKey('wizard-keep-draft'));
final _leave = find.byKey(const ValueKey('wizard-discard-draft'));

Future<FakeLocalSetupRepository> _pump(
  WidgetTester tester, {
  required Size size,
  String at = '/setup',
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final server = FakeLocalSetupRepository(status: _status);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(localSetup: server),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  _router(tester).go(at);
  await tester.pumpAndSettle();
  return server;
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

String _at(WidgetTester tester) => _router(tester).state.uri.path;

AppLocalizations get _l10n => lookupAppLocalizations(const Locale('en'));

/// Types a colour into the look step and waits for its draft to be saved.
Future<void> _typeDraft(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('setup-look-hex')),
    '#123456',
  );
  await tester.pump(AppDurations.draftAutosave);
  await tester.pumpAndSettle();
}

/// Puts the keyboard's focus on the steps beside the page.
void _focusSteps(WidgetTester tester) =>
    Focus.of(tester.element(find.text(_l10n.setupStepTitle('hours')).first))
        .requestFocus();

Future<void> _keys(WidgetTester tester, List<LogicalKeyboardKey> keys) async {
  for (final k in keys) {
    await tester.sendKeyDownEvent(k);
  }
  for (final k in keys.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a desk window with room the steps are a list beside the '
      'page, each in the words and mark of the guide', (tester) async {
    await _pump(tester, size: const Size(1440, 1000));
    expect(_steps, findsOneWidget);
    final shown = [
      for (final g in LaunchReview.from(_status).groups) ...g.steps,
    ];
    final done = shown.where((s) => s.state == SetupStepState.ready).length;
    expect(
      find.byKey(const ValueKey('setup-desk-guide-detail')),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.setupDeskProgress(done, shown.length)),
      findsOneWidget,
    );
    for (final s in shown) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('setup-desk-step-${s.step}')),
        100,
        scrollable: find.descendant(
          of: _steps,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      final word = tester.widget<Text>(
        find.byKey(ValueKey('setup-desk-state-${s.step}')),
      );
      expect(word.data, setupStepWord(_l10n, s), reason: s.step);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('setup-desk-step-${s.step}')),
          matching: find.byIcon(setupStepIcon(s.state)),
        ),
        findsOneWidget,
        reason: s.step,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('with less room the steps are a rail of numbers', (tester) async {
    await _pump(tester, size: const Size(1024, 800), at: '/setup/step/look');
    expect(_steps, findsOneWidget);
    expect(find.byKey(const ValueKey('setup-desk-state-basics')), findsNothing);
    expect(
      find.byKey(const ValueKey('setup-desk-step-basics')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-look-hex')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone keeps the guide as its own page', (tester) async {
    await _pump(tester, size: const Size(390, 844));
    expect(_steps, findsNothing);
    expect(find.byKey(const ValueKey('setup-guide-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every way out of a step with a draft asks first, and the '
      'draft written is that step\'s own', (tester) async {
    final server = await _pump(
      tester,
      size: const Size(1440, 1000),
      at: '/setup/step/look',
    );
    final order = setupDeskSequence(_status);
    final look = order.indexOf('step/look');
    expect(look, greaterThan(0), reason: 'the look step is listed');
    await _typeDraft(tester);

    // The steps beside it: Stay keeps the step; Leave opens the other.
    await tester.tap(find.byKey(const ValueKey('setup-desk-step-hours')));
    await tester.pumpAndSettle();
    expect(_keep, findsOneWidget);
    await tester.tap(_keep);
    await tester.pumpAndSettle();
    expect(_at(tester), '/setup/step/look');
    await tester.tap(find.byKey(const ValueKey('setup-desk-step-hours')));
    await tester.pumpAndSettle();
    await tester.tap(_leave);
    await tester.pumpAndSettle();
    expect(_at(tester), '/setup/step/hours');
    expect((await server.stepDraft(_workspace, 'look'))?.payload, isNotNull);
    expect(await server.stepDraft(_workspace, 'hours'), isNull);

    // The browser's Back: a step without a draft is left at once, and the
    // draft is back on the step it belongs to.
    await _router(tester).routeInformationProvider.didPushRouteInformation(
      RouteInformation(uri: Uri.parse('/setup/step/look')),
    );
    await tester.pumpAndSettle();
    expect(_at(tester), '/setup/step/look');
    expect(find.text('#123456'), findsOneWidget);

    // Alt+←: the step before, after the question.
    _focusSteps(tester);
    await _keys(tester, [
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowLeft,
    ]);
    expect(_leave, findsOneWidget);
    await tester.tap(_leave);
    await tester.pumpAndSettle();
    expect(_at(tester), '/setup/${order[look - 1]}');

    // Ctrl+Enter: the next one, after the question.
    _router(tester).go('/setup/step/look');
    await tester.pumpAndSettle();
    _focusSteps(tester);
    await _keys(tester, [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.enter,
    ]);
    expect(_leave, findsOneWidget);
    await tester.tap(_leave);
    await tester.pumpAndSettle();
    expect(_at(tester), '/setup/${order[look + 1]}');

    // Escape on the step: back to the guide, after the question.
    _router(tester).go('/setup/step/look');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-look-hex')));
    await tester.pumpAndSettle();
    await _keys(tester, [LogicalKeyboardKey.escape]);
    expect(_leave, findsOneWidget);
    await tester.tap(_leave);
    await tester.pumpAndSettle();
    expect(_at(tester), '/setup');

    expect(await server.stepDraft(_workspace, 'look'), isNotNull);
    for (final other in order.where((a) => a.startsWith('step/'))) {
      final id = other.substring('step/'.length);
      if (id == 'look') continue;
      expect(await server.stepDraft(_workspace, id), isNull, reason: id);
    }
    expect(tester.takeException(), isNull);
  });
}
