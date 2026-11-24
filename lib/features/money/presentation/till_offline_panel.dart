// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- what the till says about selling offline, above the basket: that it is offline and cash only, how many sales wait
// on the device, a way to look for the connection now, and, when the offline data of the device cannot be read, that nothing is sold
// offline until a manager decides (and the way to drop the data, after a warning).
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import 'till_offline_mode.dart';

class TillOfflinePanel extends StatelessWidget {
  const TillOfflinePanel({super.key, required this.status, required this.onSend, required this.onDiscard});

  final TillOfflineStatus status;
  final VoidCallback? onSend;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    if (status.unreadable) {
      return _Strip(
        key: const ValueKey('till-offline-unreadable'),
        color: scheme.errorContainer,
        children: [
          Text(l10n.tillOfflineUnreadable),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(key: const ValueKey('till-offline-discard'), onPressed: onDiscard, child: Text(l10n.tillOfflineDiscard)),
        ],
      );
    }
    if (!status.active && status.waiting == 0) return const SizedBox.shrink();
    return _Strip(
      key: const ValueKey('till-offline-banner'),
      color: scheme.tertiaryContainer,
      children: [
        if (status.active) Text(l10n.tillOfflineBanner, style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (status.waiting > 0) Text(l10n.tillOfflineWaiting(status.waiting), key: const ValueKey('till-offline-waiting')),
            if (status.syncing) Text(l10n.tillOfflineSyncing, key: const ValueKey('till-offline-syncing')),
            if (status.active && !status.syncing) TextButton(key: const ValueKey('till-offline-send'), onPressed: onSend, child: Text(l10n.tillOfflineSendNow)),
          ],
        ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({super.key, required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// The discard of unreadable offline data is asked twice: sales not sent yet are lost for good.
Future<bool> confirmDiscardOffline(BuildContext context) async {
  final l10n = context.l10n;
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      scrollable: true,
      title: Text(l10n.tillOfflineDiscard),
      content: Text(l10n.tillOfflineDiscardBody),
      actions: [
        TextButton(key: const ValueKey('till-offline-discard-cancel'), onPressed: () => Navigator.of(c).pop(false), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)),
        FilledButton(key: const ValueKey('till-offline-discard-confirm'), onPressed: () => Navigator.of(c).pop(true), child: Text(l10n.tillOfflineDiscardConfirm)),
      ],
    ),
  );
  return go ?? false;
}
