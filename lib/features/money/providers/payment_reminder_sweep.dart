// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/traced.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import 'money_providers.dart';

part 'payment_reminder_sweep.g.dart';

/// #726 — the client-side clock for automatic payment reminders: the
/// first admin who opens Finances in a session runs the sweep for the
/// workspace. Idempotent (the dunning rules decide what is due), so a
/// second run in the same day records nothing. Kept alive so it runs
/// once per session, not once per rebuild; realtime invalidation of the
/// invoices refreshes what the sweep produced.
@Riverpod(keepAlive: true)
Future<int> paymentReminderSweep(Ref ref, String workspaceId) async {
  final features = ref.read(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.paymentReminders)) return 0;
  final me = ref.read(myMemberProvider).value;
  if (me == null || !(me.isAdmin || me.isOwner)) return 0;
  return traced(
    'money',
    'sweep payment reminders',
    () => ref.read(moneyRepositoryProvider).sweepPaymentReminders(workspaceId),
  );
}
