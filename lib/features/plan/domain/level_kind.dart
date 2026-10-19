// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2568 — whose floor it is (`levels.kind`, 0496): the space's own, or one
/// the space rents rooms in. An external level books room by room, inside the
/// rental's window, for the rental's audience.
enum LevelKind {
  own('own'),
  external('external');

  const LevelKind(this.wire);

  final String wire;

  static LevelKind of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => own);
}
