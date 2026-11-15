// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0, #3674 -- the one-line partial-failure notice with its Retry:
// a source that failed is said here, beside the results that loaded. The
// warning pair is the status chip's.
import 'package:flutter/material.dart';

import '../../theme/personal_theme.dart';
import 'kit_metrics.dart';
import 'status_chip.dart';

class RetryNotice extends StatelessWidget {
  const RetryNotice({
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (tint, mark) = statusColorsOf(
      PersonalTheme.of(context),
      StatusTone.warn,
      scheme: scheme,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: PersonalShellMetrics.controlRadiusAll,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: KitMetrics.gap),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: mark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('retry-notice-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, KitMetrics.minTarget),
                foregroundColor: scheme.primary,
              ),
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
