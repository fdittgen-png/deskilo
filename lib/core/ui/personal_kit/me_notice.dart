// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the one-line partial-failure banner with its Retry: a
// source that failed is said here, beside the results that loaded.
import 'package:flutter/material.dart';

import '../../theme/personal_theme.dart';
import 'me_kit_metrics.dart';

class MeNotice extends StatelessWidget {
  const MeNotice({
    super.key,
    required this.text,
    required this.retryLabel,
    required this.onRetry,
  });

  final String text;

  /// The words of the Retry action.
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.warningTint,
        borderRadius: PersonalShellMetrics.controlRadiusAll,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: MeKitMetrics.gap),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: tokens.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.text),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('me-notice-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, MeKitMetrics.minTarget),
                foregroundColor: tokens.primary,
              ),
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
