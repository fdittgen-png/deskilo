// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/vies_check.dart';
import '../../../features/money/domain/vies_repository.dart';
import 'fixture_clock.dart';

/// #2354 — VIES checks in memory. Demo never reaches VIES, so a check it
/// is asked to make is an honest outage, never an invented "valid".
class FakeViesRepository implements ViesRepository {
  /// memberId → the last check; tests seed it.
  final Map<String, ViesCheck> checks = {};

  @override
  Future<ViesCheck> fetchViesCheck(String memberId) async =>
      checks[memberId] ?? ViesCheck.none;

  @override
  Future<ViesCheck> checkVies(String workspaceId, String memberId) async =>
      checks[memberId] = ViesCheck(
        vatId: checks[memberId]?.vatId ?? '',
        status: ViesStatus.unavailable,
        checkedAt: kTestNow,
        detail: 'demo',
      );
}
