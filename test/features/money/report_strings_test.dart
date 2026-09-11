// SPDX-License-Identifier: 0BSD
//
// #1061 — ReportStrings is the seam between the ARB and the document
// builders. Two things must hold: the English defaults ARE the English
// ARB (so the CLI and a builder handed no bundle render the same words
// the app renders), and `reportStringsOf` reads every field from the
// bundle it is given (so a localized document does not silently fall
// back to English for one field).
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the defaults are the English ARB, field for field', () {
    const d = ReportStrings();
    final en = reportStringsOf(AppLocalizationsEn());
    expect(d.paymentTermsDefault, en.paymentTermsDefault);
    expect(d.latePenaltyDefault, en.latePenaltyDefault);
    expect(d.recoveryDefault, en.recoveryDefault);
    expect(d.escompteDefault, en.escompteDefault);
    expect(d.accessorySupplements, en.accessorySupplements);
    expect(d.levelReservations, en.levelReservations);
    expect(d.officeReservations, en.officeReservations);
    expect(d.deskReservations, en.deskReservations);
    expect(d.lineAdjustment, en.lineAdjustment);
    expect(d.categoryPayment, en.categoryPayment);
    expect(d.categoryExpense, en.categoryExpense);
    expect(d.categorySubscription, en.categorySubscription);
    expect(d.categoryOverage, en.categoryOverage);
    expect(d.categoryAdjustment, en.categoryAdjustment);
    expect(d.categoryService, en.categoryService);
    expect(d.courtesyMr, en.courtesyMr);
    expect(d.courtesyMrs, en.courtesyMrs);
    expect(d.overage(3), en.overage(3));
    expect(d.participation(50), en.participation(50));
    expect(d.subscription(100), en.subscription(100));
    expect(d.participationMonth('September', 50),
        en.participationMonth('September', 50));
    expect(d.subscriptionMonth('September', 100),
        en.subscriptionMonth('September', 100));
    // No bundle means no locale: intl's default, as before the seam.
    expect(d.localeName, isNull);
    expect(en.localeName, 'en');
  });

  test('a French bundle reaches every field — nothing stays English', () {
    final fr = reportStringsOf(AppLocalizationsFr(), dateLocale: 'fr');
    const d = ReportStrings();
    expect(fr.localeName, 'fr');
    expect(fr.dateLocale, 'fr');
    for (final (a, b) in [
      (fr.paymentTermsDefault, d.paymentTermsDefault),
      (fr.latePenaltyDefault, d.latePenaltyDefault),
      (fr.recoveryDefault, d.recoveryDefault),
      (fr.escompteDefault, d.escompteDefault),
      (fr.accessorySupplements, d.accessorySupplements),
      (fr.levelReservations, d.levelReservations),
      (fr.officeReservations, d.officeReservations),
      (fr.deskReservations, d.deskReservations),
      (fr.lineAdjustment, d.lineAdjustment),
      (fr.categoryPayment, d.categoryPayment),
      (fr.categoryExpense, d.categoryExpense),
      (fr.categorySubscription, d.categorySubscription),
      (fr.categoryOverage, d.categoryOverage),
      // categoryService is 'Service' in both languages — not listed.
      (fr.courtesyMrs, d.courtesyMrs),
      (fr.overage(3), d.overage(3)),
      (fr.participation(50), d.participation(50)),
      (fr.subscription(100), d.subscription(100)),
    ]) {
      expect(a, isNot(b), reason: 'French should differ from English: $a');
    }
    expect(fr.courtesyWord(Courtesy.mr), AppLocalizationsFr().courtesyMr);
    expect(fr.courtesyWord(Courtesy.none), '');
  });

  test('a builder renders from the strings alone — no Flutter, no context',
      () {
    const line = InvoiceLine(
        kind: 'subscription', label: '100', amountCents: 10000);
    expect(invoiceLineText(const ReportStrings(), line), 'Subscription 100%');
    expect(invoiceLineText(reportStringsOf(AppLocalizationsFr()), line),
        AppLocalizationsFr().billSubscription(100));
  });
}
