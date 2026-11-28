// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4495 -- a setting that names a PLACE of the business holds its id, picked in the app as site › place; a code (every installation before
// this) is read only while exactly one place carries it. What the setting says is never guessed: a code two places carry is named, and so
// is a pick that is no longer usable.

/// The setting that names the place goods sold on an invoice leave from.
const settingKeyInvoiceSalePlace = 'stock.invoice_sale_place';

/// A place a setting may name: a place of the business that is in use and holds stock.
class SettingPlace {
  const SettingPlace({required this.id, required this.code, required this.path});

  final String id;
  final String code;

  /// The full path as a person reads it: `Site B › Shop`.
  final String path;
}

enum PlaceSettingState {
  /// The id of a place that is still usable.
  picked,

  /// A code that exactly one place carries (the setting still holds the code).
  fromCode,

  /// A code that several places carry: none is chosen until one is picked.
  ambiguous,

  /// A code no place carries, or a pick that is no longer usable.
  missing,
}

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// What the setting's [value] names among [places]: an id, or a code (empty is the code `MAIN`, the default of before).
({PlaceSettingState state, SettingPlace? place, String code}) placeOfSetting(String value, List<SettingPlace> places) {
  final v = value.trim();
  if (_uuid.hasMatch(v)) {
    final place = places.where((p) => p.id.toLowerCase() == v.toLowerCase()).firstOrNull;
    return (state: place == null ? PlaceSettingState.missing : PlaceSettingState.picked, place: place, code: '');
  }
  final code = v.isEmpty ? 'MAIN' : v;
  final matches = places.where((p) => p.code == code).toList();
  return switch (matches.length) {
    1 => (state: PlaceSettingState.fromCode, place: matches.single, code: code),
    0 => (state: PlaceSettingState.missing, place: null, code: code),
    _ => (state: PlaceSettingState.ambiguous, place: null, code: code),
  };
}
