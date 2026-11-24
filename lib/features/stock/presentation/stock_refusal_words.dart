// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- the goods ledger's refusal codes and their words, registered with
// the core table (lib/core/trace/feature_refusals.dart) at start. DKG03 and
// DKG15 that name the main store say what it holds, and point to the item's
// stock.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import '../../../core/codes/dk_code.dart';
import '../../../core/trace/feature_refusals.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';

/// Registers the goods ledger's words and the main store's link.
void registerStockRefusals() =>
    FeatureRefusals.register(_stockWords, link: _stockLink);

String? _stockWords(AppLocalizations l10n, String code, String? details) {
  final main = _mainStoreOf(code, details);
  if (main != null) {
    return code == DkCode.dkg15
        ? l10n.refusalMainStoreExpired(main.held, main.asked)
        : l10n.refusalMainStoreShort(main.held, main.asked);
  }
  return switch (code) {
    DkCode.dkg01 => l10n.refusalStockOff,
    DkCode.dkg02 => l10n.refusalStockUnit,
    DkCode.dkg03 => l10n.refusalStockNotEnough,
    DkCode.dkg04 => l10n.refusalStockItem,
    DkCode.dkg05 => l10n.refusalStockLocation,
    DkCode.dkg06 => l10n.refusalStockLot,
    DkCode.dkg07 => l10n.refusalStockMove,
    DkCode.dkg08 => l10n.refusalStockHistory,
    DkCode.dkg09 => l10n.refusalStockPage,
    DkCode.dkg10 => l10n.refusalStockStale,
    DkCode.dkg11 => l10n.refusalStockConfig,
    DkCode.dkg12 => l10n.refusalStockVariant,
    DkCode.dkg13 => l10n.refusalStockLedgerKept,
    DkCode.dkg15 => l10n.refusalStockOnlyExpired,
    DkCode.dkg16 => l10n.refusalStockReturnChanged,
    DkCode.dkg17 => l10n.refusalStockReturnBeyond,
    DkCode.dkg18 => l10n.refusalStockReturnSource,
    DkCode.dkg19 => l10n.refusalStockCountDecided,
    DkCode.dkg20 => l10n.refusalStockCountStale,
    DkCode.dkg21 => l10n.refusalStockCountSelf,
    _ => _tagWords(l10n, code),
  };
}

/// #4362 -- the tags, the named pieces and the handling units.
String? _tagWords(AppLocalizations l10n, String code) => switch (code) {
  DkCode.dkg22 => l10n.refusalStockTagBound,
  DkCode.dkg23 => l10n.refusalStockTagRetiredLately,
  DkCode.dkg24 => l10n.refusalStockPieceInStock,
  DkCode.dkg25 => l10n.refusalStockNamePieces,
  DkCode.dkg26 => l10n.refusalStockPieceWhere,
  DkCode.dkg27 => l10n.refusalStockUnitChanged,
  DkCode.dkg28 => l10n.refusalStockUnitContent,
  DkCode.dkg29 => l10n.refusalStockUnitCodeTaken,
  _ => null,
};

/// The Stock page of the item a sale's confirmation was refused for.
String? _stockLink(String code, String? details) {
  final main = _mainStoreOf(code, details);
  return main == null
      ? null
      : '/stock?item=${Uri.encodeQueryComponent(main.itemId)}';
}

/// What the main store holds, when a sale's confirmation was refused for it
/// (DKG03 less than asked, DKG15 only goods past their date): the server says
/// it as a JSON detail, read here, never its sentence.
({String itemId, String held, String asked})? _mainStoreOf(
  String code,
  String? details,
) {
  if (code != DkCode.dkg03 && code != DkCode.dkg15) return null;
  if (details == null) return null;
  try {
    final r = JsonReader.of(jsonDecode(details), context: DkCode.dkg03);
    if (r.stringOrNull('scope') != 'main_store') return null;
    final item = r.stringOrNull('item_id');
    final held = r.stringOrNull('held');
    final asked = r.stringOrNull('asked');
    if (item == null || held == null || asked == null) return null;
    return (itemId: item, held: held, asked: asked);
  } on Object catch (e, st) {
    // A detail that is not our JSON is no hint: the generic words stand.
    TraceLogger.instance.log(
      TraceLevel.debug,
      'stock',
      'a main store detail was not read',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}
