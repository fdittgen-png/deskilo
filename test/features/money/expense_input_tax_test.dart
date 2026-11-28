// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 — an expense keeps its input-tax treatment, the identity of its rate and the facts of its document. The payload the
// RPCs take says which of the four it is: the space's own VAT by the identity of a rate it picked, a purchase from abroad
// (the space owes the tax), or VAT a supplier abroad charged, which is only a fact of the document: no rate of the space,
// no share to deduct, so no return reads it. The sheet asks for what each kind needs, says why the foreign VAT is not
// deducted, and refuses it without the supplier's country or a rate.
import 'package:deskilo/features/money/application/submit_expense.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/expense_vat_kind.dart';
import '../../helpers/screens/money_screen.dart' show pumpMoney;
import '../../helpers/screens/supply_expense.dart' show openExpenseSheet;

ExpenseDraft _draft({
  double? percent,
  String? rateId,
  ForeignVat? foreign,
  Map<String, Object?> facts = const {},
  ExpenseVatFlags flags = (asset: false, acquisition: false),
}) => ExpenseDraft(
  locale: 'en_US',
  amount: '100',
  category: 'supplies',
  vatPercent: percent,
  vatRateId: rateId,
  foreignVat: foreign,
  vatFacts: facts,
  vatFlags: flags,
);

FakeWorkspaceRepository _registered() {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  final ws = workspace.workspaces[0];
  workspace.workspaces[0] = ws.copyWith(
    vatRegime: 'vat_registered',
    featureFlags: {...ws.featureFlags, 'inputVat': true},
  );
  return workspace;
}

FakeMoneyRepository _withRates() => FakeMoneyRepository()
  ..vatRates = const [
    VatRate(id: 'std', label: 'Standard', percent: 20, isDefault: true),
  ];

void main() {
  group('the payload', () {
    test('the space\'s own VAT keeps the identity of the rate picked and the facts of the document', () {
      final vat = _draft(percent: 20, rateId: 'std', facts: {'document_number': 'R-1'}).vat;
      expect(vat, {
        'percent': 20.0,
        'deductible_pct': 100.0,
        'treatment': 'domestic',
        'vat_rate_id': 'std',
        'document_number': 'R-1',
      });
    });

    test('a purchase from abroad is the acquisition treatment, with the country', () {
      final vat = _draft(
        percent: 20,
        rateId: 'std',
        flags: (asset: false, acquisition: true),
        facts: {'supplier_country': 'DE'},
      ).vat!;
      expect(vat['treatment'], 'acquisition');
      expect(vat['acquisition'], true);
      expect(vat['supplier_country'], 'DE');
    });

    test('VAT a supplier abroad charged is a fact: no percent, no rate, no share to deduct', () {
      final vat = _draft(
        foreign: const ForeignVat(percent: 19, taxCents: 1900),
        facts: {'supplier_country': 'DE'},
      ).vat!;
      expect(vat, {
        'treatment': 'foreign_charged',
        'stated_percent': 19.0,
        'stated_tax_cents': 1900,
        'supplier_country': 'DE',
      });
      expect(vat.keys.toSet().intersection({'percent', 'vat_rate_id', 'deductible_pct', 'acquisition'}), isEmpty);
    });

    test('no rate and no foreign VAT is an expense without VAT', () {
      expect(_draft().vat, isNull);
    });
  });

  group('what may be filed', () {
    test('foreign VAT without the supplier\'s country is refused', () {
      expect(
        expenseOutcome(_draft(foreign: const ForeignVat(percent: 19))),
        ExpenseOutcome.missingSupplierCountry,
      );
    });

    test('foreign VAT needs a rate between 0 and 100 and an amount that is not negative', () {
      const facts = {'supplier_country': 'DE'};
      expect(expenseOutcome(_draft(foreign: const ForeignVat(percent: null), facts: facts)), ExpenseOutcome.invalidStatedVat);
      expect(expenseOutcome(_draft(foreign: const ForeignVat(percent: 120), facts: facts)), ExpenseOutcome.invalidStatedVat);
      expect(expenseOutcome(_draft(foreign: const ForeignVat(percent: 19, taxCents: -1), facts: facts)), ExpenseOutcome.invalidStatedVat);
      expect(expenseOutcome(_draft(foreign: const ForeignVat(percent: 19, taxCents: 1900), facts: facts)), ExpenseOutcome.submitted);
    });
  });

  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets('the sheet files VAT a supplier abroad charged as a fact, and says it is not deducted (${size.width.toInt()} wide)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final money = await pumpMoney(tester, money: _withRates(), workspace: _registered());
      await openExpenseSheet(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '119');
      await pickVatKind(tester, 'expense', 'VAT charged by a supplier abroad');

      expect(find.byKey(const ValueKey('expense-vat-rate')), findsNothing, reason: 'no rate of the space reads another country\'s VAT');
      expect(find.byKey(const ValueKey('expense-vat-deductible')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('expense-vat-stated-percent')));
      expect(find.textContaining('not deducted on this return'), findsOneWidget);

      // Without the country and a rate nothing is filed, and the sheet says why.
      await tester.ensureVisible(find.text('Submit for confirmation'));
      await tester.tap(find.text('Submit for confirmation'));
      await tester.pumpAndSettle();
      expect(money.submittedExpenseVat, isEmpty);
      expect(find.text('Pick the supplier\'s country.'), findsOneWidget);

      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('expense-vat-country')), matching: find.byType(TextField)).first, 'DE');
      await tester.enterText(find.byKey(const ValueKey('expense-vat-stated-percent')), '19');
      await tester.enterText(find.byKey(const ValueKey('expense-vat-stated-tax')), '19');
      await tester.ensureVisible(find.text('Submit for confirmation'));
      await tester.tap(find.text('Submit for confirmation'));
      await tester.pumpAndSettle();

      expect(money.submittedExpenseVat.single, {
        'treatment': 'foreign_charged',
        'stated_percent': 19.0,
        'stated_tax_cents': 1900,
        'supplier_country': 'DE',
      });
    });
  }
}
