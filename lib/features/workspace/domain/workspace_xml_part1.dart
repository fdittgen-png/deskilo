// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_xml.dart';


/// Why a document was rejected. #165 maps each value to a localized
/// message; [WorkspaceXmlException.detail] carries the technical detail
/// (element/attribute path, offending value) for logs.
enum WorkspaceXmlError {
  /// Not well-formed XML at all.
  malformed,

  /// Well-formed XML but the root element is not `deskilo-workspace`.
  wrongRoot,

  /// A `version` we do not understand (newer app exported it).
  unsupportedVersion,

  /// A required element is missing.
  missingElement,

  /// A required attribute is missing.
  missingAttribute,

  /// An attribute value failed validation (bad int, unknown
  /// orientation, bad bool, bad timestamp, negative geometry, ...).
  invalidValue,
}

/// Typed parse failure (#164): [error] selects the user-facing message,
/// [detail] is for logging only — never shown to users.
class WorkspaceXmlException implements Exception {
  const WorkspaceXmlException(this.error, this.detail);

  final WorkspaceXmlError error;
  final String detail;

  @override
  String toString() => 'WorkspaceXmlException(${error.name}): $detail';
}

// ---------------------------------------------------------------------------
// Parsed structure (no ids — import regenerates them)
// ---------------------------------------------------------------------------

/// The `<settings>` block: everything the owner configures outside the
/// floor plan. No invite code — it is a secret and never exported.
class WorkspaceXmlSettings {
  const WorkspaceXmlSettings({
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
    this.featureFlags = const {},
    this.paymentInstructions = const {},
    this.brandColor,
  });

  final String name;
  final String countryCode;
  final String currencyCode;
  final String timezone;

  /// #1289 — the brand seed as `#RRGGBB`, null when the document carries
  /// none. The import writes it through `set_workspace_branding`, which
  /// validates the shape; the contrast rule is the app's, at import too.
  final String? brandColor;

  /// Explicit per-workspace feature overrides (#146). Absent key =
  /// registry default, exactly like [Workspace.featureFlags].
  final Map<String, bool> featureFlags;

  /// Owner payment instructions (#155) as opaque key/value pairs
  /// (`iban`, `paypal_me`, `reference`, ...). Empty values are dropped.
  final Map<String, String> paymentInstructions;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlSettings &&
      other.name == name &&
      other.countryCode == countryCode &&
      other.currencyCode == currencyCode &&
      other.timezone == timezone &&
      other.brandColor == brandColor &&
      _mapEquals(other.featureFlags, featureFlags) &&
      _mapEquals(other.paymentInstructions, paymentInstructions);

  @override
  int get hashCode => Object.hash(name, countryCode, currencyCode, timezone,
      _mapHash(featureFlags), _mapHash(paymentInstructions));
}

/// An `<accessory>` catalog entry (v2, #180). Referenced from seats by
/// [name]; ids regenerate on import like everything else in the format.
class WorkspaceXmlAccessory {
  const WorkspaceXmlAccessory({
    required this.name,
    this.supplementCents = 0,
    this.active = true,
    this.sortOrder = 0,
    this.vatRate = '',
  });

  final String name;
  final int supplementCents;
  final bool active;
  final int sortOrder;

  /// The VAT rate's LABEL (v3, #916) — empty when the accessory carries
  /// none or the file predates v3.
  final String vatRate;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlAccessory &&
      other.name == name &&
      other.supplementCents == supplementCents &&
      other.active == active &&
      other.sortOrder == sortOrder &&
      other.vatRate == vatRate;

  @override
  int get hashCode =>
      Object.hash(name, supplementCents, active, sortOrder, vatRate);
}

/// A `<seat>`: THE bookable unit. x/y is the footprint's top-left cell.
class WorkspaceXmlSeat {
  const WorkspaceXmlSeat({
    required this.name,
    required this.x,
    required this.y,
    required this.orientation,
    this.chair = '',
    this.amenities = const [],
    this.accessoryNames = const [],
    this.blockedFrom,
    this.blockedTo,
    this.nfcUid = '',
  });

  final String name;
  final int x;
  final int y;
  final SeatOrientation orientation;
  final String chair;
  final List<String> amenities;

  /// Catalog references by name (v2, #180) — always empty in a v1 file.
  final List<String> accessoryNames;
  final DateTime? blockedFrom;
  final DateTime? blockedTo;

