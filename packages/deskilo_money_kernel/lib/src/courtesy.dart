// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- how a person asks to be addressed on a document: a code each
// reader prints in its own language. It lived beside the personal-information
// model; the report strings of the invoice read it, so it sits with the
// vocabulary the accounting model stands on.

/// #912 — how a person asks to be addressed on a document.
///
/// Their own choice, never inferred: a name says nothing reliable about
/// how its bearer wants to be greeted, and getting it wrong on a letter
/// is worse than not greeting at all. [none] is a real answer, and the
/// default — the name is then printed on its own.
enum Courtesy {
  none(''),
  mr('mr'),
  mrs('mrs');

  const Courtesy(this.wire);

  /// What is stored, on `profiles.courtesy` and inside a managed
  /// identity — a code, so each reader prints it in its own language.
  final String wire;

  static Courtesy fromWire(String? wire) =>
      values.where((c) => c.wire == wire).firstOrNull ?? none;
}
