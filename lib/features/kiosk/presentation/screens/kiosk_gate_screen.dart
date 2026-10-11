// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/kiosk_mode.dart';

/// The kiosk gate: a kiosk account lands here on every app start and
/// chooses — start kiosk mode (locked until the pad restarts) or open
/// the app normally this once. The router redirects on the decision.
class KioskGateScreen extends ConsumerWidget {
  const KioskGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: AppSpacing.lgAll,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.tablet_mac_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.kioskGateTitle,
                    key: const ValueKey('kiosk-gate-title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    workspace?.name ?? '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.kioskGateBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    key: const ValueKey('kiosk-gate-start'),
                    onPressed: () =>
                        ref.read(kioskModeProvider.notifier).accept(),
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      l10n.kioskGateStart,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    key: const ValueKey('kiosk-gate-reject'),
                    onPressed: () =>
                        ref.read(kioskModeProvider.notifier).reject(),
                    child: Text(
                      l10n.kioskGateReject,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
