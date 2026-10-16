// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 - what a host lets a recording keep, decided BEFORE anything is
// persisted. The host supplies the policy; the core only asks it.

import 'action_catalogue.dart';
import 'safe_payload.dart';

/// The host's minimization and exclusion rules at capture time.
abstract interface class CapturePolicy {
  /// The catalogue that names what may be said at all.
  ActionRegistry get registry;

  /// The protected category of [surfaceId], or null when it is ordinary. A
  /// protected surface leaves a marker with this category and nothing else.
  ProtectedSurface? protectedCategory(String surfaceId);

  /// [raw] projected onto what [actionId] declares: undeclared keys dropped,
  /// values outside the vocabulary withheld. Never throws.
  SafePayload minimize(String actionId, Map<String, Object?> raw);
}

/// A policy read straight from the catalogue plus the host's list of
/// protected surfaces.
class CataloguePolicy implements CapturePolicy {
  const CataloguePolicy(
    this.registry, {
    this.protectedSurfaces = const <String, ProtectedSurface>{},
  });

  @override
  final ActionRegistry registry;

  /// Surface id to its protected category.
  final Map<String, ProtectedSurface> protectedSurfaces;

  @override
  ProtectedSurface? protectedCategory(String surfaceId) =>
      protectedSurfaces[surfaceId];

  @override
  SafePayload minimize(String actionId, Map<String, Object?> raw) {
    final spec = registry.action(actionId);
    if (spec == null) return SafePayload.empty;
    return SafePayload.minimize(
      spec.payloadFields,
      raw,
      fields: registry.safeFields,
    );
  }
}
