// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../plan/domain/grid_geometry.dart';
import '../../plan/domain/seat.dart';

part 'workspace_xml_model.freezed.dart';

/// Why a document was rejected. The import screen maps each value to a
/// localized message; [WorkspaceXmlException.detail] carries the technical
/// detail (element/attribute path, offending value) for logs.
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

/// Typed parse failure: [error] selects the user-facing message, [detail]
/// is for logging only — never shown to users.
class WorkspaceXmlException implements Exception {
  const WorkspaceXmlException(this.error, this.detail);

  final WorkspaceXmlError error;
  final String detail;

  @override
  String toString() => 'WorkspaceXmlException(${error.name}): $detail';
}

// ---------------------------------------------------------------------------
// Parsed structure (no ids — import regenerates them). Value equality is
// structural, collections included.
// ---------------------------------------------------------------------------

/// The `<settings>` block: everything the owner configures outside the
/// floor plan. No invite code — it is a secret and never exported.
@freezed
sealed class WorkspaceXmlSettings with _$WorkspaceXmlSettings {
  const factory WorkspaceXmlSettings({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,

    /// Explicit per-workspace feature overrides. Absent key = registry
    /// default, exactly like `Workspace.featureFlags`.
    @Default(<String, bool>{}) Map<String, bool> featureFlags,

    /// Owner payment instructions as opaque key/value pairs (`iban`,
    /// `paypal_me`, `reference`, ...). Empty values are dropped.
    @Default(<String, String>{}) Map<String, String> paymentInstructions,

    /// The brand seed as `#RRGGBB`, null when the document carries none.
    /// The import writes it through `set_workspace_branding`, which
    /// validates the shape; the contrast rule is the app's, at import too.
    String? brandColor,
  }) = _WorkspaceXmlSettings;
}

/// An `<accessory>` catalog entry (v2). Referenced from seats by [name];
/// ids regenerate on import like everything else in the format.
@freezed
sealed class WorkspaceXmlAccessory with _$WorkspaceXmlAccessory {
  const factory WorkspaceXmlAccessory({
    required String name,
    @Default(0) int supplementCents,
    @Default(true) bool active,
    @Default(0) int sortOrder,

    /// The VAT rate's LABEL (v3) — empty when the accessory carries none
    /// or the file predates v3.
    @Default('') String vatRate,
  }) = _WorkspaceXmlAccessory;
}

/// A `<seat>`: THE bookable unit. x/y is the footprint's top-left cell.
@freezed
sealed class WorkspaceXmlSeat with _$WorkspaceXmlSeat {
  const WorkspaceXmlSeat._();

  const factory WorkspaceXmlSeat({
    required String name,
    required int x,
    required int y,
    required SeatOrientation orientation,
    @Default('') String chair,
    @Default(<String>[]) List<String> amenities,

    /// Catalog references by name (v2) — always empty in a v1 file.
    @Default(<String>[]) List<String> accessoryNames,
    DateTime? blockedFrom,
    DateTime? blockedTo,

    /// The seat's NFC tag identifier (v3), empty when untagged.
    @Default('') String nfcUid,

    /// v4: a desk seat, a meeting room or a parking bay; a room's
    /// capacity, a bay's kind, the place's own booking slot.
    @Default(ResourceKind.seat) ResourceKind resourceKind,
    int? capacity,
    ParkingKind? parkingKind,
    int? slotMinutes,
  }) = _WorkspaceXmlSeat;

  /// The cells the seat covers, as the editor's `Seat.footprint`.
  GridRect get footprint =>
      seatFootprintAt(x: x, y: y, orientation: orientation);
}

/// A `<desk>` with its seats nested inside.
@freezed
sealed class WorkspaceXmlDesk with _$WorkspaceXmlDesk {
  const factory WorkspaceXmlDesk({
    required String name,
    required GridRect rect,
    @Default(<WorkspaceXmlSeat>[]) List<WorkspaceXmlSeat> seats,

    /// v3: the desk's own price and whether it books as a whole.
    @Default(0) int priceCents,
    @Default(false) bool bookableAsWhole,
  }) = _WorkspaceXmlDesk;
}

/// An `<office>` with its desks nested inside.
@freezed
sealed class WorkspaceXmlOffice with _$WorkspaceXmlOffice {
  const factory WorkspaceXmlOffice({
    required String name,
    required int color,
    required bool bookableAsWhole,
    required GridRect rect,
    @Default(<WorkspaceXmlDesk>[]) List<WorkspaceXmlDesk> desks,

    /// v3: the office's own price.
    @Default(0) int priceCents,

    /// v4: the area's kind by its stored word (`workspace`, `parking`);
    /// the server's check refuses any other.
    @Default('workspace') String areaKind,
  }) = _WorkspaceXmlOffice;
}

/// A `<level>` (floor) with its offices nested inside.
@freezed
sealed class WorkspaceXmlLevel with _$WorkspaceXmlLevel {
  const factory WorkspaceXmlLevel({
    required String name,
    required int sortOrder,
    @Default(<WorkspaceXmlOffice>[]) List<WorkspaceXmlOffice> offices,

    /// v3: the level's price, whether it books as a whole, and the NAME of
    /// the site it belongs to ('' = the workspace's default).
    @Default(0) int priceCents,
    @Default(false) bool bookableAsWhole,
    @Default('') String site,
  }) = _WorkspaceXmlLevel;
}

/// The whole parsed document: settings + accessory catalog + floor-plan
/// structure, no ids. [accessories] is empty for a v1 file.
@freezed
sealed class WorkspaceXmlData with _$WorkspaceXmlData {
  const factory WorkspaceXmlData({
    required WorkspaceXmlSettings settings,
    @Default(<WorkspaceXmlAccessory>[]) List<WorkspaceXmlAccessory> accessories,
    @Default(<WorkspaceXmlLevel>[]) List<WorkspaceXmlLevel> levels,

    /// The v3 `<configuration>` tree; null for a v1/v2 document or a v3
    /// document without one. Compared structurally, nested maps and lists
    /// included.
    Map<String, Object?>? configuration,
  }) = _WorkspaceXmlData;
}
