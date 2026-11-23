// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4363 (G14) -- what a refused tag command says, in words: the tag is bound elsewhere (and to what), retired
// lately (and for how long), on a piece still in stock, not in force here; or the content is not valid (a code
// that is no tag, an item that uses no tags or tags its pieces one by one). Anything else falls back to the
// stock's own wording.
import '../../../core/codes/dk_code.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import 'stock_config_text.dart';

String stockTagProblem(AppLocalizations l10n, Object error) => switch (error) {
  StockTagRefused(code: DkCode.dkg22, :final detail) => l10n.stockTagBoundElsewhere('${detail['owner'] ?? ''}'),
  StockTagRefused(code: DkCode.dkg23) => l10n.stockTagRetiredLately,
  StockTagRefused(code: DkCode.dkg24) => l10n.stockTagOnPiece,
  StockTagRefused(code: DkCode.dkg04) => l10n.stockTagNotInForce,
  StockTagRefused(code: DkCode.dkg25) => l10n.refusalStockNamePieces,
  StockTagRefused(code: DkCode.dkg26) => l10n.refusalStockPieceWhere,
  StockConfigRefused(reason: 'tag_malformed') => l10n.stockTagMalformed,
  StockConfigRefused(reason: 'tag_owner_unknown') => l10n.stockTagOwnerUnknown,
  StockConfigRefused(reason: 'tag_mode_none') => l10n.stockTagModeNone,
  StockConfigRefused(reason: 'tag_per_unit_item') => l10n.stockTagPerUnit,
  _ => stockSaveProblem(l10n, error),
};
