// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — the live guide host: the step points at the real keyed control
// with a ring that never takes a tap; a command step waits for its real
// outcome (a tap alone never completes it); skip marks skipped, back and
// stop undo nothing; a control that is not on screen is said, not
// guessed; switching the feature off pauses and resume rechecks; reduced
// motion still shows the control; and tips yield while a guide is open.
import 'package:deskilo/core/help/help_arbiter.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/guide/guide_session.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:deskilo/features/task_recorder/presentation/guide_host/guide_host.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

class _Flag extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool v) => state = v;
}

final _feature = NotifierProvider<_Flag, bool>(_Flag.new);

class _Scope extends Notifier<RecorderScope?> {
  @override
  RecorderScope? build() => canaryScope;
  void set(RecorderScope? v) => state = v;
}

final _scope = NotifierProvider<_Scope, RecorderScope?>(_Scope.new);

TaskGuide _guide(List<GuideStep> steps) => TaskGuide(
  actionContractVersion: actionContractVersion,
  title: 'Save the form',
  steps: steps,
);

const _tapSave = GuideStep(
  id: 'g1',
  kind: GuideStepKind.perform,
  action: RecorderActions.uiTap,
  target: 'demo-save',
);

const _command = GuideStep(
  id: 'g2',
  kind: GuideStepKind.perform,
  action: RecorderActions.uiCommand,
  expectedOutcomes: {RecorderOutcomes.commandDone},
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool reducedMotion = false,
  bool withControl = true,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(
    overrides: [
      recorderScopeProvider.overrideWith((ref) => ref.watch(_scope)),
      taskRecorderAvailableProvider.overrideWith((ref) => ref.watch(_feature)),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 1400),
          disableAnimations: reducedMotion,
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [
              child!,
              const Positioned.fill(child: GuideHostLayer()),
            ],
          ),
          home: Scaffold(
            body: ListView(
              children: [
                const SizedBox(height: 1600),
                if (withControl)
                  ElevatedButton(
                    key: const ValueKey('demo-save'),
                    onPressed: () {},
                    child: const Text('Save'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

GuideSession _session(ProviderContainer c) =>
    c.read(guideSessionProvider.notifier);

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester, ProviderContainer c) async {
  _session(c).close();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('the step points at the keyed control; Show me brings it in', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(_session(c).start(_guide(const [_tapSave])), isTrue);
    await _settle(tester);
    expect(_key('guide-host'), findsOneWidget);
    expect(_key('guide-host-step-g1'), findsOneWidget);
    // Off screen at first (1600 px down): Show me scrolls it in.
    await tester.tap(_key('guide-host-show-me'));
    await _settle(tester);
    expect(_key('guide-host-ring'), findsOneWidget);
    // The ring never takes the tap: the control underneath gets it.
    final ring = tester.getRect(_key('guide-host-ring'));
    final button = tester.getRect(_key('demo-save'));
    expect(ring.contains(button.center), isTrue);
    expect(
      find.ancestor(
        of: _key('guide-host-ring'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    // The capture names the tap; another control's tap is not this step.
    _session(c).action(RecorderActions.uiTap, target: 'something-else');
    await tester.pump();
    expect(c.read(guideSessionProvider).run!.statusOf('g1').name, 'pending');
    _session(c).action(RecorderActions.uiTap, target: 'demo-save');
    await _settle(tester);
    expect(_key('guide-host-completed'), findsOneWidget);
    await _end(tester, c);
  });

  testWidgets('a command waits for its real outcome; the tap alone does not '
      'complete it', (tester) async {
    final c = await _pump(tester);
    _session(c).start(_guide(const [_command]));
    await _settle(tester);
    _session(c).action(RecorderActions.uiCommand);
    await _settle(tester);
    expect(_key('guide-host-waiting'), findsOneWidget);
    // While it waits, it cannot be skipped into "done".
    expect(_key('guide-host-skip'), findsNothing);
    _session(c).outcome(RecorderOutcomes.commandUnknown);
    await _settle(tester);
    expect(_key('guide-host-uncertain'), findsOneWidget);
    _session(c).action(RecorderActions.uiCommand);
    _session(c).outcome(RecorderOutcomes.commandDone);
    await _settle(tester);
    expect(_key('guide-host-completed'), findsOneWidget);
    await _end(tester, c);
  });

  testWidgets('skip marks skipped, back and stop undo nothing, done '
      'acknowledges an instruction', (tester) async {
    final c = await _pump(tester);
    _session(c).start(
      _guide(const [
        GuideStep(id: 'g1', kind: GuideStepKind.instruction, text: 'Read me'),
        GuideStep(
          id: 'g2',
          kind: GuideStepKind.perform,
          action: RecorderActions.uiTap,
          target: 'demo-save',
        ),
        GuideStep(
          id: 'g3',
          kind: GuideStepKind.perform,
          action: RecorderActions.uiCommand,
          expectedOutcomes: {RecorderOutcomes.commandDone},
        ),
      ]),
    );
    await _settle(tester);
    expect(find.text('Read me'), findsOneWidget);
    await tester.tap(_key('guide-host-done'));
    await _settle(tester);
    expect(_key('guide-host-step-g1'), findsNothing);
    await tester.tap(_key('guide-host-skip'));
    await _settle(tester);
    final run = c.read(guideSessionProvider).run!;
    // Acknowledged and skipped — never "done".
    expect(run.statusOf('g1').name, 'acknowledged');
    expect(run.statusOf('g2').name, 'skipped');
    expect(run.current!.id, 'g3');
    await tester.tap(_key('guide-host-back'));
    await _settle(tester);
    // Back shows the previous step again; nothing is undone or redone.
    expect(c.read(guideSessionProvider).run!.current!.id, 'g2');
    expect(c.read(guideSessionProvider).run!.statusOf('g2').name, 'skipped');
    // The step list says every status.
    await tester.tap(_key('guide-host-steps'));
    await _settle(tester);
    expect(_key('guide-host-step-list'), findsOneWidget);
    await tester.tap(_key('guide-host-stop'));
    await _settle(tester);
    expect(_key('guide-host-stopped'), findsOneWidget);
    expect(c.read(helpSlotProvider), HelpSlot.guide);
    await tester.tap(_key('guide-host-close'));
    await _settle(tester);
    expect(_key('guide-host'), findsNothing);
    expect(c.read(helpSlotProvider), HelpSlot.tips);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a control that is not on screen is said, never guessed', (
    tester,
  ) async {
    final c = await _pump(tester, withControl: false);
    _session(c).start(_guide(const [_tapSave]));
    await _settle(tester);
    expect(_key('guide-host-not-on-screen'), findsOneWidget);
    expect(_key('guide-host-ring'), findsNothing);
    expect(_key('guide-host-show-me'), findsNothing);
    await _end(tester, c);
  });

  testWidgets('the feature switched off pauses; resume rechecks', (
    tester,
  ) async {
    final c = await _pump(tester);
    _session(c).start(_guide(const [_tapSave]));
    await _settle(tester);
    c.read(_feature.notifier).set(false);
    await _settle(tester);
    expect(_key('guide-host-paused-featureOff'), findsOneWidget);
    // Resuming while it is still off does nothing.
    await tester.tap(_key('guide-host-resume'));
    await _settle(tester);
    expect(_key('guide-host-paused-featureOff'), findsOneWidget);
    c.read(_feature.notifier).set(true);
    await tester.tap(_key('guide-host-resume'));
    await _settle(tester);
    expect(_key('guide-host-resume'), findsNothing);
    await _end(tester, c);
  });

  testWidgets('another account or workspace pauses the guide where it '
      'started', (tester) async {
    final c = await _pump(tester);
    _session(c).start(_guide(const [_tapSave]));
    await _settle(tester);
    c.read(_scope.notifier).set(null);
    await _settle(tester);
    expect(_key('guide-host-paused-scopeChanged'), findsOneWidget);
    expect(_session(c).resume(), isFalse);
    // Events of the other scope reach nothing.
    _session(c).action(RecorderActions.uiTap, target: 'demo-save');
    await _settle(tester);
    expect(c.read(guideSessionProvider).run!.statusOf('g1').name, 'pending');
    await _end(tester, c);
  });

  testWidgets('reduced motion still brings the control in view', (
    tester,
  ) async {
    final c = await _pump(tester, reducedMotion: true);
    _session(c).start(_guide(const [_tapSave]));
    await _settle(tester);
    await tester.tap(_key('guide-host-show-me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_key('guide-host-ring'), findsOneWidget);
    await _end(tester, c);
  });

  testWidgets('a signed-out person cannot start a guide', (tester) async {
    final c = await _pump(tester);
    c.read(_scope.notifier).set(null);
    expect(_session(c).start(_guide(const [_tapSave])), isFalse);
    expect(GuideEvents.sink, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
