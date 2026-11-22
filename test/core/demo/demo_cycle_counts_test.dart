// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 -- the Demo's cycle counts through the real routed app, at a phone and a desk width: the owner
// has been told once that the high-value shelf's count is overdue (the notice opens the cycle counts);
// the page lists that open task, the plan and the history; counting every line blind completes the
// task and each count lands in the counts of #4172 for approval, where the difference is read; a
// member who may not count is turned away by the link.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_destination.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

final _en = AppLocalizationsEn();

Future<ProviderContainer> _open(WidgetTester tester, {required DemoPersona persona, required Size size, String to = '/stock'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start(persona: persona);
  addTearDown(journey.dispose);
  journey.root.read(pendingDemoLinkProvider.notifier).hold(DemoLink.parse({'space': 'pezenas', 'persona': persona.name, 'to': to}));
  await tester.pumpWidget(UncontrolledProviderScope(container: journey.root, child: const DeskiloRoot()));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
}

/// Frames enough for a page or a sheet to arrive (a bounded pump: a page that keeps a spinner never settles).
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _path(ProviderContainer c) => c.read(routerProvider).routeInformationProvider.value.uri.path;

void main() {
  test('the owner has been told once that the shelf count is overdue; the notice opens the cycle counts', () async {
    final owner = DemoFixture.build()..becomePersona(DemoPersona.owner);
    final notices = [
      for (final e in await owner.events.fetchEvents('ws-1'))
        if (e.type == EventType.stockCountOverdue) e,
    ];
    expect(notices, hasLength(1));
    expect(notices.single.payload['plan'], 'High-value shelf');
    expect(eventDestination(notices.single), '/stock/cycle-counts');
    final member = DemoFixture.build()..becomePersona(DemoPersona.member);
    expect([for (final e in await member.events.fetchEvents('ws-1')) if (e.type == EventType.stockCountOverdue) e], isEmpty);
  });

  for (final (name, size) in [('phone', const Size(390, 2400)), ('desk', const Size(1440, 2400))]) {
    testWidgets('on a $name: the owner counts every line of the open task blind and the task is complete; the counts wait for approval', (tester) async {
      final container = await _open(tester, persona: DemoPersona.owner, size: size);
      container.read(routerProvider).go('/stock/cycle-counts');
      await _frames(tester);
      expect(find.byKey(const ValueKey('stock-cycle-task-demo-count-task-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stock-cycle-task-demo-count-task-1')));
      await _frames(tester);
      expect(_path(container), '/stock/cycle-counts/demo-count-task-1');
      expect(find.text(_en.stockCycleBlind), findsOneWidget);
      var counted = 0;
      for (var i = 0; i < 20; i++) {
        final next = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('stock-cycle-count-demo-count-line-'));
        if (next.evaluate().isEmpty) break;
        await tester.tap(next.first);
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-cycle-observed')), '1');
        await tester.tap(find.byKey(const ValueKey('stock-cycle-count-save')));
        await _frames(tester);
        counted++;
      }
      expect(counted, greaterThan(0), reason: 'the high-value shelf has goods to count');
      expect(find.byKey(const ValueKey('stock-cycle-done')), findsOneWidget, reason: 'every line counted: the task is complete');
      final counts = await container.read(stockReversalsProvider).counts(demoFirstSpaceId);
      expect(counts.where((c) => c.state == StockCountState.recorded), hasLength(counted), reason: 'each count waits for approval in the counts of #4172');
    });
  }

  testWidgets('the owner reads the plan and the history; a member who may not count is turned away', (tester) async {
    final container = await _open(tester, persona: DemoPersona.owner, size: const Size(900, 2400));
    container.read(routerProvider).go('/stock/cycle-counts');
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('stock-cycle-tab-plans')));
    await _frames(tester);
    expect(find.byKey(const ValueKey('stock-cycle-plan-demo-count-plan-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stock-cycle-tab-history')));
    await _frames(tester);
    expect(find.byKey(const ValueKey('stock-cycle-history-empty')), findsNothing, reason: 'the beans were counted before');
  });

  testWidgets('a member who may not count is turned away from the cycle counts', (tester) async {
    final container = await _open(tester, persona: DemoPersona.member, size: const Size(900, 2400), to: '/reserve');
    container.read(routerProvider).go('/stock/cycle-counts');
    await _frames(tester);
    expect(_path(container), isNot('/stock/cycle-counts'));
  });
}
