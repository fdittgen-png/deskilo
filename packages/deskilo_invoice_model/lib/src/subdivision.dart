// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- the one mapping from a stored region to what an e-invoice writes.
// An address stores its region as the part of the ISO 3166-2 code after the
// country (`MI`, `B`); an earlier entry may hold the whole code (`RO-B`). A
// format that wants the part reads [subdivisionPart], one that wants the
// whole code reads [subdivisionIso].

/// The region's code after the country: `RO-B`, `ro-b` and `B` in `RO` are
/// `B`; '' when there is none.
String subdivisionPart(String country, String stored) {
  final code = stored.trim().toUpperCase();
  final prefix = '${country.trim().toUpperCase()}-';
  return code.startsWith(prefix) ? code.substring(prefix.length) : code;
}

/// The whole ISO 3166-2 code (`RO-B`), or '' when the address has no region.
String subdivisionIso(String country, String stored) {
  final part = subdivisionPart(country, stored);
  return part.isEmpty ? '' : '${country.trim().toUpperCase()}-$part';
}
