// SPDX-License-Identifier: 0BSD
//
// #1322 — swiping the bar away takes the title bar with it.
//
// The coach mark always promised "a full-screen view"; only the bottom
// bar went. These tests hold the two bars to ONE motion: same progress,
// same frames, same ways back. The continuity test samples the middle of
// the transition, because a second animation that merely starts and ends
// with the first passes every endpoint check and still visibly lags.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bar_visibility.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_pref_stores.dart';
import '../../helpers/mock_providers.dart';

Finder get _title => find.byKey(const ValueKey('shell-title-bar'));
Finder get _bar => find.byType(ShellBottomBar);
Finder get _button => find.byType(ShellCenterButton);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool hidden = false,
  bool disableAnimations = false,
  bool web = false,
  FakeEventRepository? events,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          shellBarHidden: InMemoryShellFlagStore(hidden),
          events: events,
        ),
        if (web) webShellProvider.overrideWithValue(true),
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(disableAnimations: disableAnimations),
        child: const DeskiloApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

double _titleHeight(WidgetTester tester) => tester.getSize(_title).height;

bool _barHidden(WidgetTester tester) => tester
    .widget<IgnorePointer>(find.byKey(const ValueKey('shell-bar-surface')))
    .ignoring;

WorkspaceEvent _pendingForMe(String id) => WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: EventType.reservation,
      action: EventAction.created,
      actorMemberId: 'member-2',
      subjectMemberId: 'member-1',
      payload: const {},
      status: EventStatus.pending,
      createdAt: kTestNow,
    );

void main() {
  testWidgets('one swipe hides both bars, and the long-press brings both '
      'back', (tester) async {
    await _pump(tester);
    final shown = _titleHeight(tester);
    expect(shown, greaterThan(40), reason: 'the title bar starts on screen');

    await tester.fling(_bar, const Offset(0, 300), 800);
    await tester.pumpAndSettle();

    expect(_barHidden(tester), isTrue);
    expect(_titleHeight(tester), 0,
        reason: 'the toolbar collapses; only the status inset (0 in a test '
            'view) would remain');

    await tester.longPress(_button);
    await tester.pumpAndSettle();

    expect(_barHidden(tester), isFalse);
    expect(_titleHeight(tester), shown);
  });

  testWidgets('an upward swipe restores the title bar too', (tester) async {
    await _pump(tester, hidden: true);
    expect(_titleHeight(tester), 0, reason: 'the stored choice hides both');

    await tester.fling(_bar, const Offset(0, -300), 800);
    await tester.pumpAndSettle();

    expect(_titleHeight(tester), greaterThan(40));
  });

  testWidgets('mid-transition the title bar follows the SAME progress, '
      'frame by frame, without a jump', (tester) async {
    final container = await _pump(tester);
    final full = _titleHeight(tester);
    final progress = container.read(shellBarProgressProvider);

    await container.read(shellBarHiddenProvider.notifier).set(true);
    final heights = <double>[full];
    final frames = kShellBarHideDuration.inMilliseconds ~/ 16 + 2;
    var sawMiddle = false;
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final t = progress.value;
      final h = _titleHeight(tester);
      if (t > 0.1 && t < 0.9) sawMiddle = true;
      expect(h, closeTo(full * (1 - t), 1.0),
          reason: 'frame $i: t=$t — the title bar must read the bottom '
              "bar's own progress, not a copy of its timing");
      heights.add(h);
    }
    expect(sawMiddle, isTrue, reason: 'the transition was actually sampled');
    expect(heights.last, 0);

    var worst = 0.0;
    for (var i = 1; i < heights.length; i++) {
      final step = (heights[i] - heights[i - 1]).abs();
      if (step > worst) worst = step;
      expect(heights[i], lessThanOrEqualTo(heights[i - 1] + 0.01),
          reason: 'frame $i reversed direction');
    }
    expect(worst, lessThan(full / 3),
        reason: 'one frame carried most of the travel: $heights');
  });

  testWidgets('reduced motion: both bars jump together to the same end '
      'state', (tester) async {
    final container = await _pump(tester, disableAnimations: true);
    await container.read(shellBarHiddenProvider.notifier).set(true);
    // The instant settle runs inside a build and is published one frame
    // later — an end state, never a journey.
    await tester.pump();
    await tester.pump();

    // Two frames, no time elapsed: the title bar is already gone, so
    // there was no journey to watch — only the end state.
    expect(_barHidden(tester), isTrue);
    expect(_titleHeight(tester), 0);
  });

  testWidgets('hidden, the title bar is out of the semantics tree',
      (tester) async {
    await _pump(tester, hidden: true);
    expect(
      tester
          .widget<ExcludeSemantics>(
              find.byKey(const ValueKey('shell-title-bar-semantics')))
          .excluding,
      isTrue,
    );
  });

  testWidgets('the Reserve button carries the pending count in full screen, '
      'and only there', (tester) async {
    final events = FakeEventRepository()
      ..events.addAll([_pendingForMe('e1'), _pendingForMe('e2')]);

    await _pump(tester, hidden: true, events: events);
    expect(find.byKey(const ValueKey('shell-center-pending')), findsOneWidget,
        reason: 'the bell left with the title bar; its count must not');

    await tester.longPress(_button);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shell-center-pending')), findsNothing,
        reason: 'with the bars back, the bell shows the count again');
  });

  testWidgets('no pending decision, no badge widget', (tester) async {
    await _pump(tester, hidden: true);
    expect(find.byKey(const ValueKey('shell-center-pending')), findsNothing);
  });

  testWidgets('web is unchanged: the drawer shell keeps a plain title bar',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, hidden: true, web: true);

    expect(_title, findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.getSize(find.byType(AppBar)).height, greaterThan(40));
  });
}
