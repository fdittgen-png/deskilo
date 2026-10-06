// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/account_activity.dart';
import '../../../features/money/domain/finance_overview.dart';

class FakeAccountActivityRepository implements AccountActivityRepository {
  final records = <AccountActivityKind, List<AccountActivity>>{};
  bool unavailable = false;
  FinanceOverview financeOverview = const FinanceOverview();

  @override
  Future<FinanceOverview> overview() async {
    if (unavailable) throw StateError('financial overview unavailable');
    return financeOverview;
  }

  @override
  Future<List<AccountActivity>> list(
    AccountActivityKind kind, {
    ActivityCursor? before,
  }) async {
    if (unavailable) throw StateError('financial history unavailable');
    final rows = [...?records[kind]]
      ..sort((a, b) {
        final time = b.occurredAt.compareTo(a.occurredAt);
        return time != 0 ? time : b.id.compareTo(a.id);
      });
    return rows
        .where(
          (row) =>
              before == null ||
              row.occurredAt.isBefore(before.at) ||
              (row.occurredAt == before.at && row.id.compareTo(before.id) < 0),
        )
        .take(50)
        .toList();
  }
}
