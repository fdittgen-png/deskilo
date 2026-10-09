// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: with "capture values" on, what a person typed into a field and
// the state a switch was left in are recorded — and a field that hides what is
// typed, or holds a secret, a payment identifier or personal contact data,
// is recorded as redacted with only its length. With it off (the default)
// nothing typed reaches the recording: the generic layer's guarantee stands.
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/step_values.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/presentation/widgets/recording_indicator.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/recording_fixtures.dart';

const _typed = 'Standing desk for Ana';
const _secret = 'Canary-Secret-4711';

class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  bool on = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        const TextField(
          key: ValueKey('me-workspaces'),
          decoration: InputDecoration(labelText: 'Reason'),
        ),
        const TextField(
          key: ValueKey('me-help'),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Quantity'),
        ),
        const TextField(
          key: ValueKey('me-privacy'),
          obscureText: true,
          decoration: InputDecoration(labelText: 'Code'),
        ),
        const TextField(
          key: ValueKey('me-activity'),
          decoration: InputDecoration(labelText: 'E-mail address'),
        ),
        Switch(
          key: const ValueKey('me-servers'),
          value: on,
          onChanged: (v) => setState(() => on = v),
        ),
      ],
    ),
  );
}

Future<(ProviderContainer, RecorderController)> _pump(
  WidgetTester tester, {
  required bool capture,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(
    overrides: [
      recorderStoreProvider.overrideWithValue(
        RecorderStore(
          backend: MemoryRecorderLogBackend(),
          namespace: canaryNamespace,
        ),
      ),
      recorderScopeProvider.overrideWithValue(canaryScope),
    ],
  );
  final router = GoRouter(
    initialLocation: '/me',
    routes: [GoRoute(path: '/me', builder: (_, _) => const _Form())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) =>
            RecordingIndicator(router: router, child: child!),
      ),
    ),
  );
  c.read(recorderOpenedProvider.notifier).open();
  final controller = c.read(recorderControllerProvider);
  expect(
    await controller.start(scope: canaryScope, captureValues: capture),
    isTrue,
  );
  await tester.pumpAndSettle();
  return (c, controller);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

Future<TaskRecording> _finish(
  WidgetTester tester,
  ProviderContainer c,
  RecorderController controller,
) async {
  await tester.pumpAndSettle();
  final r = (await controller.stop())!;
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  return r;
}

Map<String, StepValues> _byTarget(TaskRecording r) => {
  for (final s in r.steps)
    if (s.target != null) s.target!: s.values,
};

void main() {
  testWidgets('on: typed text, a number and a switch are recorded; hidden '
      'and personal fields only as redacted', (tester) async {
    final (c, controller) = await _pump(tester, capture: true);
    await _type(tester, 'me-workspaces', _typed);
    await _type(tester, 'me-help', '3,5');
    await _type(tester, 'me-privacy', _secret);
    await _type(tester, 'me-activity', 'ana@example.org');
    await tester.tap(find.byKey(const ValueKey('me-servers')));
    await tester.pumpAndSettle();
    final r = await _finish(tester, c, controller);

    final values = _byTarget(r);
    StepValues of(String k) => values[k]!;
    expect(of('me-workspaces').entries['value'], TextValue(_typed));
    expect(of('me-help').entries['value'], const NumberValue(3.5));
    expect(
      of('me-privacy').entries['value'],
      const RedactedValue(_secret.length),
    );
    expect(of('me-activity').entries['value'], const RedactedValue(15));
    expect(of('me-servers').entries['checked'], const FlagValue(true));

    // The file never carries what must not travel.
    final text = encodeRecordingText(r);
    expect(text.contains(_secret), isFalse);
    expect(text.contains('ana@example.org'), isFalse);
    expect(text.contains(_typed), isTrue);
    expect(decodeRecordingText(text).accepted, isTrue);
  });

  testWidgets('off (the default): nothing typed or chosen reaches the '
      'recording', (tester) async {
    final (c, controller) = await _pump(tester, capture: false);
    await _type(tester, 'me-workspaces', _typed);
    await _type(tester, 'me-privacy', _secret);
    await tester.tap(find.byKey(const ValueKey('me-servers')));
    await tester.pumpAndSettle();
    final r = await _finish(tester, c, controller);

    expect(r.capturesValues, isFalse);
    expect(r.steps.every((s) => s.values.isEmpty), isTrue);
    final text = encodeRecordingText(r);
    for (final s in [_typed, _secret, 'values']) {
      expect(text.contains(s), isFalse, reason: s);
    }
  });

  testWidgets(
    'a switch is recorded in the state the tap left it in, both ways',
    (tester) async {
      final (c, controller) = await _pump(tester, capture: true);
      await tester.tap(find.byKey(const ValueKey('me-servers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('me-servers')));
      await tester.pumpAndSettle();
      final r = await _finish(tester, c, controller);
      final states = [
        for (final s in r.steps)
          if (s.target == 'me-servers') s.values.entries['checked'],
      ];
      expect(states, [const FlagValue(true), const FlagValue(false)]);
    },
  );
}
