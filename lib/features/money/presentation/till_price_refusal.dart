// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4476 -- a till line's price refused, in words: another price without the right to change a price at the till
// (DKN01 "price"), without its reason (DKL02 "price_reason"), a discount beyond the business's limit (DKN01
// "discount_limit", with the limit), or a discount that is not a percentage or sits beside a price (DKL02). Read by its
// keys, never by the server's sentence; any other refusal is not this one (null).
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/data/server_error.dart';
import '../../../l10n/app_localizations.dart';

/// What a refusal of a till line's price says, or null when [error] is not that refusal.
String? tillPriceRefusalText(AppLocalizations l10n, Object error) {
  final code = serverErrorCode(error);
  if (code == null || (code != DkCode.dkn01 && code != DkCode.dkl02)) return null;
  final raw = serverErrorDetails(error);
  if (raw == null) return null;
  try {
    final r = JsonReader.of(jsonDecode(raw), context: code);
    return switch ((code, r.stringOrNull('reason'))) {
      (DkCode.dkn01, 'price') => l10n.tillPriceNotAllowed,
      (DkCode.dkl02, 'price_reason') => l10n.tillPriceReasonMissing,
      (DkCode.dkn01, 'discount_limit') => l10n.tillDiscountBeyond('${r.intOrNull('max') ?? 0}'),
      (DkCode.dkl02, 'discount' || 'price_and_discount') => l10n.tillDiscountInvalid,
      _ => null,
    };
  } on Object {
    // a detail that is not our JSON is no hint: the generic words stand
    return null;
  }
}
