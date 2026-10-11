// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../providers/blocks_providers.dart';
import '../../providers/messenger_providers.dart';

/// #2211 — asks, then blocks [peer] on [source]; true when it is done.
/// Cancelling blocks nobody.
Future<bool> confirmAndBlock(
  BuildContext context,
  WidgetRef ref, {
  required String source,
  required String peer,
  required String name,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      content: Text(l10n.blockPersonConfirm(name)),
      actions: [
        TextButton(
          key: const ValueKey('account-block-cancel'),
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('account-block-confirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.blockPersonAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final ok = await runGuarded(
    context,
    domain: 'messages',
    message: 'block account failed',
    action: () =>
        ref.read(messengerActionsProvider(source: source)).blockAccount(peer),
  );
  if (!ok || !context.mounted) return false;
  ref.invalidate(myBlocksProvider(source));
  AppSnack.success(context, l10n.blockPersonDone, replace: true);
  return true;
}
