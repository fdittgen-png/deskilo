// SPDX-License-Identifier: AGPL-3.0-or-later
import 'bank_records.dart';
import 'bank_statement.dart';

/// A line obtained through the authorized statement read that supplies its
/// account and currency. A line is not a cross-account identity.
typedef BankCanonicalLine = ({
  String account,
  String currency,
  StoredBankLine line,
});

/// Maps source movements suppressed as known to a unique retained movement
/// of the same account and currency. Null means missing or ambiguous: a
/// transaction ID shared by multiple rows, an absent ID, or mismatched facts
/// is never a safe match. This does not prove period coverage or a snapshot.
List<StoredBankLine>? mapBankSourceMovements({
  required BankStatement source,
  required List<StoredBankLine> ownLines,
  required List<BankCanonicalLine> candidates,
}) {
  final byPosition = {for (final line in ownLines) line.position: line};
  if (byPosition.length != ownLines.length ||
      ownLines.map((l) => l.id).toSet().length != ownLines.length) {
    return null;
  }
  final usedIds = <String>{};
  final resolved = <StoredBankLine>[];
  for (var i = 0; i < source.lines.length; i++) {
    final expected = source.lines[i];
    final own = byPosition[i + 1];
    StoredBankLine? selected;
    if (own != null) {
      if (!_sameMovement(expected, own)) return null;
      selected = own;
    } else {
      if (expected.transactionId.trim().isEmpty) return null;
      final matches = candidates
          .where(
            (candidate) =>
                candidate.account == source.account &&
                candidate.currency == source.currency &&
                candidate.line.transactionId == expected.transactionId.trim(),
          )
          .toList();
      if (matches.length != 1 ||
          !_sameMovement(expected, matches.single.line)) {
        return null;
      }
      selected = matches.single.line;
    }
    if (!usedIds.add(selected.id)) return null;
    resolved.add(selected);
  }
  // A stored line outside the source is a conflict, not an extra movement.
  if (ownLines.any((line) => !usedIds.contains(line.id))) return null;
  return resolved;
}

bool _sameMovement(BankLine expected, StoredBankLine actual) =>
    expected.bookingDate == actual.bookingDate &&
    expected.valueDate == actual.valueDate &&
    expected.amountCents == actual.amountCents &&
    expected.currency == actual.currency &&
    expected.transactionId.trim() == actual.transactionId &&
    expected.counterpartyName == actual.counterpartyName &&
    expected.counterpartyIban == actual.counterpartyIban &&
    expected.reference == actual.reference &&
    expected.endToEndId == actual.endToEndId &&
    expected.remittance == actual.remittance;
