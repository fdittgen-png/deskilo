// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/report_image_failure.dart';

/// #2586 — why a library image is not shown, in words: denied, unavailable
/// or not a usable image. Anything that is not a typed failure reads as
/// unavailable (the read did not complete).
String reportImageReason(AppLocalizations l10n, Object error) =>
    switch (error is ReportImageFailure ? error.kind : null) {
      ReportImageFailureKind.forbidden => l10n.reportImageForbidden,
      ReportImageFailureKind.invalid => l10n.reportImageInvalid,
      _ => l10n.reportImageUnavailable,
    };

/// A read that failed — not an image that was deleted: the image's name,
/// the reason, and a way to retry exactly that read (the caller invalidates
/// its provider). Nothing else is resent.
class ReportImageNotice extends StatelessWidget {
  const ReportImageNotice({
    required this.name,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final String name;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = Theme.of(context).colorScheme.error;
    return Row(
      key: ValueKey('report-image-notice-$name'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 18, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            l10n.reportImageProblem(name, reportImageReason(l10n, error)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
        IconButton(
          key: ValueKey('report-image-retry-$name'),
          tooltip: l10n.reportImageRetry,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: onRetry,
        ),
      ],
    );
  }
}
