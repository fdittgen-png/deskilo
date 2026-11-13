// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../data/unreadable_rows.dart';
import '../l10n/context_l10n.dart';
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
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null),
            'an action needs both a label and a handler');

  /// Leading context icon.
  final IconData icon;

  /// The site's localized banner message.
  final String text;

  /// Color treatment; defaults to [InlineBannerSeverity.error].
  final InlineBannerSeverity severity;

  /// #1196 — the way forward, when the banner knows one. A banner that
  /// states a fact and offers nothing leaves the reader to work out the
  /// next move; the closed-day banner knew the next open day all along
  /// and made the member find it by hand.
  final String? actionLabel;
  final VoidCallback? onAction;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: InlineBannerMetrics.iconSize, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(text, style: TextStyle(color: foreground)),
              ),
            ],
          ),
          // The action gets its own row, as Material's own `MaterialBanner`
          // gives its actions one. Beside the text it overflowed the
          // banner by 72 px on a 360 dp phone — the sentence and a
          // button naming a date do not share a line on a narrow
          // screen, in any of the five languages.
          if (onAction != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('inline-banner-action'),
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(actionLabel!),
              ),
            ),
        ],
      ),
    );
  }
}

/// #3884 -- the one line under a list that says rows were left out because
/// this version of the app cannot read them. Nothing when none were.
class UnreadableRowsNotice extends StatelessWidget {
  const UnreadableRowsNotice({super.key, required this.areas});

  /// One list's area, as its reader recorded it in `UnreadableRows`.
  UnreadableRowsNotice.area(String area, {Key? key})
      : this(key: key, areas: [area]);

  /// The areas whose left-out rows this line counts together.
  final List<String> areas;

  @override
  Widget build(BuildContext context) {
    final listenables = [
      for (final a in areas) UnreadableRows.instance.watch(a),
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final count = areas.fold(
          0,
          (sum, a) => sum + UnreadableRows.instance.count(a),
        );
        return count == 0
            ? const SizedBox.shrink()
            : InlineBanner(
                key: const ValueKey('unreadable-rows-notice'),
                icon: Icons.visibility_off_outlined,
                severity: InlineBannerSeverity.info,
                text: context.l10n.unreadableRowsNotice(count),
              );
      },
    );
  }
}
