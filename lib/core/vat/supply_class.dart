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
  general('general');

  const SupplyClass(this.wire);

  final String wire;

  static SupplyClass fromWire(String? wire) =>
      wire == general.wire ? general : property;
}
