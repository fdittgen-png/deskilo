// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3547 — a feature the business's own kind keeps off is not unfinished
// setup. A kind without places (a practice, a salon) proposes
// `placeBooking: false`, and the place features it stored stay stored
// beneath that off parent (feature resolution preserves them); each of them
// is "switched on, waiting for" the parent. For such a business that waiting
// is the choice it made, not work left to do. Pure Dart.
import 'business_kind.dart';
import 'business_profile.dart';
import 'workspace_feature.dart';

/// Whether the business's primary kind keeps [feature] off: its profile
/// proposes it off. The primary kind decides, as it does when the kind is
/// chosen (the kind sheet proposes from it alone); a further kind and a kind
/// that says nothing about [feature] change nothing, so a coworking space
/// that also runs a practice keeps its places.
///
/// [kinds] is the registry (`public.business_kinds`); a business whose kind
/// the registry does not list keeps nothing off.
bool switchedOffByKind(
  WorkspaceFeature feature,
  BusinessProfile profile,
  List<BusinessKind> kinds,
) => kinds.any(
  (kind) => kind.code == profile.kind && kind.keepsOff(feature),
);
