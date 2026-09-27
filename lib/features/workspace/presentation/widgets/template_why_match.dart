// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/template_capabilities.dart';
import '../../domain/template_inspection.dart';
import '../capability_labels.dart';
import '../screens/template_compare_screen.dart';

/// A capability state in words: never only a colour or a tick.
String capabilityStateLabel(AppLocalizations? l10n, CapabilityState s) =>
    switch (s) {
      CapabilityState.enabled => l10n?.capabilityStateEnabled ?? 'On',
      CapabilityState.disabled => l10n?.capabilityStateDisabled ?? 'Off',
      CapabilityState.conditional =>
        l10n?.capabilityStateConditional ?? 'On only if its prerequisites are',
      CapabilityState.unspecified =>
        l10n?.capabilityStateUnspecified ?? 'Not set by this template',
      CapabilityState.localInputRequired =>
        l10n?.capabilityStateLocalInput ?? 'Needs a local value first',
      CapabilityState.incompatible =>
        l10n?.capabilityStateIncompatible ?? 'Cannot apply here',
      CapabilityState.unknown => l10n?.capabilityStateUnknown ?? 'Unknown',
    };

/// #1660 — "Why this matches": for each capability the search asked
/// for, what THIS template says (its state, and the value behind it),
/// collapsed until asked. It explains; it never ranks, stars or
/// promises, and an unmet requirement reads as unmet.
class TemplateWhyMatch extends StatefulWidget {
  const TemplateWhyMatch({
    super.key,
    required this.templateKey,
    required this.evidence,
  });

  final String templateKey;
  final Map<String, CapabilityEvidence> evidence;

  @override
  State<TemplateWhyMatch> createState() => _TemplateWhyMatchState();
}

class _TemplateWhyMatchState extends State<TemplateWhyMatch> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            key: ValueKey('template-why-${widget.templateKey}'),
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _open
                  ? (l10n?.templateWhyHide ?? 'Hide why')
                  : (l10n?.templateWhy ?? 'Why this matches'),
            ),
            onPressed: () => setState(() => _open = !_open),
          ),
          if (_open)
            for (final e in widget.evidence.entries)
              Padding(
                key: ValueKey('template-why-${widget.templateKey}-${e.key}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      e.value.state.satisfies
                          ? Icons.check_circle_outline
                          : Icons.remove_circle_outline,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        [
                          capabilityLabel(l10n, e.key),
                          capabilityStateLabel(l10n, e.value.state),
                          if (e.value.path != null &&
                              e.value.state != CapabilityState.unspecified)
                            comparisonCellText(
                              l10n,
                              ComparisonCell(
                                value: e.value.value,
                                disposition: TemplateFieldDisposition.present,
                              ),
                            ),
                        ].join(' · '),
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
