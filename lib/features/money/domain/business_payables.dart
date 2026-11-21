// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (B) -- what a business has to pay, in the two directions it is read:
// suppliers (the complete `supplier_balances_v1` aggregate) and the members it
// owes an expense back (`member_reimbursements_summary_v1`). Each direction keeps
// its own outcome -- answered, refused or unavailable -- so one successful read
// never certifies another, and a denied or failed read is never a zero. A held
// amount is a part of what remains, never an addition to it. Currencies are rows
// of their own.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import '../../../core/backend/operation_context.dart' show WorkspaceTarget;
import 'supplier_balance.dart';
import 'supplier_payables_page.dart';

/// One currency of what a business owes its members back.
@immutable
class MemberReimbursementRow {
  const MemberReimbursementRow({
    required this.currency,
    required this.remainingCents,
    required this.heldCents,
    required this.obligations,
  });

  factory MemberReimbursementRow.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'member reimbursement');
    return MemberReimbursementRow(
      currency: row.string('currency'),
      remainingCents: row.integer('remaining_cents'),
      heldCents: row.integer('held_cents'),
      obligations: row.integer('obligations'),
    );
  }

  final String currency;
  final int remainingCents;

  /// The part of [remainingCents] on hold: a subset, never an addition.
  final int heldCents;
  final int obligations;
}

/// The complete per-currency aggregate of what a business owes its members.
@immutable
class MemberReimbursements {
  const MemberReimbursements({required this.workspaceId, required this.rows});

  factory MemberReimbursements.fromJson(Object? raw) {
    final result = JsonReader.of(raw, context: 'member_reimbursements_summary_v1');
    return MemberReimbursements(
      workspaceId: result.string('workspace_id'),
      rows: [
        for (final row in result.list('rows')) MemberReimbursementRow.fromJson(row),
      ],
    );
  }

  final String workspaceId;
  final List<MemberReimbursementRow> rows;
}

/// The outcome of one direction's read.
sealed class PayablesSection<T> {
  const PayablesSection();
}

final class PayablesAnswered<T> extends PayablesSection<T> {
  const PayablesAnswered(this.data);

  final T data;
}

/// The person may not read this direction here (no finance or purchases right,
/// or purchasing is off): not a zero.
final class PayablesRefused<T> extends PayablesSection<T> {
  const PayablesRefused();
}

/// The read failed: not a zero either.
final class PayablesUnavailable<T> extends PayablesSection<T> {
  const PayablesUnavailable();
}

/// One business's payables, its two directions side by side.
@immutable
class BusinessPayables {
  const BusinessPayables({
    required this.target,
    required this.name,
    required this.suppliers,
    required this.members,
  });

  final WorkspaceTarget target;
  final String name;
  final PayablesSection<List<SupplierBalance>> suppliers;
  final PayablesSection<MemberReimbursements> members;

  /// Per currency, what the answered directions say; a direction that did not
  /// answer contributes nothing here and is said by its section.
  List<PayablesCurrency> get currencies {
    final byCurrency = <String, PayablesCurrency>{};
    if (suppliers case PayablesAnswered(:final data)) {
      for (final b in data) {
        final was = byCurrency[b.currency] ?? PayablesCurrency(b.currency);
        byCurrency[b.currency] = was.withSuppliers(b.remainingCents, b.heldCents);
      }
    }
    if (members case PayablesAnswered(:final data)) {
      for (final r in data.rows) {
        final was = byCurrency[r.currency] ?? PayablesCurrency(r.currency);
        byCurrency[r.currency] = was.withMembers(r.remainingCents, r.heldCents);
      }
    }
    return [for (final k in byCurrency.keys.toList()..sort()) byCurrency[k]!];
  }
}

/// One currency of a business's payables, the two directions apart.
@immutable
class PayablesCurrency {
  const PayablesCurrency(
    this.currency, {
    this.supplierCents = 0,
    this.supplierHeldCents = 0,
    this.memberCents = 0,
    this.memberHeldCents = 0,
  });

  final String currency;
  final int supplierCents;
  final int supplierHeldCents;
  final int memberCents;
  final int memberHeldCents;

  PayablesCurrency withSuppliers(int cents, int held) => PayablesCurrency(
    currency,
    supplierCents: supplierCents + cents,
    supplierHeldCents: supplierHeldCents + held,
    memberCents: memberCents,
    memberHeldCents: memberHeldCents,
  );

  PayablesCurrency withMembers(int cents, int held) => PayablesCurrency(
    currency,
    supplierCents: supplierCents,
    supplierHeldCents: supplierHeldCents,
    memberCents: memberCents + cents,
    memberHeldCents: memberHeldCents + held,
  );

  /// What the business has to pay in this currency: held is already inside.
  int get totalCents => supplierCents + memberCents;
  int get heldCents => supplierHeldCents + memberHeldCents;
}

/// The server's reads of what a business has to pay.
abstract interface class BusinessPayablesRepository {
  Future<List<SupplierBalance>> supplierBalances(String workspaceId);

  Future<MemberReimbursements> memberReimbursements(String workspaceId);

  /// The obligation rows behind the aggregates, of one currency and optionally
  /// one creditor kind (`supplier` or `member`), one page after [after].
  Future<SupplierPayablesPage> payablesPage(
    String workspaceId,
    String currency, {
    String? creditorKind,
    SupplierPayablesCursor? after,
  });
}

/// The server refused a payables read: the person may not read it.
class BusinessPayablesRefusal implements Exception {
  const BusinessPayablesRefusal();

  @override
  String toString() => 'BusinessPayablesRefusal';
}
