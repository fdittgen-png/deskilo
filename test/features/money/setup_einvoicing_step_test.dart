// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — the e-invoicing step of the setup guide. The platform reads as
// the server stores it: none, saved but unable to send, or sending through
// its connector. While no test environment is ready, the connector's
// documented test address is offered, and a connector without one says to
// ask for it; a ready test environment is named instead. The guide sends
// nothing: the test send is named as a step from an issued invoice, and
// the platform's own screen is one tap away. Beside it, what the law asks
// in the space's country comes from the tax reference data — France's
// dated duties, each date the data has, flagged unconfirmed while no one
// confirmed it; a country without a row says so and names who acts; a
// country the server refuses to issue for says it is refused. One column
// on a phone.
import 'package:deskilo/app/routes/setup_grow_pages.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/einvoice_mandates.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

FakeWorkspaceRepository _repo(String country) {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] = repo.workspaces[0].copyWith(countryCode: country);
  return repo;
}

List<Override> _overrides({
  String country = 'FR',
  FakeMoneyRepository? money,
  EInvoiceProviderStatus? status,
}) => [
  ...standardTestOverrides(workspace: _repo(country), money: money),
  if (status != null)
    eInvoiceStatusProvider.overrideWith((ref) async => status),
];

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'einvoicing', growPages: setupGrowPages),
    size: _phone,
    overrides: overrides,
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets('nothing set up: it says so, names the test send, and lists '
      'France\'s dated duties from the reference data, unconfirmed', (
    tester,
  ) async {
    await _pump(tester, _overrides());
    expect(
      _text(tester, 'setup-einvoicing-platform'),
      'No e-invoicing platform is set up yet.',
    );
    expect(
      find.byKey(const ValueKey('setup-einvoicing-no-sandbox')),
      findsOneWidget,
      reason: 'the generic connector has no shared test address',
    );
    expect(
      find.byKey(const ValueKey('setup-einvoicing-test-send')),
      findsOneWidget,
    );

    final duties = mandatesFor('FR');
    expect(duties, isNotEmpty, reason: 'the bundled reference has FR rows');
    final dates = DateFormat.yMMMd('en');
    for (final (index, duty) in duties.indexed) {
      final text = _text(tester, 'setup-einvoicing-duty-$index');
      expect(text, contains(dates.format(duty.from)));
      expect(text, startsWith(duty.inForceOn(kTestNow) ? 'Since ' : 'From '));
    }
    expect(
      find.byKey(ValueKey('setup-einvoicing-duty-${duties.length}')),
      findsNothing,
    );
    expect(duties.any((d) => !d.confirmed), isTrue);
    expect(
      find.byKey(const ValueKey('setup-einvoicing-unconfirmed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('setup-einvoicing-refused')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Peppol platform with no test environment yet: the '
      'documented test address, and a platform that cannot send says so', (
    tester,
  ) async {
    await _pump(
      tester,
      _overrides(
        status: const EInvoiceProviderStatus(
          configured: true,
          provider: 'peppol',
        ),
      ),
    );
    expect(
      _text(tester, 'setup-einvoicing-platform'),
      contains('cannot send yet'),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-einvoicing-sandbox-base_url')),
        matching: find.text('https://api.storecove.com'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a platform that sends, with a test environment ready: the '
      'environment is named instead of an address', (tester) async {
    final money = FakeMoneyRepository()
      ..einvoiceGateway = const EInvoiceGatewayConfig(
        configured: true,
        provider: 'peppol',
        environments: {'prod': true, 'uat': true},
      );
    await _pump(
      tester,
      _overrides(
        money: money,
        status: const EInvoiceProviderStatus(
          configured: true,
          provider: 'peppol',
        ),
      ),
    );
    expect(
      _text(tester, 'setup-einvoicing-platform'),
      startsWith('Invoices are sent through '),
    );
    expect(_text(tester, 'setup-einvoicing-test-ready'), contains('UAT'));
    expect(
      find.byKey(const ValueKey('setup-einvoicing-sandbox')),
      findsNothing,
    );
  });

  testWidgets('a country without a row says so; one the server refuses '
      'to issue for says it is refused', (tester) async {
    expect(mandatesFor('CH'), isEmpty);
    await _pump(tester, _overrides(country: 'CH'));
    expect(
      find.byKey(const ValueKey('setup-einvoicing-no-mandate')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('setup-einvoicing-refused')),
      findsNothing,
    );

    expect(nationalChannelRequired, contains('IT'));
    await _pump(tester, _overrides(country: 'IT'));
    expect(
      find.byKey(const ValueKey('setup-einvoicing-refused')),
      findsOneWidget,
    );
  });

  testWidgets('the link opens the platform screen', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SetupStepScreen(
            stepId: 'einvoicing',
            growPages: setupGrowPages,
          ),
        ),
        GoRoute(
          path: '/einvoice-config',
          builder: (_, _) => const Text('platform screen'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpApp(
      tester,
      null,
      router: router,
      size: _phone,
      overrides: _overrides(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-einvoicing-open')));
    await tester.pumpAndSettle();
    expect(find.text('platform screen'), findsOneWidget);
  });
}
