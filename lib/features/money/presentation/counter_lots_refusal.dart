// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A counter sale refused for the lots of an item, in words: goods past their date say so with what is fit to sell
// and what is past its date; too little says what is there. The refusal is read by its keys in core/trace
// (`lotsRefusalOf`); any other refusal is not this one (null).
import '../../../core/trace/lots_refusal.dart';
import '../../../l10n/app_localizations.dart';

/// What a refusal of a sale for its lots says, or null when [error] is not that refusal.
String? counterLotsRefusalText(AppLocalizations l10n, Object error) =>
    switch (lotsRefusalOf(error)) {
      (
        reason: LotsRefusalReason.expired,
        :final held,
        :final asked,
        :final expired,
      ) =>
        l10n.counterLotsExpired(held, asked, expired),
      (
        reason: LotsRefusalReason.notEnough,
        :final held,
        :final asked,
        expired: _,
      ) =>
        l10n.counterLotsShort(held, asked),
      null => null,
    };
