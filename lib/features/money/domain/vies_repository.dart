// SPDX-License-Identifier: AGPL-3.0-or-later
import 'vies_check.dart';

/// #2354 — where VIES checks of members' VAT numbers are read and made.
abstract interface class ViesRepository {
  /// The last check of [memberId]'s VAT number (`members.vies_*`).
  Future<ViesCheck> fetchViesCheck(String memberId);

  /// Asks VIES now (edge function `vies-check`) and returns what was
  /// recorded. An outage comes back as [ViesStatus.unavailable].
  Future<ViesCheck> checkVies(String workspaceId, String memberId);
}
