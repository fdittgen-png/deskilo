// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Whether an approval rule can ever be satisfied. The people who can
// decide under a rule are counted the way the server counts them when it
// calls a rule short (`workspace_readiness`, 0399), among the active
// members: every owner; under the 'members' scope every one of them;
// under 'listed' the listed persons; under 'admins' the administrators
// when the rule admits them, all of them or only the listed ones. Any
// other scope admits the owners alone. A rule asking for more approvals
// than that holds its requests forever.
import 'validation_policy.dart';

/// One active member, as far as deciding goes.
typedef Decider = ({String id, bool isOwner, bool isAdmin});

/// How many of the active members [people] can decide a request under
/// [policy].
int decidersUnder(ValidationPolicy policy, Iterable<Decider> people) => people
    .where(
      (m) =>
          m.isOwner ||
          switch (policy.validatorScope) {
            'members' => true,
            'listed' => policy.eligibleAdminIds.contains(m.id),
            'admins' =>
              m.isAdmin &&
                  policy.adminsMayValidate &&
                  (policy.eligibleAdminIds.isEmpty ||
                      policy.eligibleAdminIds.contains(m.id)),
            _ => false,
          },
    )
    .length;

/// Whether [policy] asks for more approvals than [people] can give.
bool ruleIsShort(ValidationPolicy policy, Iterable<Decider> people) =>
    policy.requiredCount > decidersUnder(policy, people);
