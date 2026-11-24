// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the words of a billing-access refusal (DKH01 to DKH05 and the
// seller's right), shared by the seller's invitation dialog and the account's
// code dialog.
import '../../../../core/failure/app_failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/billing_access.dart';

String _refusalText(AppLocalizations l10n, BillingAccessRefusalKind kind) =>
    switch (kind) {
      BillingAccessRefusalKind.notAllowed => l10n.billingAccessNotAllowed,
      BillingAccessRefusalKind.codeUnusable => l10n.billingAccessCodeUnusable,
      BillingAccessRefusalKind.notACustomer => l10n.billingAccessNotACustomer,
      BillingAccessRefusalKind.unknownGrant => l10n.billingAccessUnknownGrant,
      BillingAccessRefusalKind.reasonTooLong => l10n.billingAccessReasonTooLong,
      BillingAccessRefusalKind.requestReused => l10n.billingAccessRequestReused,
      BillingAccessRefusalKind.other => l10n.billingAccessFailed,
    };

/// The sentence of an outcome that did not succeed; null when it did.
String? billingAccessProblemText<T>(
  AppLocalizations l10n,
  CommandOutcome<T> outcome,
) => switch (outcome) {
  CommandDone<T>() => null,
  CommandRefused<T>(refusal: Refusal(cause: final BillingAccessRefusal r)) =>
    _refusalText(l10n, r.kind),
  _ => l10n.billingAccessFailed,
};
