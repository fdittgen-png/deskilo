// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 -- what a widget that failed to build shows in a release build: one
// worded tile instead of the framework's grey box. The failure itself is
// traced once by `installGlobalTraceHooks` (`FlutterError.onError` runs
// before the framework asks for this widget), so this tile only shows it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';
import '../theme/app_spacing.dart';

/// A part of a screen that could not be shown, in words.
class _FailedPartTile extends StatelessWidget {
  const _FailedPartTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.failedPartNotShown,
                key: const ValueKey('failed-part'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the framework's error box with the worded tile in a release
/// build ([release]); a debug build keeps the framework's box, which names
/// the fault for whoever is developing.
void installFailedPartTile({bool release = kReleaseMode}) {
  if (!release) return;
  ErrorWidget.builder = (_) => const _FailedPartTile();
}
