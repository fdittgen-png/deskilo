// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The dunning policy is written as one value: levels, the two delays and
// whether the daily sweep applies them by itself. The reminder rules
// dialog and the setup guide's reminders step save through this one class;
// the server keeps the first delay's setting in step with it.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/dunning.dart';
import '../domain/money_repository.dart';
import '../providers/money_providers.dart';

part 'save_dunning_rules.g.dart';

class SaveDunningRules {
  const SaveDunningRules(this._repository);
  final MoneyRepository _repository;

  /// Stores [rules] as [workspaceId]'s policy. Throws whatever the
  /// repository throws.
  Future<void> save(String workspaceId, DunningRules rules) =>
      _repository.setDunningRules(workspaceId, rules);
}

/// The dunning policy's one write.
@riverpod
SaveDunningRules saveDunningRules(Ref ref) =>
    SaveDunningRules(ref.watch(moneyRepositoryProvider));
