// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3061 — what waits on the person, on the overview and on its own screen:
// loading is not "nothing needs you"; a failed or refused read is not that
// sentence either, and Try again asks the same read once more; a refresh keeps
// the lines. The layout the overview lets a person save is covered in
// workspace_overview_layout_test.dart (lost answer, same request, one layout).
import 'dart:io';

import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/attention_screen.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_overview_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import '../../helpers/read_probe.dart';

final _en = AppLocalizationsEn();
const _retry = ValueKey('inline-banner-action');
const _empty = ValueKey('overview-attention-empty');

final _item = Attention(
  kind: AttentionKind.person,
  subject: 'members',
  action: AttentionAction.admit,
  waitingSince: DateTime(2026, 5),
  count: 2,
);

Future<ReadProbe<List<Attention>>> _pump(
  WidgetTester tester,
  Widget screen,
) async {
  final probe = ReadProbe<List<Attention>>();
  await pumpStateScreen(
    tester,
    screen,
    overrides: [
      ...standardTestOverrides(workspace: FakeWorkspaceRepository.withWorkspace()),
      enabledFeaturesSyncProvider.overrideWithValue({
        WorkspaceFeature.workspaceOverview,
      }),
      myPermissionsProvider.overrideWithValue(const {}),
      attentionProvider.overrideWith((ref) => probe()),
    ],
  );
  await tester.pump();
  return probe;
}

void main() {
  group('overview', () {
    const screen = WorkspaceOverviewScreen();

    testWidgets('loading is not "nothing needs you"', (tester) async {
      final probe = await _pump(tester, screen);
      expect(find.byKey(_empty), findsNothing);
      expect(find.byKey(const ValueKey('overview-attention-loading')), findsOneWidget);

      probe.answer([_item]);
      await tester.pump();
      expect(find.byKey(const ValueKey('overview-attention-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('overview-attention-loading')), findsNothing);
    });

    testWidgets('a successful empty answer says nothing needs the person', (
      tester,
    ) async {
      final probe = await _pump(tester, screen);
      probe.answer(const []);
      await tester.pump();
      expect(find.byKey(_empty), findsOneWidget);
    });

    testWidgets('a failure is not the empty sentence; Try again asks again', (
      tester,
    ) async {
      final probe = await _pump(tester, screen);
      probe.fail(const SocketException('offline'));
      await tester.pump();
      expect(find.byKey(_empty), findsNothing);
      expect(find.text(_en.readStateOffline), findsOneWidget);

      await tester.tap(find.byKey(_retry));
      await tester.pump();
      expect(probe.calls, 2);
      probe.answer([_item]);
      await tester.pump();
      expect(find.byKey(const ValueKey('overview-attention-0')), findsOneWidget);
      expect(find.text(_en.readStateOffline), findsNothing);
    });

    testWidgets('a refused read is access, not an empty inbox', (tester) async {
      final probe = await _pump(tester, screen);
      probe.fail(const PostgrestException(message: 'x', code: '42501'));
      await tester.pump();
      expect(find.byKey(_empty), findsNothing);
      expect(find.text(_en.readStateDenied), findsOneWidget);
    });

    testWidgets('a refresh keeps the lines with a thin progress line', (
      tester,
    ) async {
      final probe = await _pump(tester, screen);
      probe.answer([_item]);
      await tester.pump();
      ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceOverviewScreen)),
      ).invalidate(attentionProvider);
      await tester.pump();
      expect(find.byKey(const ValueKey('overview-attention-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('overview-attention-loading')), findsOneWidget);
      expect(find.byKey(_empty), findsNothing);
    });
  });

  group('pending actions screen', () {
    const screen = AttentionScreen();

    testWidgets('loading, then the lines; empty only when really empty', (
      tester,
    ) async {
      final probe = await _pump(tester, screen);
      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.byKey(AttentionScreen.emptyKey), findsNothing);
      probe.answer([_item]);
      await tester.pump();
      expect(find.byKey(AttentionScreen.rowKeyFor(0)), findsOneWidget);
    });

    testWidgets('a successful empty answer is the empty state', (tester) async {
      final probe = await _pump(tester, screen);
      probe.answer(const []);
      await tester.pump();
      expect(find.byKey(AttentionScreen.emptyKey), findsOneWidget);
    });

    testWidgets('a failure draws a failure, never a blank page or the empty '
        'state; Try again asks again', (tester) async {
      final probe = await _pump(tester, screen);
      probe.fail(StateError('boom'));
      await tester.pump();
      expect(find.byKey(AttentionScreen.emptyKey), findsNothing);
      expect(find.text(_en.readStateFailed), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);

      await tester.tap(find.byKey(_retry));
      await tester.pump();
      expect(probe.calls, 2);
      probe.answer([_item]);
      await tester.pump();
      expect(find.byKey(AttentionScreen.rowKeyFor(0)), findsOneWidget);
    });

    testWidgets('a refresh keeps the lines', (tester) async {
      final probe = await _pump(tester, screen);
      probe.answer([_item]);
      await tester.pump();
      ProviderScope.containerOf(
        tester.element(find.byType(AttentionScreen)),
      ).invalidate(attentionProvider);
      await tester.pump();
      expect(find.byKey(AttentionScreen.rowKeyFor(0)), findsOneWidget);
      expect(find.byKey(const ValueKey('read-refreshing')), findsOneWidget);
    });
  });
}
