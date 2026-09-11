// SPDX-License-Identifier: 0BSD
import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/report_strings.dart';

/// #1061 — the ONE place a document's words are read out of the ARB.
/// Every value here is exactly the `l10n?.x ?? 'default'` the builders
/// used to compute inline, so a rendered document is byte-identical
/// before and after the seam.
ReportStrings reportStringsOf(AppLocalizations? l10n, {String? dateLocale}) {
  if (l10n == null) return ReportStrings(dateLocale: dateLocale);
  return ReportStrings(
    localeName: l10n.localeName,
    dateLocale: dateLocale,
    paymentTermsDefault: l10n.invoiceLegalPaymentTermsDefault,
    latePenaltyDefault: l10n.invoiceLegalLatePenaltyDefault,
    recoveryDefault: l10n.invoiceLegalRecoveryDefault,
    escompteDefault: l10n.invoiceLegalEscompteDefault,
    accessorySupplements: l10n.billAccessorySupplements,
    levelReservations: l10n.levelSupplementLabel,
    officeReservations: l10n.officeSupplementLabel,
    deskReservations: l10n.deskSupplementLabel,
    lineAdjustment: l10n.invoiceLineAdjustment,
    categoryPayment: l10n.ledgerCategoryPayment,
    categoryExpense: l10n.ledgerCategoryExpense,
    categorySubscription: l10n.ledgerCategorySubscription,
    categoryOverage: l10n.ledgerCategoryOverage,
    categoryAdjustment: l10n.ledgerCategoryAdjustment,
    categoryService: l10n.ledgerCategoryService,
    courtesyMr: l10n.courtesyMr,
    courtesyMrs: l10n.courtesyMrs,
    overage: l10n.billOverage,
    participation: l10n.billParticipation,
    subscription: l10n.billSubscription,
    participationMonth: l10n.billParticipationMonth,
    subscriptionMonth: l10n.billSubscriptionMonth,
  );
}

/// The widget boundary: what a screen hands a builder.
ReportStrings reportStringsFor(BuildContext context) => reportStringsOf(
      AppLocalizations.of(context),
      dateLocale: Localizations.maybeLocaleOf(context)?.toString(),
    );
