// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 — a space the "chosen spaces" audience can name, as the personal
// home lists it. The privacy editor knows this value and nothing of the
// workspace layer, so the list can later come from the qualified
// references (#2563) without the editor changing.

/// One space a field's audience can be limited to.
class AudienceSpace {
  const AudienceSpace({required this.id, required this.name});

  /// What the saved audience stores for this space.
  final String id;

  /// What the person reads.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AudienceSpace && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// The ids of [chosen] that [listed] no longer names, in a stable order.
/// A saved choice is never dropped because the list does not show it: the
/// person sees it and decides.
List<String> unlistedChoices(Set<String> chosen, List<AudienceSpace> listed) {
  final known = {for (final space in listed) space.id};
  return [
    for (final id in chosen)
      if (!known.contains(id)) id,
  ]..sort();
}
