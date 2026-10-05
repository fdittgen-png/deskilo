// SPDX-License-Identifier: AGPL-3.0-or-later
// Results only complete their own live guide attempt. Failed replacement
// preserves the last saved guide; real file replacement survives reopening.
import 'dart:io';

import 'package:deskilo/features/task_recorder/data/guide_store.dart';
import 'package:deskilo/features/task_recorder/data/recorder_log_backends.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/guide/guide_runner.dart';
import 'package:deskilo/features/task_recorder/guide/guide_session.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:deskilo/features/task_recorder/presentation/recorder_seam.dart';
import 'package:deskilo/features/task_recorder/presentation/ui_capture.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

class _FailingBackend extends MemoryRecorderLogBackend {
  @override
  Future<void> replace(String key, String text) async =>
      throw const FileSystemException('storage full');
}

TaskGuide _guide(String target, {String? title}) => TaskGuide(
  actionContractVersion: actionContractVersion,
  title: title,
  steps: [GuideStep(id: 'g1', kind: GuideStepKind.perform,
    action: RecorderActions.uiCommand, target: target,
    expectedOutcomes: {RecorderOutcomes.commandDone})],
);

void main() {
  final target = uiCommandMessages.first;
  final other = uiCommandMessages.skip(1).first;

  testWidgets('both capture paths reject unrelated, duplicate and old-run results', (tester) async {
    final container = ProviderContainer(overrides: [
      recorderScopeProvider.overrideWithValue(canaryScope),
      taskRecorderAvailableProvider.overrideWithValue(true),
      recorderStoreProvider.overrideWithValue(RecorderStore(
        backend: MemoryRecorderLogBackend(), namespace: canaryNamespace)),
    ]);
    addTearDown(container.dispose);
    late WidgetRef ref;
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: Consumer(builder: (_, r, child) { ref = r; return const SizedBox(); })));
    final session = container.read(guideSessionProvider.notifier);
    final capture = UiCapture(
      controller: () => container.read(recorderControllerProvider),
      protectedNow: () => false,
    );
    session.start(_guide(target));
    final a = capture.started('workspace', target)!;
    final b = capture.started('workspace', other)!;
    capture.ended(b);
    expect(container.read(guideSessionProvider).run!.statusOf('g1'), GuideStepStatus.waiting);
    capture.ended(a);
    expect(container.read(guideSessionProvider).run!.state, GuideRunState.completed);
    session.start(_guide(target));
    final fresh = recordTaskAttempt(ref, RecorderActions.uiCommand, target: target)!;
    capture.ended(a); // the same session object, but a new run
    recordTaskAttempt(ref, RecorderActions.uiCommand, target: other)!.resolve(RecorderOutcomes.commandDone);
    expect(container.read(guideSessionProvider).run!.state, GuideRunState.running);
    fresh.resolve(RecorderOutcomes.commandDone);
    expect(container.read(guideSessionProvider).run!.state, GuideRunState.completed);
    session.start(_guide(target));
    final next = recordTaskAttempt(ref, RecorderActions.uiCommand, target: target)!;
    fresh.resolve(RecorderOutcomes.commandDone);
    expect(container.read(guideSessionProvider).run!.state, GuideRunState.running);
    next.resolve(RecorderOutcomes.commandDone);
    expect(container.read(guideSessionProvider).run!.state, GuideRunState.completed);
  });

  test('pause/retry discards the old result without stealing the new attempt', () {
    final run = GuideRun(_guide(target));
    final old = run.onAction(RecorderActions.uiCommand, target: target);
    run.pause();
    run.resume();
    expect(run.uncertain, isTrue);
    final current = run.onAction(RecorderActions.uiCommand, target: target);
    expect(run.onAction(RecorderActions.uiCommand, target: target), isNull);
    run.onOutcome(RecorderOutcomes.commandDone, token: old);
    expect(run.statusOf('g1'), GuideStepStatus.waiting);
    run.onOutcome(RecorderOutcomes.commandDone, token: current);
    expect(run.state, GuideRunState.completed);
  });

  test('failed edit preserves the saved guide', () async {
    final store = GuideStore(backend: _FailingBackend(), accountNamespace: 'account');
    final id = await store.add(_guide(target, title: 'Original'));
    await expectLater(store.replace(id, _guide(target, title: 'Edited')), throwsA(isA<FileSystemException>()));
    expect((await store.list()).single.guide.title, 'Original');
  });

  test('file replacement is readable after reopening; interrupted staging is ignored', () async {
    final dir = await Directory.systemTemp.createTemp('guide-replacement-');
    addTearDown(() => dir.delete(recursive: true));
    final backend = FileRecorderLogBackend(directory: dir);
    final store = GuideStore(backend: backend, accountNamespace: 'account');
    final id = await store.add(_guide(target, title: 'Original'));
    final created = (await store.list()).single.createdAt;
    await store.replace(id, _guide(target, title: 'Edited'));
    final reopened = GuideStore(backend: FileRecorderLogBackend(directory: dir), accountNamespace: 'account');
    expect((await reopened.list()).single.guide.title, 'Edited');
    expect((await reopened.list()).single.createdAt, created);
    final staging = await dir.createTemp('.guide-');
    await File('${staging.path}/value').writeAsString('interrupted');
    expect((await reopened.list()).single.guide.title, 'Edited');
  });
}
