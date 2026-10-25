// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/features/money/domain/document_numbering.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';

import '../money_repository.dart';

/// #2591 — the demo's number series and the invoice fingerprint, answered
/// from one space's in-memory money store ([FakeMoneyRepository]); every other
/// port of that space reads and writes the same store.
class DemoDocumentNumbering implements DocumentNumbering {
  DemoDocumentNumbering(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<List<NumberSequence>> fetchNumberSequences(String workspaceId) async =>
      [
        for (final j in NumberSequence.journals)
          _m.numberSequences[j] ?? NumberSequence.defaultsFor(j),
      ];

  @override
  Future<String> previewDocumentNumber(
    String workspaceId,
    String journal,
  ) async {
    final s =
        _m.numberSequences[journal] ?? NumberSequence.defaultsFor(journal);
    return s.format(s.nextValue, kTestNow);
  }

  @override
  Future<String> verifyInvoiceSignature(String invoiceId) async =>
      _m.integrity[invoiceId] ?? 'verified';

  @override
  Future<void> setNumberSequence(
    String workspaceId,
    NumberSequence sequence, {
    int? raiseNextValueTo,
  }) async {
    final current = _m.numberSequences[sequence.journal];
    if (raiseNextValueTo != null &&
        current != null &&
        raiseNextValueTo < current.nextValue) {
      throw StateError('a sequence never goes backwards');
    }
    _m.lastNumberSequence = sequence.copyWith(
      nextValue: raiseNextValueTo ?? current?.nextValue,
      stored: true,
    );
    _m.numberSequences[sequence.journal] = _m.lastNumberSequence!;
  }
}
