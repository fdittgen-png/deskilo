// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3811 (part of #3657) -- the invoicing refusals of 0740 and the
// installation's DKR01 are read by their code, never their sentence: each
// code says what it means in the five languages, a reworded server message
// changes nothing, and the invoice runner reads DKI01 and DKI07 by code.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/trace/refusal_text.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_issue_runner.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _languages = ['en', 'fr', 'de', 'es', 'it'];

PostgrestException _refused(String code, {String? details}) =>
    PostgrestException(
      message: 'a sentence nobody pinned',
      code: code,
      details: details,
    );

void main() {
  test('each code is its family, whatever the sentence says', () {
    for (final code in [DkCode.dki03, DkCode.dki04, DkCode.dki05, DkCode.dki06]) {
      expect(
        knownRefusalOf(_refused(code)),
        KnownRefusal.changedMeanwhile,
        reason: code,
      );
    }
    expect(knownRefusalOf(_refused(DkCode.dkd01)), KnownRefusal.alreadyDecided);
    expect(
      knownRefusalOf(_refused(DkCode.dkr01)),
      KnownRefusal.personalHomeHostsNoWorkspace,
    );
  });

  test('they say what they mean in the five languages', () {
    for (final language in _languages) {
      final l10n = lookupAppLocalizations(Locale(language));
      expect(
        knownRefusalText(l10n, _refused(DkCode.dki03)),
        l10n.refusalChangedMeanwhile,
        reason: language,
      );
      expect(
        knownRefusalText(l10n, _refused(DkCode.dkd01)),
        l10n.refusalAlreadyDecided,
        reason: language,
      );
      final home = knownRefusalText(l10n, _refused(DkCode.dkr01));
      expect(home, l10n.refusalPersonalHomeHostsNoWorkspace, reason: language);
      expect(home, isNotEmpty, reason: language);
    }
  });

  test('the invoice runner reads DKI07 and DKI01 by code', () {
    for (final language in _languages) {
      final l10n = lookupAppLocalizations(Locale(language));
      expect(
        invoiceRefusalText(l10n, _refused(DkCode.dki07)),
        l10n.invoiceAlreadyInvoiced,
        reason: language,
      );
      expect(
        invoiceRefusalText(
          l10n,
          _refused(DkCode.dki01, details: 'invoice_feature_disabled'),
        ),
        l10n.invoiceFeatureDisabled,
        reason: language,
      );
      expect(
        invoiceRefusalText(l10n, _refused(DkCode.dki01, details: 'seller_address')),
        l10n.invoiceEssentialsRefused,
        reason: language,
      );
      // #3994 — a correction of another kind than the invoice it replaces.
      expect(
        invoiceRefusalText(l10n, _refused(DkCode.dki08)),
        l10n.invoiceCorrectionKeepsKind,
        reason: language,
      );
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      invoiceRefusalText(en, _refused('XX000'), fallback: 'fb'),
      'fb',
      reason: 'another code is not read as an invoicing refusal',
    );
  });
}
