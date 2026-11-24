// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2354 — what a supply IS for the place-of-supply rules: stored on a
/// catalogue service (`services.supply_class`) and frozen on the charge
/// (`ledger_entries.supply_class`), then on every invoice line
/// (`supply`). Desks, offices, rooms, levels, packages and seat
/// accessories are property-connected by nature and carry no choice.
enum SupplyClass {
  /// A service connected with immovable property (Directive 2006/112/EC
  /// art. 47): taxed where the building stands, for every customer. The
  /// default for everything a coworking space sells.
  property('property'),

  /// A general service (art. 44/45) not tied to the premises — mail
  /// handling, a virtual office, an online-only service: a business
  /// customer elsewhere self-assesses the tax.
  general('general'),

  /// #4441 — a class a newer server knows and this app does not. Never
  /// sent: no place-of-supply rule is picked for it ([supplyVatCategory]
  /// refuses), a service keeps the class the server has, and nothing new is
  /// created with it.
  unknown('');

  const SupplyClass(this.wire);

  final String wire;

  /// The class [wire] names. A row from before the column (0403) has none
  /// and is property, the column's default; any other value is [unknown],
  /// never a class it is not.
  static SupplyClass fromWire(String? wire) => switch (wire) {
    null => property,
    'property' => property,
    'general' => general,
    _ => unknown,
  };
}

/// #4441 — a place-of-supply rule was asked for a supply class this app
/// does not know: no rule is picked.
final class UnknownSupplyClass implements Exception {
  const UnknownSupplyClass();

  @override
  String toString() => 'UnknownSupplyClass';
}
