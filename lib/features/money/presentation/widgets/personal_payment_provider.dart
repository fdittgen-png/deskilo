// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../profile/domain/personal_preferences.dart';
import '../../../profile/providers/personal_preferences_providers.dart';
import '../../domain/payment_provider.dart';
import '../payment_provider_labels.dart';

/// Saves only the preferred hosted checkout. Cards stay with the provider.
class PersonalPaymentProvider extends ConsumerWidget {
  const PersonalPaymentProvider({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(personalSettingsProvider);
    final l10n = context.l10n;
    final value =
        preferences.value?.defaults[PersonalPreference.paymentProvider] ?? '';
    return Padding(
      padding: AppSpacing.mdAll,
      child: DropdownButtonFormField<String>(
        key: ValueKey('personal-payment-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText:
              l10n.accountPaymentPreference,
        ),
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(l10n.accountPaymentAsk),
          ),
          for (final provider in PaymentProvider.values)
            DropdownMenuItem(
              value: provider.wireName,
              child: Text(paymentProviderLabel(l10n, provider)),
            ),
        ],
        onChanged: preferences.hasValue
            ? (selected) {
                if (selected == null) return;
                unawaited(runGuarded(
                  context,
                  domain: 'payments',
                  message: 'save preferred payment provider failed',
                  errorText:
                      l10n.preferencesSaveFailed,
                  action: () =>
                      ref.read(personalSettingsProvider.notifier).save({
                        PersonalPreference.paymentProvider: selected,
                      }, workspaceOnly: false),
                ));
              }
            : null,
      ),
    );
  }
}
