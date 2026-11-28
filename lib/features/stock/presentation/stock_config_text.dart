// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1), #4402 -- the words of a stock refusal, in one place: the
// server's reason (a [StockRefusal], read at the data boundary) said in the
// reader's language under the field it names, and what any failed stock
// command says. A reason has one sentence; the few reasons two kinds of thing
// share (a duplicate name of a variant or of a group, a unit in use by an item
// or as a unit of measure, an unknown tag) take the words of the [StockSubject]
// the screen saves. A missing choice the app sees itself has its own words
// (`stockRequired...`), never a server reason.
import '../../../core/codes/dk_code.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';

/// What a screen saves, for the few reasons that read differently by it.
enum StockSubject {
  /// An item, a place, a variant, a movement: the stock's own words.
  stock,

  /// An item group.
  group,

  /// A tag or a named piece.
  tag,

  /// A unit of measure of the business.
  measureUnit,
}

/// The sentence of [reason] under its field.
String stockRefusalText(AppLocalizations l10n, StockRefusal reason, {StockSubject subject = StockSubject.stock}) =>
    switch ((subject, reason)) {
      (StockSubject.group, StockRefusal.nameDuplicate) => l10n.stockReasonGroupNameDuplicate,
      (StockSubject.measureUnit, StockRefusal.unitInUse) => l10n.measureReasonInUse,
      _ => _reasonText(l10n, reason),
    };

