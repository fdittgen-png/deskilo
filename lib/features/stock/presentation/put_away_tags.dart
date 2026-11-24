// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4379 (G13b), #4363 (G14) -- the tags of a put-away line whose item is tagged piece by piece: one tag per
// piece, read by typing, by a scanner that types or by the phone's NFC. A tag read twice in the sheet, or one
// more than the line still has pieces, is refused under the field; each tag read can be taken back before the
// put-away. A refusal of the server names the piece by its place among the tags (0889 detail {allocation, unit}).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import 'stock_config_text.dart';
import 'stock_nfc_button.dart';

/// [quantity] (in [unit]) in the item's inventory unit as a whole number of pieces; null when it is not one.
int? piecesOf(StockItemConfig item, String unit, ExactQuantity quantity) {
  final factor = countsInPieces(item, unit)
      ? (num: 1, den: 1)
      : item.units.where((u) => u.unit == unit).map((u) => (num: u.factorNum, den: u.factorDen)).firstOrNull;
  if (factor == null) return null;
  final micro = quantity.scaled(factor.num, factor.den).value?.micro;
  final one = ExactQuantity.parse('1').micro; // one piece, in the kernel's own scale
  if (micro == null || micro.remainder(one) != BigInt.zero) return null;
  return (micro ~/ one).toInt();
}

/// Whether a line in [unit] counts in the item's own unit: its quantity is the number of tags read.
bool countsInPieces(StockItemConfig item, String unit) => unit.isEmpty || unit == item.inventoryUnit;

/// The tags of one line, in the order read.
class PieceTags {
  final TextEditingController next = TextEditingController();
  final List<String> codes = [];
  String? problem;

  /// Reads [raw] as the next tag: refused (and said) when [readElsewhere] already holds it or [cap] tags are
  /// read; true when it was added.
  bool read(String raw, AppLocalizations l10n, {required bool Function(String code) readElsewhere, int? cap}) {
    // as the server keeps a tag (0886 `stock_tag_normalize`): upper case, without spaces, colons or dashes
    final code = raw.toUpperCase().replaceAll(RegExp(r'[\s:-]'), '');
    next.clear();
    if (code.isEmpty) return false;
    if (readElsewhere(code)) {
      problem = l10n.stockScanAlreadyRead(code);
    } else if (cap != null && codes.length >= cap) {
      problem = l10n.stockPutAwayTagAllRead(cap);
    } else {
      codes.add(code);
      problem = null;
      return true;
    }
    return false;
  }

  void drop(String code) {
    codes.remove(code);
    problem = null;
  }

  void dispose() => next.dispose();
}

/// What a refused put-away says: a refused piece is named by its place among the line's tags.
String putAwayProblem(AppLocalizations l10n, Object e) {
  if (e is! StockTagRefused) return stockProblemText(l10n, e);
  final text = stockProblemText(l10n, e, subject: StockSubject.tag);
  final unit = e.detail['unit'];
  return unit is int ? l10n.stockPutAwayPieceProblem(unit, text) : text;
}

/// The fields of one line's tags: how many are read of how many, the next tag, and each tag read.
List<Widget> pieceTagFields(
  BuildContext context, {
  required int lineNo,
  required PieceTags tags,
  required int? needed,
  required ValueChanged<String> onRead,
  required ValueChanged<String> onDrop,
}) {
  final l10n = context.l10n;
  return [
  Text(l10n.stockPutAwayTagsTitle, style: Theme.of(context).textTheme.labelLarge),
  if (needed != null) Text(l10n.stockPutAwayTagsCount(tags.codes.length, needed), key: ValueKey('putaway-$lineNo-tags-count')),
  AppTextField(
    key: ValueKey('putaway-$lineNo-tag'),
    controller: tags.next,
    fieldKey: 'putaway-$lineNo-tags',
    label: l10n.stockPutAwayTagField,
    error: tags.problem,
    textInputAction: TextInputAction.done,
    onSubmitted: onRead,
  ),
  // on its own line: the button grows with its "reading" sentence, which a row beside the field cannot size
  StockNfcButton(onUid: onRead),
  Wrap(
    spacing: 8,
    children: [
      for (final t in tags.codes)
        InputChip(
          key: ValueKey('putaway-$lineNo-tag-$t'),
          label: Text(t),
          deleteButtonTooltipMessage: l10n.stockPutAwayTagRemove(t),
          onDeleted: () => onDrop(t),
        ),
    ],
  ),
];
}
