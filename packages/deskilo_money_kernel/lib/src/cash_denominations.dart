// SPDX-License-Identifier: AGPL-3.0-or-later

// #4511 (STK-09) -- the notes and coins of a currency a till drawer is counted in: one reference, held here and on the
// server (`public.cash_denominations`, migration 0997; test/lint/cash_denominations_parity_test.dart keeps them equal).
// A currency it does not list is counted by its total. Values are minor units of the currency (a 5 \u20ac note is 500,
// a 1 000 yen note 1000); the same value can be a note and a coin (the US dollar).

import 'package:meta/meta.dart';

import 'currencies.dart';

/// Whether a denomination is a note or a coin.
enum CashForm { note, coin }

/// One note or coin of [currency]: its value in minor units and its form; [withdrawnOn] the day it stopped being
/// issued and accepted, for one its country replaced.
final class CashDenomination {
  const CashDenomination(this.currency, this.valueMinor, this.form, {this.withdrawnOn});

  final String currency;
  final int valueMinor;
  final CashForm form;
  final String? withdrawnOn;
}

/// THE denominations, by currency, largest first: the coins and notes of each currency of the reference
/// ([currencyReference]), a coin before a note of the same value.
@visibleForTesting
final List<CashDenomination> cashDenominations = [
  for (final c in currencyReference)
    for (final (value, form) in [
      ...[for (final v in c.coins) (v, CashForm.coin)],
      ...[for (final v in c.notes) (v, CashForm.note)],
    ]..sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : b.$2.index.compareTo(a.$2.index)))
      CashDenomination(c.code, value, form),
];

/// The values a drawer in [currency] is counted in, largest first (a value that is a note and a coin once); empty for a
/// currency counted by its total.
List<int> cashValuesOf(String currency) {
  final code = currency.trim().toUpperCase();
  if (!Currencies.isKnown(code)) return const [];
  final out = <int>[];
  for (final d in cashDenominations) {
    if (d.currency == code && d.withdrawnOn == null && !out.contains(d.valueMinor)) out.add(d.valueMinor);
  }
  return out;
}

/// #4511 -- the notes of [currency], smallest first; empty for a currency the reference does not list.
List<int> cashNotesOf(String currency) {
  final code = currency.trim().toUpperCase();
  return [
    for (final d in cashDenominations.reversed)
      if (d.currency == code && d.form == CashForm.note && d.withdrawnOn == null) d.valueMinor,
  ];
}

/// The values a till counts in: its own pick ([picked], null for none) among the currency's, in the currency's order;
/// a pick that names no current value of the currency is the currency's whole list.
List<int> tillCashValues(String currency, List<int>? picked) {
  final all = cashValuesOf(currency);
  if (picked == null) return all;
  final kept = [
    for (final v in all)
      if (picked.contains(v)) v,
  ];
  return kept.isEmpty ? all : kept;
}
