// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the services step of the setup guide. The catalogue is listed as
// stored, archived services included and marked; the preview is the list a
// member picks from when adding a consumption, the active services only,
// each with its price. Adding stores a new active service at the typed
// gross price and it joins the preview; a service without a name or a
// price stores nothing. With no active service the preview says members
// have nothing to add. One column on a phone.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

Future<void> _pump(WidgetTester tester, FakeMoneyRepository money) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'services', runPages: setupRunPages),
    size: _phone,
    overrides: standardTestOverrides(money: money),
  );
  await tester.pumpAndSettle();
}

Finder _inPreview(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('setup-step-preview')),
  matching: f,
);

void main() {
  testWidgets('the catalogue as stored; the preview lists only what a '
      'member can add, with its price', (tester) async {
    await _pump(tester, FakeMoneyRepository());
    for (final id in ['coffee', 'locker', 'printing']) {
      expect(
        find.byKey(ValueKey('setup-services-stored-service-$id')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-services-stored-service-locker')),
        matching: find.text('€5.00 · Inactive'),
      ),
      findsOneWidget,
    );
    expect(_inPreview(find.text('Coffee — €1.50')), findsOneWidget);
    expect(_inPreview(find.text('Printing — €0.20')), findsOneWidget);
    expect(
      _inPreview(
        find.byKey(const ValueKey('setup-services-preview-service-locker')),
      ),
      findsNothing,
    );
  });

  testWidgets('adding stores an active service at the typed price, and it '
      'joins the preview; without a price nothing is stored', (tester) async {
    final money = FakeMoneyRepository();
    await _pump(tester, money);
    final before = money.services.length;

    await tester.enterText(
      find.byKey(const ValueKey('setup-services-name')),
      'Locker key',
    );
    await tester.tap(find.byKey(const ValueKey('setup-services-add')));
    await tester.pump();
    expect(money.services, hasLength(before), reason: 'no price, no write');

    await tester.enterText(
      find.byKey(const ValueKey('setup-services-price')),
      '2.50',
    );
    await tester.tap(find.byKey(const ValueKey('setup-services-add')));
    await tester.pumpAndSettle();
    final added = money.services.last;
    expect(money.services, hasLength(before + 1));
    expect(
      (added.name, added.priceCents, added.active),
      ('Locker key', 250, true),
    );
    expect(_inPreview(find.text('Locker key — €2.50')), findsOneWidget);
  });

  testWidgets('no active service: members have nothing to add; one column '
      'on a phone', (tester) async {
    final money = FakeMoneyRepository()..services.removeWhere((s) => s.active);
    await _pump(tester, money);
    expect(
      find.byKey(const ValueKey('setup-services-preview-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
