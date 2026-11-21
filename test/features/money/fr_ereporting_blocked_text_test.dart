// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4163 -- the refusal the France e-reporting shows names every document it
// cannot sort and why, in each of the five languages.
import 'package:deskilo/features/money/domain/fr_ereporting_capacity.dart';
import 'package:deskilo/features/money/presentation/fr_ereporting_blocked_text.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const unresolved = [
    FrUnresolved(
      invoiceId: 'a',
      number: 'F-2026-0001',
      reasons: [FrUnresolvedReason.noFrozenCapacity],
    ),
    FrUnresolved(
      invoiceId: 'b',
      number: 'F-2026-0002',
      reasons: [FrUnresolvedReason.buyerVatIdMissing],
    ),
  ];

  for (final code in ['en', 'fr', 'de', 'es', 'it']) {
    test('$code: every document and every reason is named', () {
      final l10n = lookupAppLocalizations(Locale(code));
      final text = frEReportingBlockedText(l10n, unresolved);
      expect(text, contains('F-2026-0001'));
      expect(text, contains('F-2026-0002'));
      // a select that fell to `other` would print the raw enum name
      expect(text, isNot(contains('noFrozenCapacity')));
      expect(text, isNot(contains('buyerVatIdMissing')));
    });
  }
}
