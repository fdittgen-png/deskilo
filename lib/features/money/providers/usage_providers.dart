// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/traced.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/usage_record.dart';
import 'money_providers.dart';

part 'usage_providers.g.dart';

/// #833 — which month the Usage face is showing, and whose records.
/// A member only ever sees their own, so the id is ignored for them by
/// the server; an issuer uses it to narrow to one person.
@riverpod
class UsageFilter extends _$UsageFilter {
  @override
  ({String? period, String? memberId}) build() =>
      (period: null, memberId: null);

  void showPeriod(String? period) =>
      state = (period: period, memberId: state.memberId);

  void showMember(String? memberId) =>
      state = (period: state.period, memberId: memberId);
}

/// One month of usage records. The server backfills the month's
/// no-shows before answering, so reading a month is what makes its
/// uncounted bookings appear — there is no cron behind this.
@riverpod
Future<List<UsageRecord>> usageRecords(Ref ref, String period) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null || period.isEmpty) return const [];
  final memberId = ref.watch(usageFilterProvider).memberId;
  return traced(
    'money',
    'usage records',
    () => ref.read(moneyRepositoryProvider).fetchUsageRecords(
          workspaceId: workspace.id,
          period: period,
          memberId: memberId,
        ),
  );
}
