// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- INTENDED behaviour change of moving the filing file's button behind
// the VAT filing contract (#3460): the add-on is asked through
// `LegalContext.normalized` like every other capability, so a lower-case or
// padded country code and `UK` resolve to the filing of that country. Before
// the move the label switch compared the code exactly and answered nothing for
// any of them; no caller passes one today (a workspace's country is stored as
// the registry spells it). The baseline pins (`vat_filing_actions_pins_test`)
// are unchanged.
import 'package:deskilo/features/money/presentation/vat_filing_file_actions.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intended: harmonised with LegalContext.normalized (case, padding, '
      'UK is GB)', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(vatFilingFileLabel(l10n, 'de'), l10n.vatDeclElster);
    expect(vatFilingFileLabel(l10n, ' DE '), l10n.vatDeclElster);
    expect(vatFilingFileLabel(l10n, 'UK'), l10n.vatDeclMtdCsv);
  });
}
