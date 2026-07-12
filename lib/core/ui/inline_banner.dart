// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Visual weight of an [InlineBanner].
enum InlineBannerSeverity {
  /// Something below is unavailable/rejected — `errorContainer` colors.
  error,

  /// Neutral context note — muted `surfaceContainerHighest` colors.
  info,
}

/// Layout constants of [InlineBanner] — pinned by test, not free-floating
/// magic numbers.
abstract final class InlineBannerMetrics {
  /// Size of the leading icon.
  static const double iconSize = 18;
}

/// Full-width inline banner under a screen's header (#210): the #186
/// closed-day banner generalized. An icon plus one line of text on a
/// tinted, rounded container.
///
/// Callers pass their EXISTING localized string as [text] — this widget
/// introduces no text of its own.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.icon,
    required this.text,
    this.severity = InlineBannerSeverity.error,
  });

  /// Leading context icon.
  final IconData icon;

  /// The site's localized banner message.
  final String text;

  /// Color treatment; defaults to [InlineBannerSeverity.error].
  final InlineBannerSeverity severity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (severity) {
      InlineBannerSeverity.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      InlineBannerSeverity.info => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(icon, size: InlineBannerMetrics.iconSize, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
