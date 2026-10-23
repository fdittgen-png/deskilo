// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — the legal identity step of the setup guide. The fields arrive
// prefilled from the stored identity, the preview is the top of the sample
// invoice exactly as the invoice bands print it and follows the typing
// before anything is saved, and Save writes the identity through the legal
// identity command while every legal mention the step does not show stays
// as stored. The regime decides which number is asked for. What to ask an
// accountant and what locks after the first invoice are said on the page,
// and a new regime is confirmed before it is saved: every invoice keeps the
// regime it is issued with. Cancel saves nothing.
// One column on a phone.
import 'package:deskilo/app/routes/setup_grow_pages.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 3200);

FakeWorkspaceRepository _repo() {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    address: 'Hauptstraße 1, 10115 Berlin',
    vatRegime: 'vat_registered',
    vatId: 'DE123456789',
    legalId: 'HRB 4711',
    street: 'Hauptstraße 1',
    postalCode: '10115',
    city: 'Berlin',
    invoiceLegal: {
      'legal_form': 'GmbH',
      'registration': 'Amtsgericht Berlin HRB 4711',
      'payment_terms': 'Payable within 14 days',
      'insurance': 'Allianz, policy 42',
    },
  );
  return repo;
}

Future<void> _pump(WidgetTester tester, FakeWorkspaceRepository repo) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'legal_identity', growPages: setupGrowPages),
    size: _phone,
    overrides: standardTestOverrides(workspace: repo),
  );
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String key) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextField),
        matchRoot: true,
      ),
    )
    .controller!
    .text;

Finder _inPreview(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('setup-legal-preview')),
  matching: f,
);

void main() {
  testWidgets('prefilled from the stored identity, the printed seller block '
      'beside it follows the typing, and Save keeps every other mention', (
    tester,
  ) async {
    final repo = _repo();
    await _pump(tester, repo);
    expect(_field(tester, 'setup-legal-vat-id'), 'DE123456789');
    expect(_field(tester, 'setup-legal-form'), 'GmbH');
    expect(
      _field(tester, 'setup-legal-registration'),
      'Amtsgericht Berlin HRB 4711',
    );
    expect(_field(tester, 'legal-identity-city'), 'Berlin');
    expect(find.byKey(const ValueKey('setup-legal-legal-id')), findsNothing);

    // The header band as the invoice prints it: name, form, address, VAT.
    expect(_inPreview(find.text('Test Space')), findsWidgets);
    expect(_inPreview(find.text('GmbH')), findsOneWidget);
    expect(
      _inPreview(find.text('Hauptstraße 1, 10115 Berlin')),
      findsOneWidget,
    );
    expect(_inPreview(find.textContaining('DE123456789')), findsOneWidget);
    expect(
      _inPreview(find.byKey(const ValueKey('setup-sample-badge'))),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('setup-legal-form')),
      'GmbH, Stammkapital 25.000 €',
    );
    await tester.pump();
    expect(
      _inPreview(find.text('GmbH, Stammkapital 25.000 €')),
      findsOneWidget,
    );
    expect(
      repo.workspaces.first.invoiceLegal['legal_form'],
      'GmbH',
      reason: 'nothing is saved before Save',
    );

    await tester.tap(find.byKey(const ValueKey('setup-legal-save')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('lock-confirm-body')),
      findsNothing,
      reason: 'the stored regime asks nothing',
    );
    final saved = repo.workspaces.first;
    expect(saved.invoiceLegal['legal_form'], 'GmbH, Stammkapital 25.000 €');
    expect(saved.invoiceLegal['registration'], 'Amtsgericht Berlin HRB 4711');
    expect(saved.invoiceLegal['payment_terms'], 'Payable within 14 days');
    expect(saved.invoiceLegal['insurance'], 'Allianz, policy 42');
    expect(saved.vatRegime, 'vat_registered');
    expect(saved.vatId, 'DE123456789');
    expect(saved.legalId, 'HRB 4711');
    expect(find.text('Legal identity saved.'), findsOneWidget);
  });

  testWidgets('outside the scope of VAT asks for the registration number, '
      'and Save names what each invoice keeps before it stores the regime', (
    tester,
  ) async {
    final repo = _repo();
    await _pump(tester, repo);
    await tester.tap(find.byKey(const ValueKey('setup-legal-regime')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outside the scope of VAT').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup-legal-vat-id')), findsNothing);
    expect(_field(tester, 'setup-legal-legal-id'), 'HRB 4711');
    expect(repo.workspaces.first.vatRegime, 'vat_registered');

    await tester.tap(find.byKey(const ValueKey('setup-legal-save')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('lock-confirm-body'))).data,
      'Every invoice keeps the VAT regime it is issued with, for good: '
      '“Outside the scope of VAT” applies from the next invoice on, and '
      'invoices already issued do not change.',
    );
    await tester.tap(find.byKey(const ValueKey('lock-confirm-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('lock-confirm-body')), findsNothing);
    expect(repo.workspaces.first.vatRegime, 'vat_registered',
        reason: 'cancel saves nothing');

    await tester.tap(find.byKey(const ValueKey('setup-legal-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('lock-confirm-save')));
    await tester.pumpAndSettle();
    expect(repo.workspaces.first.vatRegime, 'not_subject');
  });

  testWidgets('what to ask an accountant and what locks are on the page; one '
      'column on a phone', (tester) async {
    await _pump(tester, _repo());
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-legal-ask')),
        matching: find.byType(ListTile),
      ),
      findsNWidgets(4),
    );
    expect(find.byKey(const ValueKey('setup-legal-lock')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
