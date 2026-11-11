// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- ending a settlement review: a person marks it handled with a note
// (what was done). Nothing is accepted here: correcting recorded amounts is
// an accounting correction and goes through the existing correction path.
import '../domain/settlement_fetch.dart';

class SettlementReviewCommands {
  const SettlementReviewCommands(this._reviews);

  final SettlementReviews _reviews;

  /// Marks [reviewId] handled with [note] (trimmed, 1 to
  /// [settlementReviewNoteMax] characters); false when it was handled
  /// already. A note out of bounds is refused before anything is sent.
  Future<bool> markHandled(String reviewId, String note) {
    final text = note.trim();
    if (text.isEmpty || text.length > settlementReviewNoteMax) {
      throw ArgumentError('a note of 1 to $settlementReviewNoteMax characters');
    }
    return _reviews.markSettlementReviewHandled(reviewId, text);
  }
}