  /// The seat's NFC tag identifier (v3, #916), empty when untagged.
  final String nfcUid;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlSeat &&
      other.name == name &&
      other.x == x &&
      other.y == y &&
      other.orientation == orientation &&
      other.chair == chair &&
      _listEquals(other.amenities, amenities) &&
      _listEquals(other.accessoryNames, accessoryNames) &&
      other.blockedFrom == blockedFrom &&
      other.blockedTo == blockedTo &&
      other.nfcUid == nfcUid;

  @override
  int get hashCode => Object.hash(name, x, y, orientation, chair,
      Object.hashAll(amenities), Object.hashAll(accessoryNames), blockedFrom,
      blockedTo, nfcUid);
}

/// A `<desk>` with its seats nested inside.
class WorkspaceXmlDesk {
  const WorkspaceXmlDesk({
    required this.name,
    required this.rect,
    this.seats = const [],
    this.priceCents = 0,
    this.bookableAsWhole = false,
  });

  final String name;
  final GridRect rect;
  final List<WorkspaceXmlSeat> seats;

  /// v3 (#916): the desk's own price and whether it books as a whole.
  final int priceCents;
  final bool bookableAsWhole;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlDesk &&
      other.name == name &&
      other.rect == rect &&
      _listEquals(other.seats, seats) &&
      other.priceCents == priceCents &&
      other.bookableAsWhole == bookableAsWhole;

  @override
  int get hashCode => Object.hash(
      name, rect, Object.hashAll(seats), priceCents, bookableAsWhole);
}

/// An `<office>` with its desks nested inside.
class WorkspaceXmlOffice {
  const WorkspaceXmlOffice({
    required this.name,
    required this.color,
    required this.bookableAsWhole,
    required this.rect,
    this.desks = const [],
    this.priceCents = 0,
  });

  final String name;
  final int color;
  final bool bookableAsWhole;
  final GridRect rect;
  final List<WorkspaceXmlDesk> desks;

  /// v3 (#916): the office's own price.
  final int priceCents;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlOffice &&
      other.name == name &&
      other.color == color &&
      other.bookableAsWhole == bookableAsWhole &&
      other.rect == rect &&
      _listEquals(other.desks, desks) &&
      other.priceCents == priceCents;

  @override
  int get hashCode => Object.hash(name, color, bookableAsWhole, rect,
      Object.hashAll(desks), priceCents);
}

/// A `<level>` (floor) with its offices nested inside.
class WorkspaceXmlLevel {
  const WorkspaceXmlLevel({
    required this.name,
    required this.sortOrder,
    this.offices = const [],
    this.priceCents = 0,
    this.bookableAsWhole = false,
    this.site = '',
  });

  final String name;
  final int sortOrder;
  final List<WorkspaceXmlOffice> offices;

  /// v3 (#916): the level's price, whether it books as a whole, and the
  /// NAME of the site it belongs to ('' = the workspace's default).
  final int priceCents;
  final bool bookableAsWhole;
  final String site;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlLevel &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      _listEquals(other.offices, offices) &&
      other.priceCents == priceCents &&
      other.bookableAsWhole == bookableAsWhole &&
      other.site == site;

  @override
  int get hashCode => Object.hash(name, sortOrder, Object.hashAll(offices),
      priceCents, bookableAsWhole, site);
}

/// The whole parsed document: settings + accessory catalog + floor-plan
/// structure, no ids. [accessories] is empty for a v1 file (#180).
class WorkspaceXmlData {
  const WorkspaceXmlData({
    required this.settings,
    this.accessories = const [],
    this.levels = const [],
    this.configuration,
  });

  final WorkspaceXmlSettings settings;
  final List<WorkspaceXmlAccessory> accessories;
  final List<WorkspaceXmlLevel> levels;

  /// The v3 `<configuration>` tree (#916); null for a v1/v2 document or
  /// a v3 document without one. Compared structurally.
  final Map<String, Object?>? configuration;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceXmlData &&
      other.settings == settings &&
      _listEquals(other.accessories, accessories) &&
      _listEquals(other.levels, levels) &&
      _deepEquals(other.configuration, configuration);

  @override
  int get hashCode => Object.hash(settings, Object.hashAll(accessories),
      Object.hashAll(levels), configuration == null ? 0 : 1);
}
