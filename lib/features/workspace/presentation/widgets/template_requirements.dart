// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../capability_labels.dart';

/// #1660 — requirements the person chose explicitly. The search words
/// OFFER a capability ("Require: Credit packs"); only a tap makes it a
/// requirement, which then holds until removed, whatever is typed next.
/// Nothing here changes a template or selects one.
class TemplateRequirementChips extends StatelessWidget {
  const TemplateRequirementChips({
    super.key,
    required this.offered,
    required this.required,
    required this.onRequire,
    required this.onRemove,
    required this.onReset,
    this.preferred = const [],
    this.onPrefer,
  });

  /// Capabilities preferred: they rank the results, never hide one.
  final List<String> preferred;
  final ValueChanged<String>? onPrefer;

  /// Capabilities the current words name that are not required yet.
  final List<String> offered;

  /// Capabilities required, in the order they were chosen.
  final List<String> required;
  final ValueChanged<String> onRequire;
  final ValueChanged<String> onRemove;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (offered.isEmpty && required.isEmpty && preferred.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final id in required)
            InputChip(
              key: ValueKey('template-required-$id'),
              avatar: const Icon(Icons.rule, size: 18),
              label: Text(capabilityLabel(l10n, id)),
              tooltip: l10n?.templateRequirementRemove ?? 'Remove requirement',
              onDeleted: () => onRemove(id),
            ),
          for (final id in preferred)
            InputChip(
              key: ValueKey('template-preferred-$id'),
              avatar: const Icon(Icons.thumb_up_outlined, size: 18),
              label: Text(
                l10n?.templatePreferredChip(capabilityLabel(l10n, id)) ??
                    'Preferred: ${capabilityLabel(l10n, id)}',
              ),
              tooltip: l10n?.templateRequirementRemove ?? 'Remove requirement',
              onDeleted: () => onRemove(id),
            ),
          for (final id in offered)
            if (onPrefer != null)
              ActionChip(
                key: ValueKey('template-prefer-$id'),
                label: Text(
                  l10n?.templatePrefer(capabilityLabel(l10n, id)) ??
                      'Prefer: ${capabilityLabel(l10n, id)}',
                ),
                onPressed: () => onPrefer!(id),
              ),
          for (final id in offered)
            ActionChip(
              key: ValueKey('template-require-$id'),
              avatar: const Icon(Icons.add, size: 18),
              label: Text(
                l10n?.templateRequire(capabilityLabel(l10n, id)) ??
                    'Require: ${capabilityLabel(l10n, id)}',
              ),
              onPressed: () => onRequire(id),
            ),
          if (required.isNotEmpty || preferred.isNotEmpty)
            TextButton(
              key: const ValueKey('template-requirements-reset'),
              onPressed: onReset,
              child: Text(l10n?.templateRequirementsReset ?? 'Reset'),
            ),
        ],
      ),
    );
  }
}
