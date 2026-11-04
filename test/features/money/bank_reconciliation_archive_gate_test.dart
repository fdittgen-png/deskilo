// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Archive bank reports require the bank feature and the existing reader permissions.
import 'package:deskilo/features/money/presentation/bank_reconciliation_archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('archive bank report uses bank feature and existing reader rights', () {
    bool allowed({
      required bool feature,
      bool owner = false,
      Set<String> held = const {},
    }) => BankReconciliationArchive.mayIncludeBankReconciliation(
      featureOn: feature,
      owner: owner,
      permissions: held,
    );
    expect(allowed(feature: true, owner: true), isTrue);
    expect(allowed(feature: true, held: {'viewFinances'}), isTrue);
    expect(allowed(feature: true, held: {'issueInvoices'}), isTrue);
    expect(allowed(feature: true, held: {'managePurchases'}), isFalse);
    expect(allowed(feature: false, owner: true), isFalse);
    expect(allowed(feature: false, held: {'viewFinances'}), isFalse);
  });
}
