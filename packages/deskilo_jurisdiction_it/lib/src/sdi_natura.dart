// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 -- SdI's Natura codes: one fixed table of the Italian standard, read
// by the FatturaPA profile, the registro IVA and the stamp duty so the three
// give the same answer. It is Italian-only, so it lives in the Italian add-on;
// the application's registro IVA and stamp duty import it from here, a
// host-to-add-on dependency the removal check reports.

/// Why a 0 % line carries no VAT, in SdI's codes (the FatturaPA and the
/// registro IVA read the same one). Null for a taxed line.
String? fatturaPaNatura(String category, {required String buyerCountry}) => switch (category) {
  'O' => 'N2.2',
  'E' => 'N4',
  'Z' => 'N3.5',
  'K' => 'N3.2',
  'G' => 'N3.1',
  'AE' => buyerCountry.toUpperCase() == 'IT' ? 'N6.9' : 'N2.1',
  _ => null,
};
