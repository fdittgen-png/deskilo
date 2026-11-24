// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the words of the quote screens that more than one of them
// says: a status, a server refusal, the amount of a sent revision and a date.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/billing_customer.dart';
import '../../domain/customer_quote.dart';

/// The status a person reads: a sent quote past its validity says expired.
String quoteStatusLabel(AppLocalizations l10n, CustomerQuote q) {
  if (q.expired && q.status == QuoteStatus.sent) return l10n.quoteStatusExpired;
  return switch (q.status) {
    QuoteStatus.draft => l10n.invoicingStatusDraft,
    QuoteStatus.sent => l10n.quoteStatusSent,
    QuoteStatus.accepted => l10n.quoteStatusAccepted,
    QuoteStatus.declined => l10n.quoteStatusDeclined,
    QuoteStatus.cancelled => l10n.quoteStatusCancelled,
    QuoteStatus.converted => l10n.quoteStatusConverted,
  };
}

/// What to say for a refusal of the server; nothing was written.
String quoteRefusalText(AppLocalizations l10n, QuoteRefusal refusal) =>
    switch (refusal.kind) {
      QuoteRefusalKind.stale => l10n.quoteStale,
      QuoteRefusalKind.state => l10n.quoteStateRefused,
      QuoteRefusalKind.expired => l10n.quoteExpiredRefusal,
      QuoteRefusalKind.needsReview => l10n.quoteConvertNeedsReview,
      QuoteRefusalKind.incomplete => l10n.quoteIncomplete(
        refusal.missing.isEmpty ? '-' : refusal.missing.join(', '),
      ),
      QuoteRefusalKind.featureOff => l10n.quoteFeatureOff,
      QuoteRefusalKind.notAllowed => l10n.quoteNotAllowedAction,
      QuoteRefusalKind.other => l10n.quoteUnreached,
    };

/// A date of the offer, in the reader's own locale.
String quoteDate(BuildContext context, DateTime d) =>
    appFormatOf(context).dates(DateShape.date).format(d);

/// An amount of a sent revision, in its own currency.
String quoteAmount(BuildContext context, QuoteTotals totals) =>
    personalFormatOf(context).moneyNamed(totals.currency).formatMinor(totals.totalCents);

/// The customers' names by subject, for the rows that name one.
Map<String, String> quoteCustomerNames(List<BillingParty> customers) => {
  for (final c in customers) c.subjectId: c.displayName,
};
