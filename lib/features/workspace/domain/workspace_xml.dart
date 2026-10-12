// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import '../../plan/domain/accessory.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/grid_geometry.dart';
import '../../plan/domain/level.dart';
import '../../plan/domain/seat.dart';
import 'workspace.dart';
import 'workspace_branding.dart';
import 'workspace_xml_configuration.dart';

part 'workspace_xml_part1.dart';
part 'workspace_xml_part2.dart';
part 'workspace_xml_part3.dart';


/// Versioned XML interchange format for a workspace configuration
/// (#164, Epic #162): the owner-editable settings plus the full floor
/// plan. Deliberately excluded: the invite code (a secret) and all
/// member / reservation / ledger data. Ids are NOT part of the format —
/// import (#165) regenerates them; desks belong to offices and seats to
/// desks purely by nesting, and seats reference accessories by NAME.
///
/// Schema v2 (#180 — v1 plus the accessory catalog and per-seat
/// assignments the editor writes since #168):
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <deskilo-workspace version="2">
///   <settings name country currency timezone>
///     <feature key enabled/>
///     <payment-instruction key value/>
///   </settings>
///   <accessories>
///     <accessory name supplement-cents active sort-order/>
///   </accessories>
///   <floor-plan>
///     <level name sort-order>
///       <office name color bookable-as-whole x y w h>
///         <desk name x y w h>
///           <seat name x y orientation chair [blocked-from] [blocked-to]>
///             <amenity name/>
///             <accessory name/>
///           </seat>
///         </desk>
///       </office>
///     </level>
///   </floor-plan>
/// </deskilo-workspace>
/// ```
///
/// The `<accessories>` catalog is complete — inactive entries included, a
/// backup must restore everything. A seat's `<accessory name/>` children
/// reference catalog entries by name (ids regenerate on import); its
/// legacy `<amenity name/>` children keep mirroring `seats.amenities`
/// verbatim. A v1 document simply has no `<accessories>` section and no
/// seat `<accessory>` children — it parses to an empty catalog.
///
/// All timestamps are ISO-8601 UTC. Grid coordinates are absolute cells
/// exactly as stored (ADR 0005); a seat's x/y is its footprint's
/// top-left cell.
///
/// Schema v3 (#916 — the exported space IS the space): v2 plus
/// - a `<configuration>` section carrying every configuration domain
///   the settings block does not (tariffs, legal identity, booking and
///   validation rules, governance, document designs, sites, closure
///   days, document links) as a typed tree — see
///   `workspace_xml_configuration.dart`; absent in a v1/v2 file;
/// - the plan attributes v2 dropped: `price-cents` and
///   `bookable-as-whole` on levels and desks, `price-cents` on offices,
///   `site` (the site's name) on levels, `nfc-uid` on seats, `vat-rate`
///   (the rate's label) on catalogue accessories — every one optional,
///   so a v2 document is a valid v3 document.
/// Secrets never travel: the invite code, the e-invoice and payment
/// provider credentials. Neither does anything transactional.
@visibleForTesting
abstract final class WorkspaceXmlSchema {
  /// The version the app EXPORTS.
  static const int version = 3;

  /// The versions the parser ACCEPTS: v1 (pre-accessories, #164), v2
  /// (#180) and v3 (#916). Anything else was exported by a newer app →
  /// unsupported.
  static const Set<int> supportedVersions = {1, 2, 3};

  static const String rootElement = 'deskilo-workspace';
  static const String versionAttr = 'version';

  static const String settingsElement = 'settings';
  static const String nameAttr = 'name';
  static const String countryAttr = 'country';
  static const String currencyAttr = 'currency';
  static const String timezoneAttr = 'timezone';

  /// #1289 — the brand seed on `<settings>`, `#RRGGBB`; optional.
  static const String brandColorAttr = 'brand-color';

  static const String featureElement = 'feature';
  static const String keyAttr = 'key';
  static const String enabledAttr = 'enabled';
  static const String paymentInstructionElement = 'payment-instruction';
  static const String valueAttr = 'value';

  static const String floorPlanElement = 'floor-plan';
  static const String levelElement = 'level';
  static const String sortOrderAttr = 'sort-order';
  static const String officeElement = 'office';
  static const String colorAttr = 'color';
  static const String bookableAsWholeAttr = 'bookable-as-whole';
  static const String deskElement = 'desk';
  static const String seatElement = 'seat';
  static const String xAttr = 'x';
  static const String yAttr = 'y';
  static const String wAttr = 'w';
  static const String hAttr = 'h';
  static const String orientationAttr = 'orientation';
  static const String chairAttr = 'chair';
  static const String blockedFromAttr = 'blocked-from';
  static const String blockedToAttr = 'blocked-to';
  static const String amenityElement = 'amenity';

  // v2 (#180): accessory catalog + per-seat references by name.
  static const String accessoriesElement = 'accessories';
  static const String accessoryElement = 'accessory';
  static const String supplementCentsAttr = 'supplement-cents';
  static const String activeAttr = 'active';

  // v3 (#916): plan attributes and the configuration section.
  static const String priceCentsAttr = 'price-cents';
  static const String siteAttr = 'site';
  static const String nfcUidAttr = 'nfc-uid';
  static const String vatRateAttr = 'vat-rate';
  static const String configurationElement =
      WorkspaceXmlConfigurationSchema.element;
}
