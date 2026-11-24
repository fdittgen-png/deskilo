// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 -- a counter sale refused for the lots of an item (DKG03, `"scope": "lots"`, 0947), read from its keys: why
// (`"expired"` when goods past their date make up what is missing, `"not_enough"` otherwise), what is fit to sell
// (`held`), what was asked and what is past its date, in the item's inventory unit. Never the server's sentence.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../codes/dk_code.dart';
import '../data/server_error.dart';

/// Why a sale was refused for its lots.
enum LotsRefusalReason { expired, notEnough }

/// The refusal [error] carries, or null when it is not a refusal of a sale for its lots.
({LotsRefusalReason reason, String held, String asked, String expired})?
lotsRefusalOf(Object error) {
  if (serverErrorCode(error) != DkCode.dkg03) return null;
  final raw = serverErrorDetails(error);
  if (raw == null) return null;
  try {
    final r = JsonReader.of(jsonDecode(raw), context: DkCode.dkg03);
    if (r.stringOrNull('scope') != 'lots') return null;
    final held = r.stringOrNull('held');
    final asked = r.stringOrNull('asked');
    final reason = switch (r.stringOrNull('reason')) {
      'expired' => LotsRefusalReason.expired,
      'not_enough' => LotsRefusalReason.notEnough,
      _ => null,
    };
    if (held == null || asked == null || reason == null) return null;
    return (
      reason: reason,
      held: held,
      asked: asked,
      expired: r.stringOr('expired'),
    );
  } on Object {
    // a detail that is not our JSON is no hint: the generic words stand
    return null;
  }
}
