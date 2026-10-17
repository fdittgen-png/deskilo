// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../../../core/data/read_provenance.dart';
import '../../../core/data/system_columns.dart';
import 'expense_repartition.dart';
import 'ledger_entry.dart';

/// Why a fiscal source was not accepted. None of them is a smaller file:
/// the export stops and says which.
enum AccountingSourceFailure {
  /// The scope is over the producer's row budget; the period must narrow.
  overBudget,

  /// The answer is for another workspace, period, principal or version
  /// than the one asked, or its control totals disagree with its rows.
  inconsistent,

  /// The books changed between the invoice list the person looked at and
  /// the source read: a new invoice, or one whose value moved.
  invoicesMoved,
}

class AccountingSourceException implements Exception {
  const AccountingSourceException(this.failure, this.detail);

  final AccountingSourceFailure failure;
  final String detail;

  @override
  String toString() => 'AccountingSourceException(${failure.name}): $detail';
}

/// The identity and value of one invoice as the source holds it.
typedef SourceInvoice = ({String id, String number, int totalCents});

/// The books of one workspace and period as ONE server response under ONE
/// statement snapshot (`accounting_source_snapshot_v1`, #2365): the ledger
/// and repartitions an export is built from, the invoice headers they sit
/// beside, and the control totals the server computed from those very rows.
/// [fromRpc] accepts it only when it is the answer to the question asked and
/// its own totals agree with its own rows.
class AccountingSourceSnapshot {
  const AccountingSourceSnapshot._({
    required this.provenance,
    required this.invoices,
    required this.ledger,
    required this.repartitions,
    required this.matchedCents,
  });

  /// The in-memory demo workspace has no server to snapshot: its books are
  /// read in one call from the same memory, and say so.
  AccountingSourceSnapshot.demo({
    required this.invoices,
    required this.ledger,
    required this.repartitions,
  })  : provenance = const ReadProvenance.traversal(
          reason: 'in-memory demo books',
        ),
        matchedCents = 0;

  final ReadProvenance provenance;
  final List<SourceInvoice> invoices;
  final List<LedgerEntry> ledger;
  final List<ExpenseRepartition> repartitions;

  /// Sum of the matches of the in-scope invoices, as delivered.
  final int matchedCents;

  /// Parses the answer to a request for [workspaceId] and `[from, to]`
  /// made by [principal]. Strict: an unknown ledger kind or category, a
  /// wrong echo or a total that does not equal the sum of its rows is an
  /// [AccountingSourceException], never a skipped row.
  factory AccountingSourceSnapshot.fromRpc(
    Object? raw, {
    required String workspaceId,
    required String from,
    required String to,
    required String principal,
  }) {
    final r = JsonReader.of(raw, context: 'accounting_source_snapshot_v1');
    Never bad(String why) =>
        throw AccountingSourceException(AccountingSourceFailure.inconsistent, why);

    if (r.integer('version') != 1) bad('unsupported version');
    final status = r.string('status');
    if (status == 'refused') {
      throw AccountingSourceException(
        AccountingSourceFailure.overBudget,
        '${r.stringOr('reason')}: ${r.stringOr('action')}',
      );
    }
    if (status != 'ok') bad('unknown status $status');
    if (r.string('workspace_id') != workspaceId) bad('another workspace');
    if (r.string('from') != from || r.string('to') != to) bad('another period');
    if (r.string('principal') != principal) bad('another principal');
    final cutoff = r.string('cutoff');
    if (cutoff.isEmpty) bad('no snapshot named');

    final invoices = r.objects(
      'invoices',
      (i) => (
        id: i.string('id'),
        number: i.string('number'),
        totalCents: i.integer('total_cents'),
      ),
    );
    final ledger = r.objects('ledger', _strictLedger);
    final repartitions = r.objects(
      'repartitions',
      (row) => ExpenseRepartition.fromJson(row.json),
    );
    final matched = r.objects('matches', (m) => m.integer('paid_cents'));

    final totals = r.objectOrAbsent('totals');
    void agree(String what, JsonReader t, int count, int value, String key) {
      if (t.integer('count') != count || t.integer(key) != value) {
        bad('$what totals disagree with the rows');
      }
    }

    int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);
    agree('invoice', totals.objectOrAbsent('invoices'), invoices.length,
        sum(invoices.map((i) => i.totalCents)), 'total_cents');
    agree('match', totals.objectOrAbsent('matches'), matched.length,
        sum(matched), 'paid_cents');
    agree('ledger', totals.objectOrAbsent('ledger'), ledger.length,
        sum(ledger.map((e) => e.amountCents)), 'sum_cents');
    final l = totals.objectOrAbsent('ledger');
    if (l.integer('credit_cents') !=
            sum(ledger
                .where((e) => e.kind == LedgerKind.credit)
                .map((e) => e.amountCents)) ||
        l.integer('charge_cents') !=
            sum(ledger
                .where((e) => e.kind == LedgerKind.charge)
                .map((e) => e.amountCents))) {
      bad('ledger sides disagree with the rows');
    }
    agree('repartition', totals.objectOrAbsent('repartitions'),
        repartitions.length, sum(repartitions.map((x) => x.amountCents)),
        'amount_cents');

    return AccountingSourceSnapshot._(
      provenance: ReadProvenance.snapshot(
        sourceRevision: cutoff,
        target: workspaceId,
        principal: principal,
        queryFingerprint: 'accounting_source_snapshot_v1/$from/$to',
      ),
      invoices: invoices,
      ledger: ledger,
      repartitions: repartitions,
      matchedCents: sum(matched),
    );
  }

  /// Refuses unless every invoice of the source is one the person already
  /// holds, with the same value: an invoice issued or changed since the list
  /// was loaded means the export would mix two moments.
  void requireInvoicesHeld(Iterable<SourceInvoice> held) {
    final byId = {for (final i in held) i.id: i};
    for (final i in invoices) {
      final h = byId[i.id];
      if (h == null || h.totalCents != i.totalCents) {
        throw AccountingSourceException(
          AccountingSourceFailure.invoicesMoved,
          'invoice ${i.number} is not as loaded',
        );
      }
    }
  }
}

LedgerEntry _strictLedger(JsonReader row) {
  final kind = LedgerKind.values.asNameMap()[row.string('kind')];
  final category = LedgerCategory.values.asNameMap()[row.string('category')];
  if (kind == null || category == null) {
    throw AccountingSourceException(
      AccountingSourceFailure.inconsistent,
      'unknown ledger kind/category ${row.string('kind')}/${row.string('category')}',
    );
  }
  return LedgerEntry(
    system: SystemColumns.fromRow(row.json),
    id: row.string('id'),
    memberId: row.string('member_id'),
    kind: kind,
    category: category,
    amountCents: row.integer('amount_cents'),
    description: row.stringOr('description'),
    period: row.stringOr('period'),
    createdAt: row.dateTime('created_at'),
    occurredOn: row.dateTimeOrNull('occurred_on'),
  );
}
