// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C2 — My data › Personal information: the personal part of my data
// as my personal home holds it, with no workspace. It says what the home
// answered (how many conversations, messages and workspaces it names),
// that each workspace's records are not part of it, and offers the very
// answer as a file through the platform's truthful delivery. Its state is
// its own: a home that does not answer, refuses or has no such reader is
// named here, and the finances and reservations views are not touched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_delivery.dart';
import '../../../core/files/file_delivery_notice.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/personal_export.dart';
import '../providers/me_providers.dart';

/// The words for a personal export that did not come.
String _personalExportProblem(AppLocalizations l10n, Object error) =>
    switch (error) {
      PersonalExportRefused(failure: PersonalExportFailure.unsupported) =>
        l10n.meDataPersonalUnsupported,
      PersonalExportRefused(failure: PersonalExportFailure.forbidden) =>
        l10n.meDataPersonalForbidden,
      PersonalExportRefused(failure: PersonalExportFailure.malformed) =>
        l10n.meDataPersonalMalformed,
      _ => l10n.meDataPersonalFailed,
    };

class PersonalDataCard extends ConsumerStatefulWidget {
  const PersonalDataCard({super.key});

  @override
  ConsumerState<PersonalDataCard> createState() => _PersonalDataCardState();
}

class _PersonalDataCardState extends ConsumerState<PersonalDataCard> {
  bool _delivering = false;

  Future<void> _deliver(PersonalExport export) async {
    if (_delivering) return;
    setState(() => _delivering = true);
    final delivery = await deliverFile(
      context,
      ref,
      bytes: export.bytes(),
      fileName: export.fileName,
    );
    if (!mounted) return;
    setState(() => _delivering = false);
    announceFileDelivery(context, delivery, retry: () => _deliver(export));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final answer = ref.watch(personalExportProvider);
    final export = answer.value;
    final Widget state;
    if (answer.isLoading && !answer.hasValue) {
      state = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(
          key: ValueKey('me-data-personal-loading'),
        ),
      );
    } else if (answer.hasError) {
      final error = answer.error!;
      final unsupported =
          error is PersonalExportRefused &&
          error.failure == PersonalExportFailure.unsupported;
      state = Column(
        key: ValueKey(
          unsupported
              ? 'me-data-personal-unavailable'
              : 'me-data-personal-failed',
        ),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _personalExportProblem(l10n, error),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (!unsupported)
            TextButton(
              key: const ValueKey('me-data-personal-retry'),
              onPressed: () => ref.invalidate(personalExportProvider),
              child: Text(l10n.commonRetry),
            ),
        ],
      );
    } else if (export != null) {
      state = Column(
        key: const ValueKey('me-data-personal-loaded'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.meDataPersonalSummary(
              export.conversations,
              export.messages,
              export.workspaces,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('me-data-personal-export'),
              onPressed: _delivering ? null : () => _deliver(export),
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.meDataPersonalExport),
            ),
          ),
        ],
      );
    } else {
      state = const SizedBox.shrink();
    }
    return Card(
      key: const ValueKey('me-data-personal'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.meDataPersonalTitle,
              style: theme.textTheme.titleMedium?.strong,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.meDataPersonalScope,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            state,
          ],
        ),
      ),
    );
  }
}
