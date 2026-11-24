// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A counter sale refused for the lots of an item (DKG03, `"scope": "lots"`, 0947): the server says by key why --
// `"reason": "expired"` when goods past their date make up what is missing, `"not_enough"` otherwise -- with what is
// fit to sell (`held`), what was asked and what is past its date, all in the item's inventory unit. The words are read
// from those keys, never from the server's sentence; any other refusal is not this one (null).
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/data/server_error.dart';
import '../../../l10n/app_localizations.dart';

/// What a refusal of a sale for its lots says, or null when [error] is not that refusal.
String? counterLotsRefusalText(AppLocalizations l10n, Object error) {
  if (serverErrorCode(error) != DkCode.dkg03) return null;
  final raw = serverErrorDetails(error);
  if (raw == null) return null;
  try {
    final r = JsonReader.of(jsonDecode(raw), context: DkCode.dkg03);
    if (r.stringOrNull('scope') != 'lots') return null;
    final held = r.stringOrNull('held');
    final asked = r.stringOrNull('asked');
    if (held == null || asked == null) return null;
    return switch (r.stringOrNull('reason')) {
      'expired' => l10n.counterLotsExpired(held, asked, r.stringOr('expired')),
      'not_enough' => l10n.counterLotsShort(held, asked),
      _ => null,
    };
  } on Object {
    // a detail that is not our JSON is no hint: the generic words stand
    return null;
  }
}
