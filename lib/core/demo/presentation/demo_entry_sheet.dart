// SPDX-License-Identifier: 0BSD
//
// #1379 — what a visitor is told before they walk in.
//
// The sheet exists because the answer to "is this real?" has to be given
// BEFORE somebody starts clicking, not inferred afterwards from a badge.
// It says three things plainly: the data is invented, nothing reaches a
// real workspace or leaves the device, and no account is needed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_spacing.dart';
import '../demo_entry.dart';

/// The button that offers the demonstration space.
class DemoEntryButton extends ConsumerWidget {
  const DemoEntryButton({super.key});

  static const Key buttonKey = Key('demo-entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      key: buttonKey,
      icon: const Icon(Icons.play_circle_outline),
      label: Text(l10n?.demoEntryAction ?? 'Explore the demo workspace'),
      onPressed: () => showDemoEntrySheet(context, ref),
    );
  }
}

/// Explains the demonstration space, and enters it if the visitor agrees.
Future<void> showDemoEntrySheet(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final start = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.demoEntryTitle ?? 'A workspace to look around',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n?.demoEntryBody ??
                  'Everything in it is made up: the people, the bookings '
                      'and the bills are invented for the demonstration. '
                      'Nothing you do here reaches a real workspace, '
                      'nothing leaves this device, and no account is '
                      'needed. Reset puts it back whenever you like.',
            ),
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const Key('demo-entry-start'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n?.demoEntryStart ?? 'Start exploring'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (start ?? false) ref.read(demoEntryProvider.notifier).enter();
}
