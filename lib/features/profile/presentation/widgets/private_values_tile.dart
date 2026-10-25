// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 XPRIV-01 — Me › Account: whether private values (amounts on
// compact cards, previews) stay masked until revealed. Saved on this
// device and, when signed in, as the personal account's default — never
// as a workspace override. Nothing is shown without the personal shell.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/privacy/private_values.dart';
import '../../../../core/trace/guarded.dart';
import '../../domain/personal_preferences.dart';
import '../../providers/personal_preferences_providers.dart';
import '../../providers/profile_providers.dart';

class PrivateValuesTile extends ConsumerWidget {
  const PrivateValuesTile({super.key});

  static Future<void> _save(WidgetRef ref, {required bool masked}) async {
    final value = masked
        ? PrivateValuesChoice.masked
        : PrivateValuesChoice.shown;
    final account = ref.read(personalPreferenceContextProvider).account;
    await ref.read(privateValuesDeviceProvider.notifier).set(value);
    if (account == null) return;
    await ref.read(personalSettingsProvider.notifier).save({
      PersonalPreference.privateValues: value,
    }, workspaceOnly: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offered with the personal shell only (the policy's `enabled`).
    if (!ref.watch(privateValuesPolicyProvider).enabled) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return SwitchListTile(
      key: const ValueKey('settings-private-values'),
      secondary: const Icon(Icons.visibility_off_outlined),
      title: Text(l10n.privateValuesTitle),
      subtitle: Text(l10n.privateValuesHint),
      value: ref.watch(privateValuesMaskedProvider),
      onChanged: (masked) => runGuarded(
        context,
        domain: 'profile',
        message: 'private values save failed',
        errorText: l10n.preferencesSaveFailed,
        action: () => _save(ref, masked: masked),
      ),
    );
  }
}
