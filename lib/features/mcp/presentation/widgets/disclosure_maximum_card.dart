// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../providers/eligibility_review_form_provider.dart';
import '../../providers/mcp_providers.dart';
import '../mcp_operation_labels.dart';

/// #1809 — the installation maximum of optional fields; reading it needs
/// the second factor ([onUnlock]), saving it too ([onSave]).
class DisclosureMaximumCard extends ConsumerWidget {
  const DisclosureMaximumCard({
    super.key,
    required this.onUnlock,
    required this.onSave,
  });

  final VoidCallback onUnlock;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(mcpDisclosureMaximumProvider);
    final form = ref.watch(eligibilityReviewFormProvider);
    final notifier = ref.read(eligibilityReviewFormProvider.notifier);
    return Card(
      key: const ValueKey('mcp-maximum'),
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.mcpDisclosureTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.mcpDisclosureMaximumExplain),
            if (form.maximumOutcome != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: InlineBanner(
                  key: ValueKey('mcp-maximum-outcome-${form.maximumOutcome}'),
                  icon: Icons.info_outline,
                  severity: form.maximumOutcome == 'saved'
                      ? InlineBannerSeverity.info
                      : InlineBannerSeverity.error,
                  text: form.maximumOutcome == 'saved'
                      ? (l10n.mcpDisclosureMaximumSaved)
                      : (l10n.mcpDisclosureMaximumRefused),
                ),
              ),
            ...state.when(
              loading: () => const [LoadingView()],
              error: (e, _) => [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.mcpDisclosureMaximumLocked,
                  key: const ValueKey('mcp-maximum-locked'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const ValueKey('mcp-maximum-unlock'),
                  onPressed: form.busy ? null : onUnlock,
                  child: Text(l10n.mcpDisclosureUnlock),
                ),
              ],
              data: (m) {
                final draft = notifier.maximumFor(m);
                return [
                  for (final field in m.available)
                    CheckboxListTile(
                      key: ValueKey('mcp-maximum-field-$field'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: draft.contains(field),
                      title: Text(mcpOptionalFieldLabel(l10n, field)),
                      onChanged: form.busy
                          ? null
                          : (on) => notifier.toggleMaximumField(
                              m,
                              field,
                              on: on ?? false,
                            ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('mcp-maximum-save'),
                    onPressed: form.busy ? null : onSave,
                    child: Text(l10n.mcpDisclosureMaximumSave),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
