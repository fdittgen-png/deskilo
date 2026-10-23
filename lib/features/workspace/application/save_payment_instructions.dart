// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The payment instructions members read on an unpaid statement, written
// whole (the server keeps no field-by-field history of them). The payment
// methods screen and the setup guide's step save through this one class,
// then read the workspace row again, because the instructions live on it.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/payment_instructions.dart';
import '../domain/workspace_identity_repository.dart';
import '../providers/workspace_providers.dart';

part 'save_payment_instructions.g.dart';

class SavePaymentInstructions {
  const SavePaymentInstructions(this._repository);
  final WorkspaceIdentityRepository _repository;

  /// Replaces [workspaceId]'s instructions with [instructions]. Throws
  /// whatever the repository throws.
  Future<void> save(String workspaceId, PaymentInstructions instructions) =>
      _repository.setPaymentInstructions(workspaceId, instructions);
}

/// The payment instructions' one write.
@riverpod
SavePaymentInstructions savePaymentInstructions(Ref ref) =>
    SavePaymentInstructions(ref.watch(workspaceRepositoryProvider));
