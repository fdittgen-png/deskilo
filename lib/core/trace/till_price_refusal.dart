// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4476 -- a till line's price refused (0964), read from its keys: another price without the right (DKN01 "price"),
// without its reason (DKL02 "price_reason"), a discount beyond the business's limit (DKN01 "discount_limit", with the
// limit) or one that is not a percentage or sits beside a price (DKL02 "discount", "price_and_discount"). Never the
// server's sentence.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../codes/dk_code.dart';
import '../data/server_error.dart';

/// Why a till line's price was refused.
enum TillPriceRefusal { notAllowed, reasonMissing, discountBeyond, discountInvalid }

/// The refusal [error] carries, with the business's discount limit for [TillPriceRefusal.discountBeyond]; null when it
/// is not a refusal of a till line's price.
({TillPriceRefusal reason, int max})? tillPriceRefusalOf(Object error) {
  final code = serverErrorCode(error);
  if (code != DkCode.dkn01 && code != DkCode.dkl02) return null;
  final raw = serverErrorDetails(error);
  if (raw == null) return null;
  try {
    final r = JsonReader.of(jsonDecode(raw), context: code ?? '');
    final reason = switch ((code, r.stringOrNull('reason'))) {
      (DkCode.dkn01, 'price') => TillPriceRefusal.notAllowed,
      (DkCode.dkl02, 'price_reason') => TillPriceRefusal.reasonMissing,
      (DkCode.dkn01, 'discount_limit') => TillPriceRefusal.discountBeyond,
      (DkCode.dkl02, 'discount' || 'price_and_discount') => TillPriceRefusal.discountInvalid,
      _ => null,
    };
    return reason == null ? null : (reason: reason, max: r.intOrNull('max') ?? 0);
  } on Object {
    // a detail that is not our JSON is no hint: the generic words stand
    return null;
  }
}
