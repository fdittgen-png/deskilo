// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/accounting_source_queries.dart';
import 'package:deskilo/features/money/domain/accounting_source_snapshot.dart';

import '../money_repository.dart';

/// #2591 — the one fiscal source an accounting export reads, in the demo:
/// answered from one space's in-memory money store ([FakeMoneyRepository]);
/// every other port of that space reads and writes the same store.
class DemoAccountingSource implements AccountingSourceQueries {
  DemoAccountingSource(this._m);

  final FakeMoneyRepository _m;

  /// The year's books in one call from the same memory (#2365): the
  /// matches of the year's invoices and of the settlements that regroup
  /// them, and their instalments, as the server's source delivers them.
  AccountingSourceSnapshot _snapshot(int year) {
    final inYear = [
      for (final i in _m.invoices)
        if (i.issuedAt.year == year) i,
    ];
    final held = {for (final i in inYear) i.id};
    final settlements = {for (final i in inYear) ?i.settledByInvoiceId};
    return AccountingSourceSnapshot.demo(
      invoices: [
        for (final i in inYear)
          (id: i.id, number: i.number, totalCents: i.totalCents),
      ],
      matches: {
        for (final e in _m.invoiceMatchesStore.entries)
          if (held.contains(e.key) || settlements.contains(e.key))
            e.key: e.value,
      },
      instalments: {
        for (final e in _m.invoiceInstalmentsStore.entries)
          if (held.contains(e.key)) e.key: List.of(e.value),
      },
      ledger: [
        for (final e in _m.ledger)
          if (e.on.year == year) e,
      ],
      repartitions: [
        for (final r in _m.repartitions)
          if ((r.appliedAt ?? r.createdAt).year == year) r,
      ],
    );
  }

  @override
  Future<AccountingSourceSnapshot> fetchAccountingSource({
    required String workspaceId,
    required int year,
  }) async => _snapshot(year);
}
