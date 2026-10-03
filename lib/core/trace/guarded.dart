// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../l10n/app_localizations.dart';
import '../validation/pending_validation.dart';
import 'package:flutter/widgets.dart';

import '../ui/app_snack.dart';
import 'refusal_text.dart';
import 'trace_logger.dart';

/// #2142 — told about each guarded command while something listens: the
/// task recorder, while it records, sets it and clears it again. With
/// nothing set, [runGuarded] does exactly what it did before.
abstract interface class GuardedCommandWatcher {
  /// Before the action. A null token means "not watched".
  Object? started(String domain, String message);

  /// After it: [error] when it failed, [pending] when a policy held it.
  void ended(Object token, {Object? error, bool pending = false});
}

/// The watcher, when one listens.
GuardedCommandWatcher? guardedCommandWatcher;

/// Runs a mutating [action] with THE error boilerplate every call site
/// used to open-code: on failure the error is debug-printed, traced to
/// [TraceLogger] under [domain]/[message], and — when [errorText] is
/// given and [context] still mounted — surfaced as an error snackbar.
///
/// Returns whether the action succeeded, so call sites branch with one
/// line instead of a ten-line try/catch:
///
/// ```dart
/// if (!await runGuarded(context,
///     domain: 'money',
///     message: 'fee band save failed',
///     errorText: l10n?.workspaceGenericError ?? '…',
///     action: () => repo.replaceFeeBands(id, bands))) return;
/// ```
Future<bool> runGuarded(
  BuildContext context, {
  required String domain,
  required String message,
  required Future<void> Function() action,
  String? errorText,
}) async {
  // #1012 — every guarded action leaves its start and its end in the
  // trace, so a button that "does nothing" shows a start with no end,
  // and a device that pretends shows what it actually did.
  final what = message.replaceFirst(RegExp(r'\s+failed$'), '');
  TraceLogger.instance.log(TraceLevel.info, domain, '$what — started');
  final watcher = guardedCommandWatcher;
  final watched = watcher?.started(domain, message);
  try {
    await action();
    TraceLogger.instance.log(TraceLevel.info, domain, '$what — done');
    if (watched != null) watcher?.ended(watched);
    return true;
  } on PendingValidationException catch (e, st) {
    if (watched != null) watcher?.ended(watched, pending: true);
    // #982 — not a failure: the policy holds the act for a decision. One
    // notice, the same everywhere, and the caller treats it as "not
    // done" (the feed shows the pending request).
    TraceLogger.instance.log(TraceLevel.info, domain, '$message: pending validation ${e.eventId}');
    debugPrint('$message: pending validation $st');
    if (context.mounted) {
      AppSnack.info(
        context,
        AppLocalizations.of(context)?.validationSentForApproval ??
            'Sent for validation — it applies once approved.',
      );
    }
    return false;
  } catch (e, st) {
    if (watched != null) watcher?.ended(watched, error: e);
    debugPrint('$message: $e\n$st');
    TraceLogger.instance.error(domain, message, error: e, stackTrace: st);
    if (errorText != null && context.mounted) {
      // #1241 — "Something went wrong. Please try again." is the wrong
      // sentence for a dropped connection. It reads as a fault in the
      // app, it does not say the attempt never reached the server, and
      // it does not tell the reader the one thing they can act on:
      // there is no network, and nothing was sent.
      //
      // This is the single point every guarded action passes through,
      // so one check covers the whole app. There is no write queue yet
      // (#1241 step 3, which needs the idempotency work first) — saying
      // so plainly is step one, and it ships today.
      //
      // #1305 — and a refusal is not a fault either: "you may not", "your
      // session ended", "someone already decided" each say what to do,
      // where the caller's generic text would only say "try again".
      final l10n = AppLocalizations.of(context);
      AppSnack.error(
        context,
        isTransientNetworkFailure(e)
            ? (l10n?.errorOffline ??
                'No connection — nothing was sent. Try again when you '
                    'are back online.')
            : knownRefusalText(l10n, e) ?? errorText,
      );
    }
    return false;
  }
}
