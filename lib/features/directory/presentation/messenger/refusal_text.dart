// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/messenger_actions.dart';
import '../../domain/messenger.dart';

/// #1824 — the sentence for a refusal the server explained.
String refusalText(AppLocalizations l10n, MessengerRefusal refusal) =>
    switch (refusal) {
      MessengerRefusal.locked =>
        l10n.messengerForwardLocked,
      MessengerRefusal.forwardingOff =>
        l10n.messengerRefusedForwardingOff,
      MessengerRefusal.tooLong =>
        l10n.messengerRefusedTooLong,
      MessengerRefusal.closed =>
        l10n.messengerRefusedClosed,
      MessengerRefusal.unavailable =>
        l10n.messengerRefusedUnavailable,
      MessengerRefusal.requestPending =>
        l10n.messengerRefusedRequestPending,
      MessengerRefusal.limit =>
        l10n.messengerRefusedLimit,
    };

/// [runGuarded], except that a refusal the server explained is said in
/// its own words rather than as a fault. Answers whether it went through.
Future<bool> runMessenger(
  BuildContext context, {
  required String message,
  required String errorText,
  required Future<void> Function() action,
}) async {
  MessengerRefusal? refused;
  final ok = await runGuarded(
    context,
    domain: 'messages',
    message: message,
    errorText: errorText,
    action: () async {
      try {
        await action();
      } catch (e, st) {
        refused = MessengerActions.refusalOf(e);
        if (refused == null) rethrow;
        TraceLogger.instance.warn(
          'messages',
          '$message: refused (${refused!.name})',
          error: e,
          stackTrace: st,
        );
      }
    },
  );
  final refusal = refused;
  if (refusal != null) {
    if (context.mounted) {
      AppSnack.error(
        context,
        refusalText(context.l10n, refusal),
      );
    }
    return false;
  }
  return ok;
}
