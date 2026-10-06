// SPDX-License-Identifier: AGPL-3.0-or-later
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

  factory AccountActivity.fromJson(Map<String, dynamic> row) => AccountActivity(
    id: row['id'] as String,
    workspaceId: row['workspace_id'] as String,
    workspaceName: row['workspace_name'] as String,
    occurredAt: DateTime.parse(row['occurred_at'] as String),
    reference: row['reference'] as String? ?? '',
    description: row['description'] as String? ?? '',
    currency: row['currency'] as String,
    status: row['status'] as String,
    amountCents: row['amount_cents'] as int?,
    minutes: row['minutes'] as int?,
  );
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
