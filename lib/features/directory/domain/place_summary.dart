// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step C -- what a place card says of where a space is: the town of its
// published address, never the host it is served from.

/// The town of [address] (`street, 34120 Pézenas` -> `Pézenas`): the last
/// comma-separated part without its leading postal code; empty when the
/// address names none.
String cityOfAddress(String address) {
  final parts = address
      .split(RegExp(r'[,\n]'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final last = parts.last.replaceFirst(RegExp(r'^\d{4,5}\s+'), '').trim();
  // A single part is a street, not a town, unless it opens with a postal code.
  if (parts.length == 1 && last == parts.last) return '';
  return last;
}
