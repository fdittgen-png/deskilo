// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3684 -- what the map could not do, said in a line, never a silent grey
// area or a missing pin: the background that did not load, the places
// that have no pin and why, and nothing to pin at all.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// One line over or above the map, with its Try again when there is
/// something to try again.
class DirectoryMapNotice extends StatelessWidget {
  const DirectoryMapNotice({
    super.key,
    required this.icon,
    required this.lines,
    this.onRetry,
    this.retryKey,
    this.elevated = false,
  });

  final IconData icon;

  /// The sentences, each with its own key so a test reads one of them.
  final List<(ValueKey<String>, String)> lines;
  final VoidCallback? onRetry;
  final ValueKey<String>? retryKey;

  /// Over the map: a raised surface, so it reads on any background.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (key, text) in lines)
                    Text(text, key: key, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (onRetry case final retry?)
            TextButton(
              key: retryKey,
              onPressed: retry,
              child: Text(context.l10n.commonRetry),
            ),
        ],
      ),
    );
    if (!elevated) return row;
    return Material(
      elevation: 2,
      borderRadius: AppRadius.mdAll,
      color: theme.colorScheme.surface,
      child: row,
    );
  }
}

/// In place of the map when there is no pin to show: a sentence, not an
/// empty continent.
class DirectoryMapPlaceholder extends StatelessWidget {
  const DirectoryMapPlaceholder({
    super.key,
    required this.text,
    this.busy = false,
  });

  final String text;

  /// The places are still being looked up: the hourglass alone, with
  /// [text] as what it says, since a status line above may say it too.
  final bool busy;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Center(
      child: Padding(
        padding: AppSpacing.mdAll,
        child: busy
            ? Icon(Icons.hourglass_top, semanticLabel: text)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wrong_location_outlined),
                  const SizedBox(height: AppSpacing.sm),
                  Text(text, textAlign: TextAlign.center),
                ],
              ),
      ),
    ),
  );
}
