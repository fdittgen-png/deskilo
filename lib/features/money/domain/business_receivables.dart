// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (A) -- what a business is still owed, as the server answers it: one row
// per currency, never added across currencies and never netted against what the
// business owes. The amounts partition the receivable: still to collect, declared
// (a payment waiting for the business, or being paid online), received and not
// yet matched, and awaiting approval. A refund due to a customer is the
// business's debt to the customer and stays apart from them.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import '../../../core/backend/operation_context.dart' show WorkspaceTarget;

/// One currency of one business's receivables.
@immutable
class BusinessReceivablesRow {
  const BusinessReceivablesRow({
    required this.currency,
    required this.toCollectCents,
    required this.declaredCents,
    required this.receivedUnmatchedCents,
    required this.awaitingCents,
    required this.refundDueCents,
    required this.invoices,
  });

  factory BusinessReceivablesRow.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'business receivables row');
    return BusinessReceivablesRow(
      currency: row.string('currency'),
      toCollectCents: row.integer('to_collect_cents'),
      declaredCents: row.integer('declared_cents'),
      receivedUnmatchedCents: row.integer('received_unmatched_cents'),
      awaitingCents: row.integer('awaiting_cents'),
      refundDueCents: row.integer('refund_due_cents'),
      invoices: row.integer('invoices'),
    );
  }

  final String currency;
  final int toCollectCents;
  final int declaredCents;
  final int receivedUnmatchedCents;
  final int awaitingCents;

  /// What the business owes its customers back: never part of [receivableCents].
  final int refundDueCents;

  /// How many invoices (and credit notes) the amounts rest on.
  final int invoices;

  /// The four states that are still to arrive, in this currency.
  int get receivableCents =>
      toCollectCents + declaredCents + receivedUnmatchedCents + awaitingCents;
}

/// One business's complete summary: its currencies side by side.
@immutable
class BusinessReceivables {
  const BusinessReceivables({required this.workspaceId, required this.rows});

  factory BusinessReceivables.fromJson(Object? raw) {
    final result = JsonReader.of(raw, context: 'business_receivables_summary_v1');
    return BusinessReceivables(
      workspaceId: result.string('workspace_id'),
      rows: [
        for (final row in result.list('rows'))
          BusinessReceivablesRow.fromJson(row),
      ],
    );
  }

  final String workspaceId;
  final List<BusinessReceivablesRow> rows;
}

/// Where one business's read stands: answered, refused (the person may not read
/// this business's money), or unavailable (it could not be read). An answer is
/// never confused with zero.
sealed class BusinessReceivablesSource {
  const BusinessReceivablesSource(this.target, this.name);

  /// Which business, on which installation: the identity every open and every
  /// cache of this source is keyed on, so equal local ids on two installations
  /// never collide.
  final WorkspaceTarget target;
  final String name;

  String get workspaceId => target.workspaceId;
}

final class BusinessReceivablesAnswered extends BusinessReceivablesSource {
  const BusinessReceivablesAnswered(super.target, super.name, this.summary);

  final BusinessReceivables summary;
}

final class BusinessReceivablesRefused extends BusinessReceivablesSource {
  const BusinessReceivablesRefused(super.target, super.name);
}

final class BusinessReceivablesUnavailable extends BusinessReceivablesSource {
  const BusinessReceivablesUnavailable(super.target, super.name);
}

/// The state of a receivable invoice, as the server buckets it: each invoice
/// is in exactly one, so the states partition what the summary adds up.
enum ReceivableState {
  toCollect('to_collect'),
  declared('declared'),
  receivedUnmatched('received_unmatched'),
  awaiting('awaiting'),
  refundDue('refund_due');

  const ReceivableState(this.wire);

  final String wire;

  /// The state the server named, or null for one this app does not know: such a
  /// row keeps its amounts and says no state, it is never read as another.
  static ReceivableState? of(String wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// Where the next page of invoices starts: the keyset the server answered.
typedef ReceivablesCursor = ({String issuedAt, String id});

/// One invoice (or credit note) behind a business's receivables.
@immutable
class ReceivableInvoiceRow {
  const ReceivableInvoiceRow({
    required this.invoiceId,
    required this.number,
    required this.issuedAt,
    required this.dueOn,
    required this.memberName,
    required this.currency,
    required this.totalCents,
    required this.stillDueCents,
    required this.awaitingCents,
    required this.state,
  });

  factory ReceivableInvoiceRow.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'receivable invoice');
    return ReceivableInvoiceRow(
      invoiceId: row.string('invoice_id'),
      number: row.stringOr('number'),
      issuedAt: DateTime.parse(row.string('issued_at')),
      dueOn: DateTime.tryParse(row.stringOr('due_on')),
      memberName: row.stringOr('member_name'),
      currency: row.string('currency'),
      totalCents: row.integer('total_cents'),
      stillDueCents: row.integer('still_due_cents'),
      awaitingCents: row.integer('awaiting_cents'),
      state: ReceivableState.of(row.string('state')),
    );
  }

  final String invoiceId;
  final String number;
  final DateTime issuedAt;
  final DateTime? dueOn;
  final String memberName;
  final String currency;
  final int totalCents;
  final int stillDueCents;
  final int awaitingCents;
  final ReceivableState? state;
}

/// One page of invoices with an explicit continuation: a null [next] is the end,
/// never a guess.
@immutable
class ReceivablesPage {
  const ReceivablesPage({required this.rows, required this.next});

  factory ReceivablesPage.fromJson(Object? raw) {
    final result = JsonReader.of(raw, context: 'business_receivables_page_v1');
    final cursor = result.objectOrNull('next');
    return ReceivablesPage(
      rows: [
        for (final row in result.list('rows')) ReceivableInvoiceRow.fromJson(row),
      ],
      next: cursor == null
          ? null
          : (issuedAt: cursor.string('issued_at'), id: cursor.string('id')),
    );
  }

  final List<ReceivableInvoiceRow> rows;
  final ReceivablesCursor? next;
}

/// The server's read of one business's receivables.
abstract interface class BusinessReceivablesRepository {
  Future<BusinessReceivables> summary(String workspaceId);

  /// The invoices of one currency, optionally of one state, one page after
  /// [after].
  Future<ReceivablesPage> page(
    String workspaceId,
    String currency, {
    ReceivableState? state,
    ReceivablesCursor? after,
  });
}

/// The server refused: the person may not read this business's receivables
/// (the finance right, or invoicing is off there).
class BusinessReceivablesRefusal implements Exception {
  const BusinessReceivablesRefusal();

  @override
  String toString() => 'BusinessReceivablesRefusal';
}
