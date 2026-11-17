// SPDX-License-Identifier: AGPL-3.0-or-later

/// The one currency the euro-denominated filing formats (the French FEC
/// and the DATEV Buchungsstapel) are written in. A workspace booking in
/// another currency is refused by those exporters with its currency
/// named (#3184); no exporter assumes this currency for it.
const _euroFormatCurrency = 'EUR';

/// Whether [currency] is the one the euro-denominated formats are
/// written in.
bool isEuroFormatCurrency(String currency) =>
    currency.toUpperCase() == _euroFormatCurrency;
