// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 XPRIV-01 — the private-values mask reads two things core cannot:
// the installation's `personalShell` platform flag, which offers the
// choice at all, and the personal account's own default (never a
// workspace override). Composed here, where both features are.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/privacy/private_values.dart';
import '../features/me/providers/personal_shell_providers.dart';
import '../features/profile/domain/personal_preferences.dart';
import '../features/profile/providers/personal_preferences_providers.dart';

/// Puts the policy in a scope's overrides (main.dart, the demo container).
final Override privateValuesFromAccount = privateValuesPolicyProvider
    .overrideWith(
      (ref) => PrivateValuesPolicy(
        enabled: ref.watch(personalShellEnabledProvider),
        account: ref
            .watch(personalSettingsProvider)
            .value
            ?.defaults[PersonalPreference.privateValues],
      ),
    );
