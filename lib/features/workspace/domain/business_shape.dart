// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4407 -- what a business is, read once: whether it has places to book, whether it sells services and whether it is a shop.
// Every screen that words or lays itself out differently for a business without places, for a shop or for a freelancer reads
// this one value (`businessShapeProvider`), never a feature, a kind or a stored flag of its own. Pure Dart.
import 'workspace_feature.dart';

/// The shape of the selected business.
///
/// Its three sources, and which wins where:
///  * **places** -- the effective `placeBooking` feature (what the business has switched on, by hand or by its kind's
///    proposal) AND the primary kind not keeping places off. Either one off means no places: a coworking space that switches
///    places off by hand reads as a business without places on every step, as does a practice whose stored flag is still on.
///    The one deliberate exception is the setup levels screen, which reads the STORED flag (`stored.contains(placeBooking)`,
///    #3702): one off place feature is not "no places", and a level the person has not reached yet must not read as an answer.
///  * **services** -- the effective `services` feature.
///  * **shop** -- the business's kinds (the primary one or a further one) include `shop`.
class BusinessShape {
  const BusinessShape({required this.places, required this.services, required this.shop, this.kindKeepsPlacesOff = false});

  /// Reads the shape from its three sources: the effective [features], whether the primary kind keeps places off
  /// ([kindKeepsPlacesOff]) and the business's kind codes ([kinds], the primary one first).
  factory BusinessShape.of({
    required Set<WorkspaceFeature> features,
    required bool kindKeepsPlacesOff,
    required List<String> kinds,
  }) => BusinessShape(
    places: features.contains(WorkspaceFeature.placeBooking) && !kindKeepsPlacesOff,
    services: features.contains(WorkspaceFeature.services),
    shop: kinds.contains('shop'),
    kindKeepsPlacesOff: kindKeepsPlacesOff,
  );

  /// Has places members or customers book.
  final bool places;

  /// Sells services.
  final bool services;

  /// Is a shop (alone or beside another kind).
  final bool shop;

  /// The primary kind alone keeps places off, whatever the business switched on: the setup status hides the place steps of such
  /// a business (#4223), never of one that switched places off by hand and may still want them.
  final bool kindKeepsPlacesOff;
}
