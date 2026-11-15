// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3470 — saves the business's accounting journals: the four journals, or
// none when they are the country add-on's own (the business keeps the
// defaults, and a later change of the defaults reaches it).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/domain/workspace_identity_repository.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/fec_accounts.dart';

class SaveAccountingJournals {
  const SaveAccountingJournals(this._repository);

  final WorkspaceIdentityRepository _repository;

  /// Keeps [journals] for [workspaceId]; the add-on's own are kept as none.
  /// Throws [AccountingJournalsRefused] when the server refuses them.
  Future<void> save(String workspaceId, FecJournals journals) =>
      _repository.setAccountingJournals(
        workspaceId,
        journals == FecJournals.installed() ? const {} : journals.toJson(),
      );
}

final saveAccountingJournalsProvider = Provider<SaveAccountingJournals>(
  (ref) => SaveAccountingJournals(ref.watch(workspaceRepositoryProvider)),
);
