// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- what the till shows (the basket, its price, a sale made, the refusal of the last act) and the two refusals the till
// says by itself. Kept apart from the session that changes it so the parts that serve it (the offline selling, #4373) can read
// and show it without importing the session back.
import 'package:flutter/foundation.dart';

import '../../../core/failure/app_failure.dart' show TypedRefusal;
import '../domain/counter_till.dart';

/// What the till shows: the basket, its price, a sale made, or the refusal of the last act.
@immutable
class TillState {
  const TillState({this.lines = const [], this.draft, this.sold, this.busy = false, this.problem, this.change, this.unconfirmed = false, this.card, this.cardUnknown = false, this.soldCash = false});

  final List<TillLine> lines;
  final TillDraft? draft;
  final TillSold? sold;
  final bool busy;

  /// The error of the last act, as the server (or the client's own check) raised it; null when it went through.
  final Object? problem;

  /// The change due on the sale just made, in minor units.
  final int? change;

  /// The sale was sent and its answer did not come: it may have been made. Nothing else is done to the basket until the
  /// sale is confirmed (sent again under the same request id, which the server answers with the sale it made).
  final bool unconfirmed;

  /// #4185 -- the card authorization asked of the terminal for this sale, while its answer is awaited.
  final TillCardAsked? card;

  /// #4185 -- the terminal's answer was lost: the card is never asked again for this sale; someone who may see the
  /// finances settles it from the receipts, where the sale is completed once.
  final bool cardUnknown;

  /// #4368 -- the sale just made took cash: the drawer an attached printer drives opens for it.
  final bool soldCash;

  bool get empty => lines.isEmpty;

  TillState copyWith({
    List<TillLine>? lines,
    TillDraft? Function()? draft,
    TillSold? Function()? sold,
    bool? busy,
    Object? Function()? problem,
    int? Function()? change,
  }) => TillState(
    lines: lines ?? this.lines,
    draft: draft == null ? this.draft : draft(),
    sold: sold == null ? this.sold : sold(),
    busy: busy ?? this.busy,
    problem: problem == null ? this.problem : problem(),
    change: change == null ? this.change : change(),
    unconfirmed: unconfirmed,
    card: card,
    cardUnknown: cardUnknown,
    soldCash: soldCash,
  );

  /// The same state with the card asked of the terminal set (null: none asked).
  TillState withCard(TillCardAsked? asked) =>
      TillState(lines: lines, draft: draft, sold: sold, busy: busy, problem: problem, change: change, unconfirmed: unconfirmed, card: asked, cardUnknown: cardUnknown, soldCash: soldCash);

  /// The same state with the terminal's answer marked as lost, or not.
  TillState withCardUnknown({required bool value}) =>
      TillState(lines: lines, draft: draft, sold: sold, busy: busy, problem: problem, change: change, unconfirmed: unconfirmed, card: card, cardUnknown: value, soldCash: soldCash);

  /// #4368 -- the same state with the sale just made marked as taking cash, or not.
  TillState withSoldCash({required bool value}) =>
      TillState(lines: lines, draft: draft, sold: sold, busy: busy, problem: problem, change: change, unconfirmed: unconfirmed, card: card, cardUnknown: cardUnknown, soldCash: value);

  /// The same state with the sale marked as waiting to be confirmed, or not.
  TillState withUnconfirmed({required bool value}) =>
      TillState(lines: lines, draft: draft, sold: sold, busy: busy, problem: problem, change: change, unconfirmed: value, card: card, cardUnknown: cardUnknown, soldCash: soldCash);
}

/// The cash given is less than the total: said by the till itself before anything is sent.
class TillCashShort implements Exception {
  const TillCashShort();
}

/// #4185 -- the terminal declined the card: nothing was taken, the sale is still to be paid.
class TillCardDeclined implements TypedRefusal {
  const TillCardDeclined();
}

/// A weighed or counted line was rung up without a quantity above zero: the till asks for the weight first.
class TillQuantityMissing implements TypedRefusal {
  const TillQuantityMissing();
}

/// The server's draft does not describe the basket on the screen: it is not sold.
class TillDraftMismatch implements Exception {
  const TillDraftMismatch();
}
