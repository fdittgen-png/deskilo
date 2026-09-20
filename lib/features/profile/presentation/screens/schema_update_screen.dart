// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/schema_version.dart';
import '../../../../core/instance/schema_compatibility.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

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
  const SchemaUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = l10n?.schemaUpdateTitle ?? 'This server needs an update';
    final body = l10n?.schemaUpdateBody(requiredSchemaVersion) ??
        'This app needs version $requiredSchemaVersion of the DesKilo '
            'schema, and the server it connects to runs an older one. '
            'Until the server is updated, the app would fail in ways it '
            'could not explain, so it stops here.';
    final operator = l10n?.schemaUpdateOperator ??
        'If you run this server: apply the missing migrations with '
            '`dart run tool/instance.dart install --ref <project>`. Only '
            'what is missing runs.';
    final member = l10n?.schemaUpdateMember ??
        'Otherwise: tell the person who runs your space. Nothing you '
            'entered is lost.';
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
            Text(operator, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(member, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('schema-update-retry'),
              onPressed: () => ref.invalidate(schemaCompatibilityProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n?.schemaUpdateRetry ?? 'Check again'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('schema-update-server'),
              onPressed: () => context.push('/server'),
              icon: const Icon(Icons.dns_outlined),
              label: Text(l10n?.schemaUpdateServer ?? 'Server settings'),
            ),
          ],
        ),
      ),
    );
  }
}
