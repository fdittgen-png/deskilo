// SPDX-License-Identifier: AGPL-3.0-or-later
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

/// #2590 — one month of usage as a PURE read, with how complete it is: it
/// records nothing, and a month nobody has recorded reads as incomplete.
@riverpod
Future<UsageRead> usageRead(Ref ref, String period) async {
  final memberId = ref.watch(usageFilterProvider).memberId;
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null || period.isEmpty) return const UsageRead(records: []);
  return traced(
    'money',
    'usage read',
    () => ref.read(memberAccountQueriesProvider).readUsageRecords(
          workspaceId: workspace.id,
          period: period,
          memberId: memberId,
        ),
  );
}
