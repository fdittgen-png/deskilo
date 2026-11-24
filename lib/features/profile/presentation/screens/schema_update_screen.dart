// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/installation_schema.dart';
import '../../../../core/backend/schema_version.dart';
import '../../../../core/instance/schema_compatibility.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_spacing.dart';

/// #1312 — the server this device uses runs an older DesKilo schema than
/// this app needs.
///
/// Every route but the Server screen, the help and the privacy page
/// collapses onto this one while that is true. A newer app on an older
/// schema is not supported (OPERATIONS.md § Version compatibility), and
/// letting the member in means the first screen reading a missing column
/// fails with a message that explains nothing.
///
/// Two readers, one screen: whoever runs the server is told what to run,
/// everybody else who to ask — and both may point this device elsewhere.
///
/// No feature flag, for the reason the Server screen has none: the flags
/// live on the server this screen says cannot be used yet.
class SchemaUpdateScreen extends ConsumerWidget {
  const SchemaUpdateScreen({super.key, this.signedIn = false, this.onSignOut});

  /// Whether someone is signed in: the account's own exits are offered only then.
  final bool signedIn;

  /// Signs out and forgets the account; the app composes it, so this screen needs no auth import.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = l10n.schemaUpdateTitle;
    // What the app cannot work without, not what it was built against: an
    // older but sufficient server is never sent here.
    final body = l10n.schemaUpdateBody(appNeedsSchemaVersion);
    final operator = l10n.schemaUpdateOperator;
    final member = l10n.schemaUpdateMember;
    // #3729 — what the installation hosting the workspace reports, and the
    // migrations it lacks, for whoever runs it. Only when it answered.
    final hosted = ref.watch(installationSchemaMemoryProvider).lastBehind;
    final running = hosted != null && hosted.answered && hosted.number != null
        ? hosted.number
        : null;
    // Only one business's installation is old when the personal one is not:
    // the account and its other businesses stay open, so the screen leads
    // back to Me.
    final onlyThisHost =
        ref.watch(schemaCompatibilityProvider).value !=
        SchemaCompatibility.behind;
    return Scaffold(
      key: const ValueKey('schema-update'),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.gutterAll,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(Icons.system_update_alt_outlined,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(body, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            if (running != null && running < appNeedsSchemaVersion) ...[
              Text(
                l10n.schemaUpdateRunning(
                  '$running',
                  '${running + 1}',
                  '$appNeedsSchemaVersion',
                ),
                key: const ValueKey('schema-update-missing'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(operator, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(member, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('schema-update-retry'),
              onPressed: () {
                ref
                  ..invalidate(schemaCompatibilityProvider)
                  ..invalidate(workspaceSchemaProvider);
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.invoiceIssueCheckAgain),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('schema-update-server'),
              onPressed: () => context.push(Routes.server),
              icon: const Icon(Icons.dns_outlined),
              label: Text(l10n.schemaUpdateServer),
            ),
            if (signedIn && onlyThisHost) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('schema-update-me'),
                onPressed: () => context.go(Routes.me),
                icon: const Icon(Icons.switch_account_outlined),
                label: Text(l10n.spaceBackToMe),
              ),
            ],
            if (signedIn && onSignOut != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                key: const ValueKey('schema-update-sign-out'),
                onPressed: onSignOut,
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
