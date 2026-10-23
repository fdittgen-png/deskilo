// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — the reminders step of the setup guide. The reminder rules
// dialog's own fields arrive prefilled from the stored policy and save
// through its one write. The preview is the reminder a member receives,
// redrawn as the owner changes a field and before anything is saved: the
// message it goes out with for a sample invoice, the payment conditions the
// letter recalls (or that it recalls none), when each level falls due and
// who sends it. Saving stores exactly the drafted policy; the payment
// conditions are one tap away on the legal identity. One column on a
// phone.
import 'package:deskilo/app/routes/setup_grow_pages.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/report_data_sample.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

// The first delay is also a setting (`dunning.first_after_days`), read over
// the stored rules: the fixture keeps the two equal, at the registry's
// default (the rules' own default too).
const _stored = DunningRules(levels: 2, betweenDays: 7);

FakeWorkspaceRepository _repo({String terms = ''}) {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    invoiceLegal: {if (terms.isNotEmpty) 'payment_terms': terms},
  );
  return repo;
}

Future<FakeMoneyRepository> _pump(
  WidgetTester tester, {
  String terms = '',
}) async {
  final money = FakeMoneyRepository()..dunningRules = _stored;
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'reminders', growPages: setupGrowPages),
    size: _phone,
    overrides: standardTestOverrides(
      workspace: _repo(terms: terms),
      money: money,
    ),
  );
  await tester.pumpAndSettle();
  return money;
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

int _dropdown(WidgetTester tester, String key) =>
    tester.widget<DropdownButton<int>>(find.byKey(ValueKey(key))).value!;

void main() {
  testWidgets('the stored rules prefilled; the preview is the message for a '
      'sample invoice, each level\'s delay and who sends it', (tester) async {
    await _pump(tester);
    expect(_dropdown(tester, 'dunning-levels'), 2);
    expect(
      _dropdown(tester, 'dunning-first-days'),
      SettingDefaults.dunningFirstAfterDays,
    );
    expect(_dropdown(tester, 'dunning-between-days'), 7);

    final amount = moneyFormat(
      'EUR',
      locale: 'en',
    ).formatMinor(SampleInvoice.grossCents);
    expect(
      _text(tester, 'setup-reminders-message'),
      'Friendly reminder: invoice SAMPLE — balance due $amount.',
    );
    expect(
      _text(tester, 'setup-reminders-level-1'),
      'Reminder 1: ${SettingDefaults.dunningFirstAfterDays} days after the '
      'invoice, once its payment term has passed.',
    );
    expect(
      _text(tester, 'setup-reminders-level-2'),
      'Reminder 2: 7 days after the previous one.',
    );
    expect(find.byKey(const ValueKey('setup-reminders-level-3')), findsNothing);
    expect(
      _text(tester, 'setup-reminders-who'),
      'You send each reminder yourself; the app shows when one is due.',
    );
    expect(
      _text(tester, 'setup-reminders-terms-printed'),
      'No payment conditions are written yet: the letter cites none.',
    );
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a change moves the preview before anything is saved; Save '
      'stores exactly the drafted rules', (tester) async {
    final money = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('dunning-levels')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dunning-automatic')));
    await tester.pump();

    expect(
      _text(tester, 'setup-reminders-level-3'),
      'Reminder 3: 7 days after the previous one.',
    );
    expect(
      _text(tester, 'setup-reminders-who'),
      'The app sends each reminder by itself once a day, for the amount '
      'still owed.',
    );
    expect(money.dunningRules, _stored, reason: 'nothing saved yet');

    await tester.tap(find.byKey(const ValueKey('setup-reminders-save')));
    await tester.pumpAndSettle();
    expect(
      money.dunningRules,
      const DunningRules(betweenDays: 7, automatic: true),
    );
    expect(find.text('Reminder rules saved.'), findsOneWidget);
  });

  testWidgets('the payment conditions the letter recalls, edited with the '
      'legal identity', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SetupStepScreen(
            stepId: 'reminders',
            growPages: setupGrowPages,
          ),
        ),
        GoRoute(
          path: '/legal-identity',
          builder: (_, _) => const Text('legal identity screen'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpApp(
      tester,
      null,
      router: router,
      size: _phone,
      overrides: standardTestOverrides(
        workspace: _repo(terms: 'Payable within 30 days.'),
        money: FakeMoneyRepository()..dunningRules = _stored,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _text(tester, 'setup-reminders-terms-printed'),
      'The letter recalls your payment conditions: Payable within 30 days.',
    );
    await tester.tap(find.byKey(const ValueKey('setup-reminders-terms')));
    await tester.pumpAndSettle();
    expect(find.text('legal identity screen'), findsOneWidget);
  });
}
