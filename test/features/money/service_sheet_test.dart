// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3552 — one service editor, for the services screen and the setup step: a
// problem is said under its own field and nothing is stored; what a service
// says about itself (description, duration, category, shown on the public
// page) is saved with it; a VAT rate that could not be read is said, never a
// missing field; the list groups the services by category, the uncategorised
// last, and fits a phone. The Demo's practice has six services in two
// categories, its sessions with their durations.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_money_seed.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> _pump(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  Size size = const Size(800, 1600),
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: money),
        ...extra,
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/services'),
  );
  await tester.pumpAndSettle();
  return money;
}

Future<void> _openNew(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('each problem is said under its field, and nothing is stored', (
    tester,
  ) async {
    final money = await _pump(tester);
    final before = money.services.length;
    await _openNew(tester);
    await tester.enterText(_key('services-price'), '12');
    await tester.enterText(_key('services-duration'), '3');
    await _tap(tester, _key('services-save'));
    expect(money.services, hasLength(before));
    expect(find.text('Please answer this.'), findsOneWidget, reason: 'name');
    expect(find.text('Between 5 and 1440 minutes.'), findsOneWidget);
  });

  testWidgets('what a service says about itself is saved with it, the public '
      'page only when switched on', (tester) async {
    final money = await _pump(tester);
    await _openNew(tester);
    await tester.enterText(_key('services-name'), 'Coaching');
    await tester.enterText(_key('services-price'), '80');
    await tester.enterText(_key('services-description'), 'One hour, one goal.');
    await tester.enterText(_key('services-duration'), '50');
    await tester.enterText(_key('services-category'), 'Sessions');
    expect(
      tester.widget<SwitchListTile>(_key('services-public')).value,
      isFalse,
      reason: 'nothing is public until the business says so',
    );
    await _tap(tester, _key('services-public'));
    await _tap(tester, _key('services-save'));
    final saved = money.services.singleWhere((s) => s.name == 'Coaching');
    expect(
      (
        saved.priceCents,
        saved.description,
        saved.durationMinutes,
        saved.category,
        saved.isPublic,
      ),
      (8000, 'One hour, one goal.', 50, 'Sessions', true),
    );
  });

  testWidgets('VAT rates that could not be read are said, with Try again, '
      'and nothing can be saved without them', (tester) async {
    var answering = false;
    await _pump(
      tester,
      extra: [
        vatRatesProvider.overrideWith((ref) async {
          if (!answering) throw StateError('the rates could not be read');
          return const [];
        }),
      ],
    );
    await _openNew(tester);
    expect(_key('services-vat-rates-failed'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('services-save')).onPressed,
      isNull,
    );
    answering = true;
    await _tap(tester, find.text('Try again'));
    expect(_key('services-vat-rates-failed'), findsNothing);
    expect(
      tester.widget<FilledButton>(_key('services-save')).onPressed,
      isNotNull,
    );
  });

  testWidgets('the list groups by category, the uncategorised last, with '
      'durations, and fits a 320 px phone', (tester) async {
    final money = FakeMoneyRepository();
    money.services
      ..clear()
      ..addAll(const [
        ServiceItem(
          id: 'a',
          workspaceId: 'ws-1',
          name: 'Coffee',
          priceCents: 150,
          active: true,
        ),
        ServiceItem(
          id: 'b',
          workspaceId: 'ws-1',
          name: 'Session',
          priceCents: 8000,
          active: true,
          category: 'Sessions',
          durationMinutes: 50,
        ),
        ServiceItem(
          id: 'c',
          workspaceId: 'ws-1',
          name: 'Workshop',
          priceCents: 4000,
          active: true,
          category: 'Groups',
          durationMinutes: 120,
        ),
      ]);
    await _pump(tester, money: money, size: const Size(320, 1200));
    final groups = find.text('Groups');
    final sessions = find.text('Sessions');
    final other = find.text('Other services');
    expect(groups, findsOneWidget);
    expect(sessions, findsOneWidget);
    expect(other, findsOneWidget);
    expect(
      tester.getTopLeft(groups).dy,
      lessThan(tester.getTopLeft(sessions).dy),
    );
    expect(
      tester.getTopLeft(sessions).dy,
      lessThan(tester.getTopLeft(other).dy),
    );
    expect(find.textContaining('50 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test("the Demo's practice has six services in two categories, its sessions "
      'with their durations', () {
    final money = FakeMoneyRepository();
    seedLeipzigMoney(money, DateTime(2026, 5, 13));
    final services = money.services;
    expect(services, hasLength(6));
    expect(services.map((s) => s.category).toSet(), hasLength(2));
    final timed = services.where((s) => s.durationMinutes != null);
    expect(timed, hasLength(4));
    expect(timed.every((s) => s.isPublic && s.description.isNotEmpty), isTrue);
  });
}