String _reasonText(AppLocalizations l10n, StockRefusal reason) => switch (reason) {
  StockRefusal.codeDuplicate => l10n.stockReasonCodeDuplicate,
  StockRefusal.codeMalformed => l10n.stockReasonCodeMalformed,
  StockRefusal.codeUnitRemoved => l10n.stockReasonCodeUnitRemoved,
  StockRefusal.conversionSameUnit => l10n.stockReasonConversionSameUnit,
  StockRefusal.conversionUnknown => l10n.stockReasonConversionUnknown,
  StockRefusal.costInvalid => l10n.stockReasonCostInvalid,
  StockRefusal.costRateMissing => l10n.stockReasonCostRateMissing,
  StockRefusal.defaultPurchaseTwice => l10n.stockReasonDefaultPurchaseTwice,
  StockRefusal.defaultSaleTwice => l10n.stockReasonDefaultSaleTwice,
  StockRefusal.depth => l10n.itemGroupReasonDepth,
  StockRefusal.dimensionInvalid => l10n.measureReasonDimension,
  StockRefusal.dimensionMismatch => l10n.stockReasonDimensionMismatch,
  StockRefusal.eceInvalid => l10n.measureReasonEce,
  StockRefusal.expiryMalformed => l10n.stockReasonExpiryMalformed,
  StockRefusal.expiryRequired => l10n.stockReasonExpiryRequired,
  StockRefusal.factorInvalid => l10n.stockReasonFactorInvalid,
  StockRefusal.groupUnknown => l10n.itemGroupReasonGroupUnknown,
  StockRefusal.gtinCheck => l10n.stockReasonGtinCheck,
  StockRefusal.gtinLength => l10n.stockReasonGtinLength,
  StockRefusal.hasSubgroups => l10n.itemGroupReasonHasSubgroups,
  StockRefusal.hasTags => l10n.stockReasonHasTags,
  StockRefusal.homeInvalid => l10n.stockReasonHomeInvalid,
  StockRefusal.inUse => l10n.itemGroupReasonInUse,
  StockRefusal.inexact => l10n.measureReasonInexact,
  StockRefusal.itemForeign => l10n.stockReasonItemForeign,
  StockRefusal.itemNotStocked => l10n.stockReasonItemNotStocked,
  StockRefusal.itemUnknown => l10n.stockReasonGroupItemUnknown,
  StockRefusal.kindUnknown => l10n.stockReasonKindUnknown,
  StockRefusal.labelRequired => l10n.measureReasonName,
  StockRefusal.levelChildrenWrong => l10n.stockReasonLevelChildrenWrong,
  StockRefusal.levelParentMissing => l10n.stockReasonLevelParentMissing,
  StockRefusal.levelParentWrong => l10n.stockReasonLevelParentWrong,
  StockRefusal.lineConflict => l10n.stockReasonLineConflict,
  StockRefusal.lineUnknown => l10n.stockReasonLineUnknown,
  StockRefusal.locationCycle => l10n.stockReasonLocationCycle,
  StockRefusal.locationDefault => l10n.stockReasonLocationDefault,
  StockRefusal.locationForeign => l10n.stockReasonLocationForeign,
  StockRefusal.locationHasChildren => l10n.stockReasonLocationHasChildren,
  StockRefusal.locationOccupied => l10n.stockReasonLocationOccupied,
  StockRefusal.locationParentForeign => l10n.stockReasonLocationParentForeign,
  StockRefusal.locationVirtual => l10n.stockReasonLocationVirtual,
  StockRefusal.lotCodeRequired => l10n.stockReasonLotCodeRequired,
  StockRefusal.lotExpired => l10n.stockReasonLotExpired,
  StockRefusal.lotGroupConflict => l10n.stockReasonLotGroupConflict,
  StockRefusal.malformed => l10n.stockReasonMalformed,
  StockRefusal.mappingDuplicate => l10n.stockReasonMappingDuplicate,
  StockRefusal.mappingUnknown => l10n.stockReasonMappingUnknown,
  StockRefusal.nameDuplicate => l10n.stockReasonNameDuplicate,
  StockRefusal.nameLength => l10n.stockReasonGroupNameLength,
  StockRefusal.nameMalformed => l10n.stockReasonNameMalformed,
  StockRefusal.needsSerial => l10n.itemGroupReasonNeedsSerial,
  StockRefusal.notOverridable => l10n.itemGroupReasonNotOverridable,
  StockRefusal.oneSource => l10n.stockReasonOneSource,
  StockRefusal.outOfRange => l10n.stockReasonOutOfRange,
  StockRefusal.packageUnit => l10n.stockReasonPackageUnit,
  StockRefusal.overAllocated => l10n.stockReasonOverAllocated,
  StockRefusal.placeUnusable => l10n.stockReasonPlaceUnusable,
  StockRefusal.parentInactive => l10n.stockReasonParentInactive,
  StockRefusal.pickRoleUnknown => l10n.stockReasonPickRoleUnknown,
  StockRefusal.placeUnknown => l10n.stockReasonGroupPlaceUnknown,
  StockRefusal.pointFixed => l10n.stockReasonPointFixed,
  StockRefusal.pointTwice => l10n.stockReasonPointTwice,
  StockRefusal.priceInvalid => l10n.stockReasonPriceInvalid,
  StockRefusal.quantityAndTarget => l10n.stockReasonQuantityAndTarget,
  StockRefusal.quantityInvalid => l10n.stockReasonQuantityInvalid,
  StockRefusal.reasonPlaces => l10n.stockReasonReasonPlaces,
  StockRefusal.receiptUnknown => l10n.stockReasonReceiptUnknown,
  StockRefusal.receiveOver => l10n.stockReasonReceiveOver,
  StockRefusal.registryUnit => l10n.stockReasonRegistryUnit,
  StockRefusal.required => l10n.stockReasonGroupNameRequired,
  StockRefusal.sameSite => l10n.stockReasonSameSite,
  StockRefusal.siteUnknown => l10n.stockReasonSiteUnknown,
  StockRefusal.stockOnHand => l10n.stockReasonStockOnHand,
  StockRefusal.stockWithoutVariant => l10n.stockReasonStockWithoutVariant,
  StockRefusal.supplierForeign => l10n.stockReasonSupplierForeign,
  StockRefusal.tagMalformed => l10n.stockReasonTagMalformed,
  StockRefusal.tagModeNone => l10n.stockReasonTagModeNone,
  StockRefusal.tagOwnerInactive => l10n.stockReasonTagOwnerInactive,
  StockRefusal.tagOwnerUnknown => l10n.stockReasonTagOwnerUnknown,
  StockRefusal.tagPerUnitItem => l10n.stockReasonTagPerUnitItem,
  StockRefusal.targetBelowPoint => l10n.stockReasonTargetBelowPoint,
  StockRefusal.tooLong => l10n.stockReasonTooLong,
  StockRefusal.trackingUnsupported => l10n.stockReasonTrackingUnsupported,
  StockRefusal.transferNeedsTransit => l10n.stockReasonTransferNeedsTransit,
  StockRefusal.transferUnknown => l10n.stockReasonTransferUnknown,
  StockRefusal.transitIsSystem => l10n.stockReasonTransitIsSystem,
  StockRefusal.unitArchived => l10n.stockReasonUnitArchived,
  StockRefusal.unitDuplicate => l10n.stockReasonUnitDuplicate,
  StockRefusal.unitFixed => l10n.measureReasonFixed,
  StockRefusal.unitInUse => l10n.stockReasonUnitInUse,
  StockRefusal.unitNotOfItem => l10n.stockReasonUnitNotOfItem,
  StockRefusal.unitUnknown => l10n.stockReasonUnitUnknown,
  StockRefusal.unitUnmapped => l10n.stockReasonUnitUnmapped,
  StockRefusal.unitsNotTracked => l10n.stockReasonUnitsNotTracked,
  StockRefusal.unknownReference => l10n.stockReasonGroupUnknownReference,
  StockRefusal.valueForeign => l10n.stockReasonValueForeign,
  StockRefusal.valueRequired => l10n.stockReasonGroupValueRequired,
  StockRefusal.variantCombinationDuplicate => l10n.stockReasonCombinationDuplicate,
  StockRefusal.variantHasStock => l10n.stockReasonVariantHasStock,
  StockRefusal.variantInUse => l10n.stockReasonVariantInUse,
  StockRefusal.variantRequired => l10n.stockReasonVariantRequired,
  StockRefusal.variantUnknown => l10n.stockReasonVariantUnknown,
  StockRefusal.variantValuesMissing => l10n.stockReasonValuesMissing,
  StockRefusal.vatRateUnknown => l10n.stockReasonGroupVatRateUnknown,
  StockRefusal.wrongSite => l10n.stockReasonWrongSite,
  // no words of their own yet: the generic refusal
  StockRefusal.oneSubject ||
  StockRefusal.preferredTwice ||
  StockRefusal.tagsOff ||
  StockRefusal.unknown ||
  StockRefusal.other => l10n.stockReasonOther,
};

