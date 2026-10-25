// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import 'finance_overview.dart';

/// Account RPC projection. It contains neither operator stamps nor other
/// members' data. Currency belongs to each record; pages are never summed.
enum AccountActivityKind { invoices, payments, usage }

typedef ActivityCursor = ({DateTime at, String id});

/// The rows `my_financial_activity` answers per page (its `limit 50`): a
/// shorter page is the last one. Not a choice; the RPC fixes it.
const int activityPageSize = 50;

/// Every row [page] answers, page after page by the keyset cursor, until a
/// page is shorter than [activityPageSize] (or the cursor stops moving, so
/// a host that repeats its last page cannot hold the reader forever). A
/// failed page fails the whole read: an export is never silently short.
Future<List<AccountActivity>> everyActivityPage(
  Future<List<AccountActivity>> Function(ActivityCursor? before) page,
) async {
  final all = <AccountActivity>[];
  ActivityCursor? before;
  while (true) {
    final rows = await page(before);
    // The same page again: nothing new is coming.
    if (before != null && rows.isNotEmpty && rows.last.cursor == before) {
      return all;
    }
    all.addAll(rows);
    if (rows.length < activityPageSize) return all;
    before = rows.last.cursor;
  }
}

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
