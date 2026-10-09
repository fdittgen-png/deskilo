// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — one task runs through Me and the spaces: a recording started in
// one space goes on in Me, in another space and back, and only another
// account (or installation) ends it.
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../me/me_app.dart';

void main() {
  testWidgets('a recording follows the person from a space to Me, into '
      'another space and back', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    // The recorder screen was opened once: the indicator follows routes.
    container.read(recorderOpenedProvider.notifier).open();
    await tester.pumpAndSettle();
    final recorder = container.read(recorderControllerProvider);
    final scope = container.read(recorderScopeProvider)!;
    expect(await recorder.start(scope: scope), isTrue);
    expect(container.read(currentWorkspaceProvider).value?.id, 'ws-1');
    recorder.annotate('In the first space');

    await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
    await tester.pumpAndSettle();
    expect(recorder.currentPage, '/me?tab=home');
    recorder.annotate('On Me');
    await tester.tap(find.byKey(const ValueKey('me-space-ws-2')));
    await tester.pumpAndSettle();
    expect(container.read(currentWorkspaceProvider).value?.id, 'ws-2');
    expect(recorder.status.endReason, isNull);
    expect(recorder.state, RecorderState.recording);
    recorder.annotate('In the second space');

    router.go('/me');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-space-ws-1')));
    await tester.pumpAndSettle();
    expect(container.read(recorderScopeProvider), scope);
    expect(recorder.currentPage, '/reserve');
    final recording = (await recorder.stop())!;
    expect(recording.endReason, RecordingEndReason.stopped);
    final notes = recording.steps.where((s) => s.note != null);
    expect(notes.map((s) => s.note), [
      'In the first space',
      'On Me',
      'In the second space',
    ]);
    expect(notes.map((s) => s.page), ['/reserve', '/me?tab=home', '/reserve']);
    // The taps and pages between them were recorded on both sides too.
    expect(
      recording.steps.where((s) => s.page == '/me?tab=home').length,
      greaterThan(1),
    );
  });
}
