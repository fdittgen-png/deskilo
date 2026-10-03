// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2142 — the generic layer: on any screen, a tap is named by its
// control's key (or the key's pattern) and labelled by the app's own
// words; a field left is named, never read; a guarded command is an
// attempt and its real result; a protected screen stays one marker; the
// recorder's own controls are never noted; a screen's own seam wins; a
// control with no listed key is a visible gap; and a recorder never
// opened costs nothing. Canaries typed into fields and carried in ids
// never reach the recording.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/trace/guarded.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/presentation/recorder_seam.dart';
import 'package:deskilo/features/task_recorder/presentation/ui_capture.dart';
import 'package:deskilo/features/task_recorder/presentation/ui_labels.g.dart';
import 'package:deskilo/features/task_recorder/presentation/widgets/recording_indicator.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import 'fixtures/recording_fixtures.dart';

const _canary = 'Canary-Typed-4711';

ProviderContainer _container() => ProviderContainer(
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

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: ListView(
        children: [
          FilledButton(
            key: const ValueKey('drawer-members'),
            onPressed: () {},
            child: Text(l10n.membersTitle),
          ),
          TextButton(onPressed: () {}, child: const Text('no key here')),
          TextButton(
            key: const ValueKey('perm-admin-member-0042'),
            onPressed: () {},
            child: const Text('a pattern key'),
          ),
          const TextField(key: ValueKey('me-workspaces')),
          FilledButton(
            key: const ValueKey('me-help'),
            onPressed: () => runGuarded(
              context,
              domain: 'workspace',
              message: 'role permissions update failed',
              action: () async {},
            ),
            child: const Text('guarded'),
          ),
          FilledButton(
            key: const ValueKey('me-privacy'),
            onPressed: () => recordTaskStep(ref, RecorderActions.selectLevel),
            child: const Text('seam'),
          ),
          TextButton(
            key: const ValueKey('me-activity'),
            onPressed: () => context.go('/auth'),
            child: const Text('protected'),
          ),
        ],
      ),
    );
  }
}

Future<(ProviderContainer, RecorderController, GoRouter)> _pumpHarness(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = _container();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Home()),
      GoRoute(
        path: '/auth',
        builder: (_, _) => Scaffold(
          body: TextButton(
            key: const ValueKey('drawer-members'),
            onPressed: () {},
            child: const Text('on a protected screen'),
          ),
        ),
      ),
    ],
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
  expect(await controller.start(scope: canaryScope), isTrue);
  await tester.pumpAndSettle();
  return (c, controller, router);
}

Future<TaskRecording> _stop(
  WidgetTester tester,
  ProviderContainer c,
  RecorderController controller,
) async {
  final r = (await controller.stop())!;
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  return r;
}

/// Generic steps, a label shown as the English words it stands for.
List<String> _generic(TaskRecording r) {
  final en = lookupAppLocalizations(const Locale('en'));
  String words(String? key) => key == null ? '' : ' "${uiLabel(en, key)}"';
  return [
    for (final s in r.steps)
      if (s.action?.startsWith('ui.') ?? false)
        '${s.action} ${s.target ?? '-'}${words(s.payload.values['label'])}',
  ];
}

