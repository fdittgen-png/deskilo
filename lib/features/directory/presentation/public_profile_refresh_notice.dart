// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/async_read_body.dart';
import '../../../core/ui/kit/kit_card.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';

/// A retained card is never presented as a successful fresh source read.
class PublicProfileRefreshNotice extends ConsumerWidget {
  const PublicProfileRefreshNotice({
    super.key,
    required this.workspace,
    required this.state,
  });
  final PublicWorkspace workspace;
  final AsyncValue<PublicWorkspace?>? state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = state;
    // #4414 kept: shown only while a refresh runs or failed (the banner below)
    if (current == null || (!current.isLoading && !current.hasError)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    void retry() => ref.invalidate(
      publicWorkspaceDetailProvider(
        workspace.source,
        workspace.key,
        workspace.id,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: current.isLoading
          ? KitCard(
              key: const ValueKey('public-profile-refresh-notice'),
              child: Semantics(
                liveRegion: true,
                child: Text(l.publicProfileRefreshing),
              ),
            )
          : ReadFailureBanner(
              error: current.error!,
              retryKey: const ValueKey('public-profile-retry'),
              onRetry: retry,
            ),
    );
  }
}
