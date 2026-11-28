// SPDX-License-Identifier: AGPL-3.0-or-later

// #4511 (STK-09) -- the notes and coins of a currency a till drawer is counted in: one reference, held here and on the
// server (`public.cash_denominations`, migration 0997; test/lint/cash_denominations_parity_test.dart keeps them equal).
// A currency it does not list is counted by its total. Values are minor units of the currency (a 5 \u20ac note is 500,
// a 1 000 yen note 1000); the same value can be a note and a coin (the US dollar).

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

/// THE denominations, by currency, largest first.
const List<CashDenomination> cashDenominations = [
  CashDenomination('AUD', 10000, CashForm.note),
  CashDenomination('AUD', 5000, CashForm.note),
  CashDenomination('AUD', 2000, CashForm.note),
  CashDenomination('AUD', 1000, CashForm.note),
  CashDenomination('AUD', 500, CashForm.note),
  CashDenomination('AUD', 200, CashForm.coin),
  CashDenomination('AUD', 100, CashForm.coin),
  CashDenomination('AUD', 50, CashForm.coin),
  CashDenomination('AUD', 20, CashForm.coin),
  CashDenomination('AUD', 10, CashForm.coin),
  CashDenomination('AUD', 5, CashForm.coin),
  CashDenomination('CAD', 10000, CashForm.note),
  CashDenomination('CAD', 5000, CashForm.note),
  CashDenomination('CAD', 2000, CashForm.note),
  CashDenomination('CAD', 1000, CashForm.note),
  CashDenomination('CAD', 500, CashForm.note),
  CashDenomination('CAD', 200, CashForm.coin),
  CashDenomination('CAD', 100, CashForm.coin),
  CashDenomination('CAD', 25, CashForm.coin),
  CashDenomination('CAD', 10, CashForm.coin),
  CashDenomination('CAD', 5, CashForm.coin),
  CashDenomination('CHF', 100000, CashForm.note),
  CashDenomination('CHF', 20000, CashForm.note),
  CashDenomination('CHF', 10000, CashForm.note),
  CashDenomination('CHF', 5000, CashForm.note),
  CashDenomination('CHF', 2000, CashForm.note),
  CashDenomination('CHF', 1000, CashForm.note),
  CashDenomination('CHF', 500, CashForm.coin),
  CashDenomination('CHF', 200, CashForm.coin),
  CashDenomination('CHF', 100, CashForm.coin),
  CashDenomination('CHF', 50, CashForm.coin),
  CashDenomination('CHF', 20, CashForm.coin),
  CashDenomination('CHF', 10, CashForm.coin),
  CashDenomination('CHF', 5, CashForm.coin),
  CashDenomination('CZK', 500000, CashForm.note),
  CashDenomination('CZK', 200000, CashForm.note),
  CashDenomination('CZK', 100000, CashForm.note),
  CashDenomination('CZK', 50000, CashForm.note),
  CashDenomination('CZK', 20000, CashForm.note),
  CashDenomination('CZK', 10000, CashForm.note),
  CashDenomination('CZK', 5000, CashForm.coin),
  CashDenomination('CZK', 2000, CashForm.coin),
  CashDenomination('CZK', 1000, CashForm.coin),
  CashDenomination('CZK', 500, CashForm.coin),
  CashDenomination('CZK', 200, CashForm.coin),
  CashDenomination('CZK', 100, CashForm.coin),
  CashDenomination('DKK', 100000, CashForm.note),
  CashDenomination('DKK', 50000, CashForm.note),
  CashDenomination('DKK', 20000, CashForm.note),
  CashDenomination('DKK', 10000, CashForm.note),
  CashDenomination('DKK', 5000, CashForm.note),
  CashDenomination('DKK', 2000, CashForm.coin),
  CashDenomination('DKK', 1000, CashForm.coin),
  CashDenomination('DKK', 500, CashForm.coin),
  CashDenomination('DKK', 200, CashForm.coin),
  CashDenomination('DKK', 100, CashForm.coin),
  CashDenomination('DKK', 50, CashForm.coin),
  CashDenomination('EUR', 50000, CashForm.note),
  CashDenomination('EUR', 20000, CashForm.note),
  CashDenomination('EUR', 10000, CashForm.note),
  CashDenomination('EUR', 5000, CashForm.note),
  CashDenomination('EUR', 2000, CashForm.note),
  CashDenomination('EUR', 1000, CashForm.note),
  CashDenomination('EUR', 500, CashForm.note),
  CashDenomination('EUR', 200, CashForm.coin),
  CashDenomination('EUR', 100, CashForm.coin),
  CashDenomination('EUR', 50, CashForm.coin),
  CashDenomination('EUR', 20, CashForm.coin),
  CashDenomination('EUR', 10, CashForm.coin),
  CashDenomination('EUR', 5, CashForm.coin),
  CashDenomination('EUR', 2, CashForm.coin),
  CashDenomination('EUR', 1, CashForm.coin),
  CashDenomination('GBP', 5000, CashForm.note),
  CashDenomination('GBP', 2000, CashForm.note),
  CashDenomination('GBP', 1000, CashForm.note),
  CashDenomination('GBP', 500, CashForm.note),
  CashDenomination('GBP', 200, CashForm.coin),
  CashDenomination('GBP', 100, CashForm.coin),
  CashDenomination('GBP', 50, CashForm.coin),
  CashDenomination('GBP', 20, CashForm.coin),
  CashDenomination('GBP', 10, CashForm.coin),
  CashDenomination('GBP', 5, CashForm.coin),
  CashDenomination('GBP', 2, CashForm.coin),
  CashDenomination('GBP', 1, CashForm.coin),
  CashDenomination('JPY', 10000, CashForm.note),
  CashDenomination('JPY', 5000, CashForm.note),
  CashDenomination('JPY', 2000, CashForm.note),
  CashDenomination('JPY', 1000, CashForm.note),
  CashDenomination('JPY', 500, CashForm.coin),
  CashDenomination('JPY', 100, CashForm.coin),
  CashDenomination('JPY', 50, CashForm.coin),
  CashDenomination('JPY', 10, CashForm.coin),
  CashDenomination('JPY', 5, CashForm.coin),
  CashDenomination('JPY', 1, CashForm.coin),
  CashDenomination('NOK', 100000, CashForm.note),
  CashDenomination('NOK', 50000, CashForm.note),
  CashDenomination('NOK', 20000, CashForm.note),
  CashDenomination('NOK', 10000, CashForm.note),
  CashDenomination('NOK', 5000, CashForm.note),
  CashDenomination('NOK', 2000, CashForm.coin),
  CashDenomination('NOK', 1000, CashForm.coin),
  CashDenomination('NOK', 500, CashForm.coin),
  CashDenomination('NOK', 100, CashForm.coin),
  CashDenomination('PLN', 50000, CashForm.note),
  CashDenomination('PLN', 20000, CashForm.note),
  CashDenomination('PLN', 10000, CashForm.note),
  CashDenomination('PLN', 5000, CashForm.note),
  CashDenomination('PLN', 2000, CashForm.note),
  CashDenomination('PLN', 1000, CashForm.note),
  CashDenomination('PLN', 500, CashForm.coin),
  CashDenomination('PLN', 200, CashForm.coin),
  CashDenomination('PLN', 100, CashForm.coin),
  CashDenomination('PLN', 50, CashForm.coin),
  CashDenomination('PLN', 20, CashForm.coin),
  CashDenomination('PLN', 10, CashForm.coin),
  CashDenomination('PLN', 5, CashForm.coin),
  CashDenomination('PLN', 2, CashForm.coin),
  CashDenomination('PLN', 1, CashForm.coin),
  CashDenomination('SEK', 100000, CashForm.note),
  CashDenomination('SEK', 50000, CashForm.note),
  CashDenomination('SEK', 20000, CashForm.note),
  CashDenomination('SEK', 10000, CashForm.note),
  CashDenomination('SEK', 5000, CashForm.note),
  CashDenomination('SEK', 2000, CashForm.note),
  CashDenomination('SEK', 1000, CashForm.coin),
  CashDenomination('SEK', 500, CashForm.coin),
  CashDenomination('SEK', 200, CashForm.coin),
  CashDenomination('SEK', 100, CashForm.coin),
  CashDenomination('USD', 10000, CashForm.note),
  CashDenomination('USD', 5000, CashForm.note),
  CashDenomination('USD', 2000, CashForm.note),
  CashDenomination('USD', 1000, CashForm.note),
  CashDenomination('USD', 500, CashForm.note),
  CashDenomination('USD', 200, CashForm.note),
  CashDenomination('USD', 100, CashForm.coin),
  CashDenomination('USD', 100, CashForm.note),
  CashDenomination('USD', 50, CashForm.coin),
  CashDenomination('USD', 25, CashForm.coin),
  CashDenomination('USD', 10, CashForm.coin),
  CashDenomination('USD', 5, CashForm.coin),
  CashDenomination('USD', 1, CashForm.coin),
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
