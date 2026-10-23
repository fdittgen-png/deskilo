// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the payment steps of the setup guide. How members pay: the
// payment methods screen's fields arrive prefilled, the preview is the
// statement's own how-to-pay card and follows the typing before anything
// is saved, and Save stores the instructions on the workspace row.
// Online payments: the operator, not the owner, enters the provider's
// secret, and the step says so; it lists the providers as the config read
// returns them, opens the config screen, and previews the checkout with
// the online button only once a provider is connected. Both pages are one
// column on a phone.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);
const _iban = 'DE89 3704 0044 0532 0130 00';

FakeWorkspaceRepository _repo({Map<String, dynamic> instructions = const {}}) {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    paymentInstructions: instructions,
  );
  return repo;
}

Future<void> _pump(
  WidgetTester tester,
  String stepId, {
  FakeWorkspaceRepository? repo,
  FakeMoneyRepository? money,
}) async {
  await pumpApp(
    tester,
    SetupStepScreen(stepId: stepId, runPages: setupRunPages),
    size: _phone,
    overrides: standardTestOverrides(workspace: repo ?? _repo(), money: money),
  );
  await tester.pumpAndSettle();
}

Finder _inPreview(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('setup-step-preview')),
  matching: f,
);

void main() {
  group('how members pay', () {
    testWidgets('prefilled, and the preview is the statement card, redrawn '
        'as the owner types', (tester) async {
      final repo = _repo(instructions: {'iban': _iban});
      await _pump(tester, 'payment_methods', repo: repo);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('workspaceSettingsIban')))
            .controller!
            .text,
        _iban,
      );
      expect(_inPreview(find.text(_iban)), findsOneWidget);
      expect(_inPreview(find.byKey(const Key('howToPayWero'))), findsNothing);

      await tester.enterText(
        find.byKey(const Key('workspaceSettingsWero')),
        '+33 6 12 34 56 78',
      );
      await tester.pump();
      expect(_inPreview(find.byKey(const Key('howToPayWero'))), findsOneWidget);
      expect(
        _inPreview(find.byKey(const Key('pay-online-button'))),
        findsNothing,
      );
      expect(repo.lastPaymentInstructions, isNull, reason: 'nothing saved');

      await tester.tap(find.byKey(const ValueKey('setup-payments-save')));
      await tester.pumpAndSettle();
      expect(
        repo.workspaces.first.paymentInstructions['wero'],
        '+33 6 12 34 56 78',
      );
      expect(repo.workspaces.first.paymentInstructions['iban'], _iban);
    });

    testWidgets('nothing filled: the preview says members see nothing', (
      tester,
    ) async {
      await _pump(tester, 'payment_methods');
      expect(
        find.byKey(const ValueKey('setup-payments-preview-empty')),
        findsOneWidget,
      );
      expect(_inPreview(find.byType(Card)), findsNothing);
    });

    testWidgets('one column on a phone', (tester) async {
      await _pump(
        tester,
        'payment_methods',
        repo: _repo(instructions: {'iban': _iban}),
      );
      expect(
        find.byKey(const ValueKey('setup-step-one-column')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('online payments', () {
    FakeMoneyRepository connected() => FakeMoneyRepository()
      ..paymentStatus[PaymentProvider.stripe] = const PaymentProviderStatus(
        configured: true,
        secretKeysSet: {'secret_key'},
      );

    testWidgets('the operator enters the secret; the providers as the config '
        'read returns them; the checkout with the online button', (
      tester,
    ) async {
      await _pump(
        tester,
        'online_payments',
        repo: _repo(instructions: {'iban': _iban}),
        money: connected(),
      );
      expect(
        find.byKey(const ValueKey('setup-online-operator')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing, reason: 'no secret asked');
      final stripe = find.byKey(const ValueKey('setup-online-provider-stripe'));
      expect(
        find.descendant(of: stripe, matching: find.text('Configured')),
        findsOneWidget,
      );
      final paypal = find.byKey(const ValueKey('setup-online-provider-paypal'));
      expect(
        find.descendant(of: paypal, matching: find.text('Not configured')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-online-preview-on')),
        findsOneWidget,
      );
      expect(
        _inPreview(find.byKey(const Key('pay-online-button'))),
        findsOneWidget,
      );
      expect(_inPreview(find.text(_iban)), findsOneWidget);
    });

    testWidgets('no provider: the checkout has no online button', (
      tester,
    ) async {
      await _pump(
        tester,
        'online_payments',
        repo: _repo(instructions: {'iban': _iban}),
      );
      expect(
        find.byKey(const ValueKey('setup-online-preview-off')),
        findsOneWidget,
      );
      expect(
        _inPreview(find.byKey(const Key('pay-online-button'))),
        findsNothing,
      );
    });

    testWidgets('the link opens the online payment settings', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SetupStepScreen(
              stepId: 'online_payments',
              runPages: setupRunPages,
            ),
          ),
          GoRoute(
            path: '/payment-config',
            builder: (_, _) => const Text('payment config screen'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpApp(
        tester,
        null,
        router: router,
        size: _phone,
        overrides: standardTestOverrides(workspace: _repo()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-online-open-config')));
      await tester.pumpAndSettle();
      expect(find.text('payment config screen'), findsOneWidget);
    });

    testWidgets('one column on a phone', (tester) async {
      await _pump(tester, 'online_payments', money: connected());
      expect(
        find.byKey(const ValueKey('setup-step-one-column')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
