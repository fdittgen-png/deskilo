// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Every Grow step's feature requires invoicing, so without it the server
// lists none of them (`feature_effective`): the guide says what that means
// and where the choice is made. Nothing while invoicing is on.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

class SetupNoInvoicingBanner extends ConsumerWidget {
  const SetupNoInvoicingBanner({super.key, required this.reload});

  /// Reads the guide again after the levels screen.
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    if (features.contains(WorkspaceFeature.invoicing)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return InlineBanner(
      key: const ValueKey('setup-guide-no-invoicing'),
      icon: Icons.receipt_long_outlined,
      severity: InlineBannerSeverity.info,
      // Statements when money is kept at all; otherwise nothing is owed.
      text: l10n.setupGuideNoInvoicing(
        features.contains(WorkspaceFeature.moneyTab) ? 'statements' : 'none',
      ),
      actionLabel: l10n.setupGuideLevelsLink,
      onAction: () async {
        await context.push('/setup/levels');
        await reload();
      },
    );
  }
}
