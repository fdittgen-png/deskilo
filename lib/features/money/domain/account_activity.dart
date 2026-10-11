// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import 'finance_overview.dart';

/// Account RPC projection. It contains neither operator stamps nor other
/// members' data. Currency belongs to each record; pages are never summed.
enum AccountActivityKind { invoices, payments, usage }

typedef ActivityCursor = ({DateTime at, String id});

class AccountActivity {
  const AccountActivity({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.occurredAt,
    required this.reference,
    required this.description,
    required this.currency,
    required this.status,
    this.amountCents,
    this.minutes,
  });
  final String id,
      workspaceId,
      workspaceName,
      reference,
      description,
      currency,
      status;
  final DateTime occurredAt;
  final int? amountCents, minutes;
  ActivityCursor get cursor => (at: occurredAt, id: id);

  /// #2387 — read through [JsonReader]; the context names the RPC.
  factory AccountActivity.fromJson(Map<String, dynamic> row) {
    final r = JsonReader(row, context: 'my_financial_activity');
    return AccountActivity(
      id: r.string('id'),
      workspaceId: r.string('workspace_id'),
      workspaceName: r.string('workspace_name'),
      occurredAt: r.dateTime('occurred_at'),
      reference: r.stringOr('reference'),
      description: r.stringOr('description'),
      currency: r.string('currency'),
      status: r.string('status'),
      amountCents: r.intOrNull('amount_cents'),
      minutes: r.intOrNull('minutes'),
    );
  }
}

abstract interface class AccountActivityRepository {
  /// Me › Finances: my invoices (outstanding and paid) and reminders across
  /// every workspace I belong to (0380).
  Future<FinanceOverview> overview();

  Future<List<AccountActivity>> list(
    AccountActivityKind kind, {
    ActivityCursor? before,
  });
}
