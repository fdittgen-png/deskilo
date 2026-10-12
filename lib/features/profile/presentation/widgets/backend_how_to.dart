// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// The four steps, on the screen rather than in a manual: a coworking
/// owner setting this up has the Supabase dashboard open in the other
/// hand.
class BackendHowTo extends ConsumerWidget {
  const BackendHowTo({super.key, required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final featureOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.instanceWizard);
    final steps = [
      l10n.backendStep1,
      l10n.backendStep2,
      l10n.backendStep3,
      l10n.backendStep4,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // #977 — the wizard does the four steps for you.
        if (featureOn)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: FilledButton.icon(
              key: const ValueKey('backend-new-instance'),
              onPressed: () => context.push('/server/new-instance'),
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: Text(l10n.instanceCreateButton),
            ),
          ),
        Card(
      child: ExpansionTile(
        key: const ValueKey('backend-howto'),
        // #1194 — this row carried a help glyph as its LEADING icon and
        // a help dot as its trailing one: two question marks meaning
        // different things, on one line. The leading icon says what the
        // row is ABOUT; the dot beside it is the help.
        leading: const Icon(Icons.dns_outlined),
        title: Row(children: [
          Expanded(
            child: Text(l10n.backendHowTitle),
          ),
          HelpDot(topic,
            anchor: HelpAnchor.backendHow,
          ),
        ]),
        childrenPadding: AppSpacing.mdAll,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    // The step NUMBER — a numeral, not prose: formatted
                    // like every other number in the app.
                    child: Text(
                      NumberFormat.decimalPattern(
                        Localizations.localeOf(context).toString(),
                      ).format(i + 1),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[i])),
                ],
              ),
            ),
        ],
      ),
    ),
      ],
    );
  }
}
