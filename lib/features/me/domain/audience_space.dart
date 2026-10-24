// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 — a space the "chosen spaces" audience can name, as the personal
// home lists it. The privacy editor knows this value and nothing of the
// workspace layer: the list comes from the qualified references of the
// personal home (#2563, `my_personal_workspace_refs_v1`), so a space is
// identified by its network reference, never by a local id.
import 'personal_workspace_refs.dart';

/// One space a field's audience can be limited to.
class AudienceSpace {
  const AudienceSpace({
    required this.id,
    this.name,
    this.installationId = '',
    this.hostedHere = true,
    this.verified = true,
    this.selectable = true,
  });

  /// [ref] as the editor offers it. Only a space of this home whose
  /// membership the home itself reads as active or paused can be chosen
  /// (`set_visibility` refuses any other); a space on another installation
  /// is shown, unverified, and never chosen here.
  factory AudienceSpace.fromRef(PersonalWorkspaceRef ref) {
    final verified = ref.freshness == RefFreshness.local;
    return AudienceSpace(
      id: ref.networkId,
      name: ref.label,
      installationId: ref.installationId,
      hostedHere: ref.hostedHere,
      verified: verified,
      selectable: ref.hostedHere &&
          verified &&
          (ref.status == RefStatus.active || ref.status == RefStatus.paused),
    );
  }

  /// The network reference the saved audience stores for this space.
  final String id;

  /// What the person reads; null where the home may not name it.
  final String? name;

  /// The installation that hosts the space.
  final String installationId;

  /// The space lives on the personal home that answered.
  final bool hostedHere;

  /// The home holds the relationship itself; false means "verification
  /// unavailable" (a space on another installation, #2563 C2).
  final bool verified;

  /// Whether the person may add it to a chosen audience here.
  final bool selectable;

  @override
  bool operator ==(Object other) =>
      other is AudienceSpace &&
      other.id == id &&
      other.name == name &&
      other.installationId == installationId &&
      other.hostedHere == hostedHere &&
      other.verified == verified &&
      other.selectable == selectable;

  @override
  int get hashCode =>
      Object.hash(id, name, installationId, hostedHere, verified, selectable);
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

/// The ids of [listed] whose name another listed space also carries: a
/// name alone does not tell them apart, so the editor says where each is.
Set<String> ambiguousNames(List<AudienceSpace> listed) {
  final counts = <String, int>{};
  for (final space in listed) {
    final name = space.name?.trim().toLowerCase();
    if (name == null || name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return {
    for (final space in listed)
      if ((counts[space.name?.trim().toLowerCase()] ?? 0) > 1) space.id,
  };
}
