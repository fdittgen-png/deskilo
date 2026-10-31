// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../providers/badge_security_providers.dart';

/// An administrator sees unverifiable or short historical PINs as needing
/// a refresh, while a failed lookup never claims the credential is current.
class BadgePinReviewNotice extends ConsumerWidget {
  const BadgePinReviewNotice({
    required this.workspaceId,
    required this.memberId,
    super.key,
  });

  final String workspaceId;
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(badgePinReviewProvider(workspaceId, memberId));
    return review.when(
      data: (needed) => needed
          ? Text(
              context.l10n.badgePinReviewNotice,
              key: const ValueKey('badge-pin-review-notice'),
            )
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => Text(
        context.l10n.badgePinReviewUnavailable,
        key: const ValueKey('badge-pin-review-unavailable'),
      ),
    );
  }
}
