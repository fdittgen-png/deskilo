// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/traced.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import 'money_providers.dart';

part 'billing_invoice_sweep.g.dart';

/// #816 — the client-side clock for the billing cycle (#802): the first
/// issuer who opens Finances in a session runs `sweep_billing_invoices`
/// for the workspace, exactly as the reminder sweep runs (#726). The
/// sweep is idempotent (one invoice per member and month), so it costs
/// nothing when the cron already ran — and a workspace without pg_cron
/// still gets its subscription and usage invoices.
@Riverpod(keepAlive: true)
Future<int> billingInvoiceSweep(Ref ref, String workspaceId) async {
  final features = ref.read(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.invoicing) ||
      !(features.contains(WorkspaceFeature.subscriptionInvoices) ||
          features.contains(WorkspaceFeature.usageInvoices))) {
    return 0;
  }
  final me = ref.read(myMemberProvider).value;
  if (me == null || !(me.isAdmin || me.isOwner)) return 0;
  return traced(
    'money',
    'sweep billing invoices',
    () => ref.read(moneyRepositoryProvider).sweepBillingInvoices(workspaceId),
  );
}
