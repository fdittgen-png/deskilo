// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/messenger_actions.dart';
import '../../domain/messenger.dart';

/// #1824 — the sentence for a refusal the server explained.
String refusalText(AppLocalizations? l10n, MessengerRefusal refusal) =>
    switch (refusal) {
      MessengerRefusal.locked =>
        l10n?.messengerForwardLocked ??
            'The author locked this message against forwarding.',
      MessengerRefusal.forwardingOff =>
        l10n?.messengerRefusedForwardingOff ??
            'This space does not allow forwarding its messages.',
      MessengerRefusal.tooLong =>
        l10n?.messengerRefusedTooLong ??
            'This message is too long for that conversation.',
      MessengerRefusal.closed =>
        l10n?.messengerRefusedClosed ?? 'This inquiry is closed.',
      MessengerRefusal.unavailable =>
        l10n?.messengerRefusedUnavailable ??
            'This space does not take inquiries right now.',
      MessengerRefusal.limit =>
        l10n?.messengerRefusedLimit ??
            'Too many at once. Please wait a minute.',
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
        refusalText(AppLocalizations.of(context), refusal),
      );
    }
    return false;
  }
  return ok;
}
