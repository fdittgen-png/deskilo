// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/usage_record.dart';

/// #2590 — the demo's usage is always prepared: there is nothing left to
/// record.
class FakeUsagePreparation implements UsagePreparation {
  const FakeUsagePreparation();

  @override
  Future<int> prepare(String workspaceId, String period, String requestId) async =>
      0;
}
