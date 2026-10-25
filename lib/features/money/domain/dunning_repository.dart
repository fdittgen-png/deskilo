// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dunning.dart';

/// #2591 — the dunning of a workspace: the policy, the sweep that applies it,
/// and the holds that keep an invoice out of it. The server decides who may;
/// reads and writes are named apart.
abstract interface class DunningRepository {
  /// The workspace's dunning policy (#472, 0093); defaults when unset.
  Future<DunningRules> fetchDunningRules(String workspaceId);

  /// #1913 (0331) — invoiceId → the reason of its ACTIVE dunning hold
  /// (`dispute`, `identity_error`, `insolvency`, `other`). A held invoice
  /// is not reminded, by hand or by the sweep.
  Future<Map<String, String>> fetchDunningHolds(String workspaceId);

  /// Owner-only: persist the dunning policy.
  Future<void> setDunningRules(String workspaceId, DunningRules rules);

  /// #726 — apply the dunning rules now (idempotent: the rules decide).
  /// Returns how many reminders were recorded. Admins only.
  Future<int> sweepPaymentReminders(String workspaceId);

  /// #1913 — places a hold (RPC `place_dunning_hold`); only whoever
  /// issues the invoices of the space may.
  Future<void> placeDunningHold(
    String invoiceId, {
    required String reason,
    String note = '',
  });

  /// #1913 — releases the active hold (RPC `release_dunning_hold`).
  Future<void> releaseDunningHold(String invoiceId);
}
