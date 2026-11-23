// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/app_floor.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/sign_out.dart';

/// #3726 — the installation this device uses accepts only newer apps.
///
/// Every route but the way out collapses onto this one while that is true:
/// the Server screen, the help, the privacy page and the Demo stay open, and
/// this screen offers signing out. It says what happened and the way to
/// update on this platform.
///
/// No feature flag, for the reason the Server screen has none: the flags
/// live on the installation this screen says this app cannot use.
class AppUpdateScreen extends ConsumerWidget {
  const AppUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final signedIn = ref.watch(authStateProvider).value != null;
    final how = kIsWeb
        ? l10n.appUpdateWeb
        : switch (defaultTargetPlatform) {
            TargetPlatform.android || TargetPlatform.iOS => l10n.appUpdateStore,
            _ => l10n.appUpdateDesktop,
          };
    return Scaffold(
      key: const ValueKey('app-update'),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.gutterAll,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(
              Icons.system_update_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                l10n.appUpdateTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.appUpdateBody, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            Text(
              how,
              key: const ValueKey('app-update-how'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('app-update-retry'),
              onPressed: () => ref.invalidate(appFloorProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.invoiceIssueCheckAgain),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('app-update-server'),
              onPressed: () => context.push('/server'),
              icon: const Icon(Icons.dns_outlined),
              label: Text(l10n.schemaUpdateServer),
            ),
            if (signedIn) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                key: const ValueKey('app-update-sign-out'),
                onPressed: () => signOutAndForget(ref),
                icon: const Icon(Icons.logout),
                label: Text(l10n.authSignOut),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
