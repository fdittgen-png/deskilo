// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/dunning_repository.dart';

import '../money_repository.dart';

/// #2591 — the demo's dunning policy, its sweep and the holds, answered
/// from one space's in-memory money store ([FakeMoneyRepository]); every other
/// port of that space reads and writes the same store.
class DemoDunning implements DunningRepository {
  DemoDunning(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<DunningRules> fetchDunningRules(String workspaceId) async =>
      _m.dunningRules;

  @override
  Future<Map<String, String>> fetchDunningHolds(String workspaceId) async =>
      Map.of(_m.dunningHolds);

  @override
  Future<void> setDunningRules(String workspaceId, DunningRules rules) async {
    _m.dunningRules = rules;
  }

  @override
  Future<int> sweepPaymentReminders(String workspaceId) async {
    _m.sweeps++;
    return 0;
  }

  @override
  Future<void> placeDunningHold(
    String invoiceId, {
    required String reason,
    String note = '',
  }) async {
    if (_m.dunningHolds.containsKey(invoiceId)) {
      throw StateError('this invoice is already on hold');
    }
    _m.dunningHolds[invoiceId] = reason;
  }

  @override
  Future<void> releaseDunningHold(String invoiceId) async {
    if (_m.dunningHolds.remove(invoiceId) == null) {
      throw StateError('this invoice is not on hold');
    }
  }
}