/// What a failed stock command says: a stale read, a unit the first movement
/// fixed, too little on hand, a tag or a handling unit refused, a refusal with
/// its reason, a refusal the app knows everywhere (who may, who you are), or
/// (anything else) that nothing was saved.
String stockProblemText(AppLocalizations l10n, Object error, {StockSubject subject = StockSubject.stock}) =>
    switch (error) {
      StockConfigStale() => l10n.stockEditStale,
      StockConfigInUse() => l10n.stockEditInUse,
      StockNotEnough() => l10n.refusalStockNotEnough,
      StockUnitRefused(code: DkCode.dkg27) => l10n.refusalStockUnitChanged,
      StockUnitRefused(code: DkCode.dkg29) => l10n.refusalStockUnitCodeTaken,
      StockUnitRefused() => l10n.refusalStockUnitContent,
      StockTagRefused(code: DkCode.dkg22, :final owner) => l10n.stockTagBoundElsewhere(owner),
      StockTagRefused(code: DkCode.dkg23) => l10n.stockTagRetiredLately,
      StockTagRefused(code: DkCode.dkg24) => l10n.stockTagOnPiece,
      StockTagRefused(code: DkCode.dkg25) => l10n.refusalStockNamePieces,
      StockTagRefused(code: DkCode.dkg26) => l10n.refusalStockPieceWhere,
      StockTagRefused(code: DkCode.dkg04) when subject == StockSubject.tag => l10n.stockTagNotInForce,
      StockConfigRefused(:final reason) => stockRefusalText(l10n, reason, subject: subject),
      _ => knownRefusalText(l10n, error) ?? l10n.stockEditNotSaved,
    };
