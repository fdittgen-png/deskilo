// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4476 -- a till line's price refused, in words: the refusal is read by its keys in core/trace (`tillPriceRefusalOf`);
// any other refusal is not this one (null).
import '../../../core/trace/till_price_refusal.dart';
import '../../../l10n/app_localizations.dart';

/// What a refusal of a till line's price says, or null when [error] is not that refusal.
String? tillPriceRefusalText(AppLocalizations l10n, Object error) => switch (tillPriceRefusalOf(error)) {
  (reason: TillPriceRefusal.notAllowed, max: _) => l10n.tillPriceNotAllowed,
  (reason: TillPriceRefusal.reasonMissing, max: _) => l10n.tillPriceReasonMissing,
  (reason: TillPriceRefusal.discountBeyond, max: _) => l10n.tillDiscountBeyond,
  (reason: TillPriceRefusal.discountInvalid, max: _) => l10n.tillDiscountInvalid,
  (reason: TillPriceRefusal.returnNotAllowed, max: _) => l10n.tillReturnNotAllowed,
  (reason: TillPriceRefusal.returnOffline, max: _) => l10n.tillReturnOffline,
  (reason: TillPriceRefusal.returnTracked, max: _) => l10n.tillReturnTracked,
  (reason: TillPriceRefusal.returnNotDeposit, max: _) => l10n.tillReturnNotDeposit,
  null => null,
};
