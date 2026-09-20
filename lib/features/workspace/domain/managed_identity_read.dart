// SPDX-License-Identifier: 0BSD
//
// #1561 — what a managed-identity read ANSWERED.
//
// `managed_identity_of` (0161) refuses when the access rule does not name
// the caller: that refusal is an answer — the admin simply does not see
// the contact details. A dropped connection is not an answer at all.
//
// Both used to arrive as `PersonalInfo.empty`, which the edit form then
// opened on and saved, and `update_managed_identity` replaces the whole
// row. The two states have to be told apart before anything decides
// whether there is something to edit.
library;

import '../../profile/domain/personal_info.dart';

class ManagedIdentityRead {
  /// The rule names the caller; [identity] is what the server holds
  /// (possibly empty, for a profile whose identity was never filled in).
  const ManagedIdentityRead.loaded(this.identity) : refused = false;

  /// The server answered "not you". There is nothing to show and nothing
  /// to save — the same rule gates the write.
  const ManagedIdentityRead.refused()
      : identity = PersonalInfo.empty,
        refused = true;

  final PersonalInfo identity;
  final bool refused;
}
