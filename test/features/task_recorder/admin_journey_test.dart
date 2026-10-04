// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1884 B — management forms through their real screens: the role
// matrix, the validation rules, and the shared command observer. A
// permission switch keeps which permission, for which built-in role,
// which way; a rule keeps which event type it is for, never who
// approves. Each save is an attempt before the command and its real
// result after (saved, sent for validation, refused or unknown), and the
// stored state is the same with the recorder off.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/validation/pending_validation.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/presentation/recorder_seam.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/validation_settings.dart' show admin;
import 'fixtures/recording_fixtures.dart';

class _HeldEvents extends FakeEventRepository {
  @override
  Future<void> upsertValidationPolicy(ValidationPolicy policy) async =>
      throw const PendingValidationException('ev-canary');
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required bool record,
  required String route,
  FakeWorkspaceRepository? workspace,
  FakeEventRepository? events,
}) async {
  tester.view.physicalSize = const Size(1200, 3400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  workspace ??= FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..otherMembers.add(admin('member-2'));
  final c = ProviderContainer(
    overrides: [
      ...standardTestOverrides(workspace: workspace, events: events),
      recorderStoreProvider.overrideWithValue(
        RecorderStore(
          backend: MemoryRecorderLogBackend(),
          namespace: canaryNamespace,
        ),
      ),
      recorderScopeProvider.overrideWithValue(canaryScope),
    ],
  );
  if (record) {
    expect(
      await c.read(recorderControllerProvider).start(scope: canaryScope),
      isTrue,
    );
    c.read(recorderOpenedProvider.notifier).open();
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const DeskiloApp()),
  );
  await tester.pumpAndSettle();
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(route),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<TaskRecording> _stop(WidgetTester tester, ProviderContainer c) async {
  final r = (await c.read(recorderControllerProvider).stop())!;
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  return r;
}

RecordedStep _outcomeOf(TaskRecording r, RecordedStep attempt) =>
    r.steps.singleWhere((s) => s.op == attempt.op && !s.isAttempt);

Future<void> _tapPermission(WidgetTester tester, String key) async {
  final tile = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    tile,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  test('the accepted permission and rule keys are exactly the enums', () {
    expect(
      workspacePermissionKeys,
      WorkspacePermission.values.map((p) => p.wireName).toSet(),
    );
    expect(validationRuleKeys, {
      for (final t in EventType.values)
        if (t != EventType.unknown) t.dbName,
    });
  });

  testWidgets('a permission switch: which one, for whom, then saved', (
    tester,
  ) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final c = await _pump(
      tester,
      record: true,
      route: '/roles',
      workspace: workspace,
    );
    await _tapPermission(tester, 'perm-admin-issueInvoices');
    final r = await _stop(tester, c);
    final attempt = r.steps.singleWhere((s) => s.isAttempt);
    expect(attempt.action, RecorderActions.togglePermission);
    expect(attempt.target, 'issueInvoices');
    expect(attempt.payload.toJson(), {'role_kind': 'admin', 'switch_to': 'on'});
    expect(_outcomeOf(r, attempt).outcome, RecorderOutcomes.settingSaved);
    expect(
      workspace.workspaces.single.rolePermissions['admin'] as List,
      contains('issueInvoices'),
    );
  });

  testWidgets('the same permission with the recorder off', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final c = await _pump(
      tester,
      record: false,
      route: '/roles',
      workspace: workspace,
    );
    await _tapPermission(tester, 'perm-admin-issueInvoices');
    expect(
      workspace.workspaces.single.rolePermissions['admin'] as List,
      contains('issueInvoices'),
    );
    expect(c.read(recorderControllerProvider).state, RecorderState.idle);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('a validation rule: its type, never its approvers', (
    tester,
  ) async {
    final events = FakeEventRepository();
    final c = await _pump(
      tester,
      record: true,
      route: '/validation',
      events: events,
    );
    await tester.tap(find.text('Default policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c);
    final attempt = r.steps.singleWhere((s) => s.isAttempt);
    expect(attempt.action, RecorderActions.saveValidationRule);
    expect(attempt.target, validationDefaultRule);
    expect(_outcomeOf(r, attempt).outcome, RecorderOutcomes.settingSaved);
    expect(events.policies, hasLength(1));
    final text = encodeRecordingText(r);
    for (final secret in ['member-2', 'Ana', 'Flo']) {
      expect(text.contains(secret), isFalse, reason: secret);
    }
  });

  testWidgets('a rule held for validation is pending, never saved', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      record: true,
      route: '/validation',
      events: _HeldEvents(),
    );
    await tester.tap(find.text('Default policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c);
    final attempt = r.steps.singleWhere((s) => s.isAttempt);
    expect(_outcomeOf(r, attempt).outcome, RecorderOutcomes.settingPending);
    expect(encodeRecordingText(r).contains('ev-canary'), isFalse);
  });

  testWidgets('closing a rule unsaved is its own step, and saves nothing', (
    tester,
  ) async {
    final events = FakeEventRepository();
    final c = await _pump(
      tester,
      record: true,
      route: '/validation',
      events: events,
    );
    await tester.tap(find.text('Default policy'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c);
    expect(
      r.steps.map((s) => s.action),
      contains(RecorderActions.cancelValidationRule),
    );
    expect(r.steps.where((s) => s.isAttempt), isEmpty);
    expect(events.policies, isEmpty);
  });

  test('with no recording the command just runs, errors unchanged', () async {
    expect(await observeTaskSetting(null, () async => 7), 7);
    await expectLater(
      observeTaskSetting<void>(null, () async => throw StateError('x')),
      throwsStateError,
    );
  });
}