void main() {
  test('the vocabulary names keys, patterns, messages and labels', () {
    expect(uiKeys, containsAll(['drawer-members', 'me-workspaces']));
    expect(uiKeyPatterns, contains('perm-{}-{}'));
    expect(uiCommandMessages, contains('role permissions update failed'));
    expect(uiLabelKeys, contains('membersTitle'));
    expect(UiCapture.nameOfKey('perm-admin-member-0042'), 'perm-{}-{}');
    expect(UiCapture.nameOfKey('typed by $_canary'), uiUnkeyed);
    expect(UiCapture.nameOfKey(null), uiUnkeyed);
  });

  testWidgets('taps by key, pattern or gap; a field by key, never read', (
    tester,
  ) async {
    final (c, controller, _) = await _pumpHarness(tester);
    await tester.tap(find.byKey(const ValueKey('drawer-members')));
    await tester.tap(find.text('no key here'));
    await tester.tap(find.byKey(const ValueKey('perm-admin-member-0042')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('me-workspaces')),
      _canary,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('drawer-members')));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c, controller);
    expect(_generic(r), [
      'ui.tap drawer-members "Members & plans"',
      'ui.tap unkeyed',
      'ui.tap perm-{}-{}',
      'ui.commit_field me-workspaces',
      'ui.tap drawer-members "Members & plans"',
    ]);
    final text = encodeRecordingText(r);
    for (final secret in [_canary, '0042', 'no key here']) {
      expect(text.contains(secret), isFalse, reason: secret);
    }
  });

  testWidgets('a guarded command is an attempt, then its real result', (
    tester,
  ) async {
    final (c, controller, _) = await _pumpHarness(tester);
    await tester.tap(find.byKey(const ValueKey('me-help')));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c, controller);
    final attempt = r.steps.singleWhere((s) => s.isAttempt);
    expect(attempt.action, RecorderActions.uiCommand);
    expect(attempt.target, 'role permissions update failed');
    final outcome = r.steps.singleWhere(
      (s) => s.op == attempt.op && !s.isAttempt,
    );
    expect(outcome.outcome, RecorderOutcomes.commandDone);
  });

  testWidgets('a screen\'s own seam wins over the generic tap', (tester) async {
    final (c, controller, _) = await _pumpHarness(tester);
    await tester.tap(find.byKey(const ValueKey('me-privacy')));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c, controller);
    expect(_generic(r), isEmpty);
  });

  testWidgets('a protected screen is one marker, and nothing on it', (
    tester,
  ) async {
    final (c, controller, _) = await _pumpHarness(tester);
    await tester.tap(find.byKey(const ValueKey('me-activity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('on a protected screen'));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c, controller);
    expect(r.steps.where((s) => s.kind == StepKind.excluded), hasLength(1));
    expect(_generic(r), ['ui.tap me-activity']);
  });

  testWidgets('the recorder\'s own controls are never noted', (tester) async {
    final (c, controller, _) = await _pumpHarness(tester);
    await tester.tap(find.byKey(const ValueKey('recording-indicator-pause')));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c, controller);
    expect(_generic(r), isEmpty);
  });

  testWidgets('a recorder never opened costs nothing', (tester) async {
    final c = ProviderContainer(overrides: standardTestOverrides());
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const DeskiloApp()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/roles'));
    await tester.pumpAndSettle();
    expect(c.exists(recorderControllerProvider), isFalse);
    expect(guardedCommandWatcher, isNull);
    expect(UiCapture.current, isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('across the app: a screen by its pattern and title, a '
      'command on the role matrix with no seam of its own', (tester) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final c = ProviderContainer(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        recorderStoreProvider.overrideWithValue(
          RecorderStore(
            backend: MemoryRecorderLogBackend(),
            namespace: canaryNamespace,
          ),
        ),
        recorderScopeProvider.overrideWithValue(canaryScope),
      ],
    );
    c.read(recorderOpenedProvider.notifier).open();
    final controller = c.read(recorderControllerProvider);
    expect(await controller.start(scope: canaryScope), isTrue);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const DeskiloApp()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/roles'));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('perm-admin-issueInvoices'));
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // A member's page, by an id: the pattern is noted, never the path.
    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push('/member/member-canary-77'),
    );
    await tester.pumpAndSettle();
    final r = await _stop(tester, c, controller);
    expect(
      _generic(r),
      contains(startsWith('ui.open_screen /member/:memberId')),
    );
    expect(encodeRecordingText(r).contains('canary-77'), isFalse);
    expect(_generic(r), contains('ui.open_screen /roles "Roles"'));
    final attempt = r.steps.singleWhere((s) => s.isAttempt);
    expect(attempt.action, RecorderActions.uiCommand);
    expect(attempt.target, 'role permissions update failed');
    expect(
      r.steps.singleWhere((s) => s.op == attempt.op && !s.isAttempt).outcome,
      RecorderOutcomes.commandDone,
    );
    expect(
      workspace.workspaces.single.rolePermissions['admin'] as List,
      contains('issueInvoices'),
    );
  });
}
