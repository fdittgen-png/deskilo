// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/app_failure_from.dart';
import '../failure/app_failure.dart';
import '../l10n/context_l10n.dart';
import '../ui/app_snack.dart';
import '../validation/pending_validation.dart';
import 'refusal_text.dart';
import 'trace_logger.dart';
import 'workspace_context_not_ready.dart';

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
///     errorText: context.l10n.workspaceGenericError,
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
    TraceLogger.instance.log(TraceLevel.info, domain, '$message: pending validation ${e.eventId}', stackTrace: st);
    if (context.mounted) {
      AppSnack.info(
        context,
        context.l10n.validationSentForApproval,
      );
    }
    return false;
  } on Object catch (e, st) {
    if (watched != null) watcher?.ended(watched, error: e);
    _traceCaught(domain, message, e, st, otherwise: TraceLevel.error);
    if (e is WorkspaceContextNotReady && context.mounted) {
      // #3403 -- the reference an action needs is not ready: say so, with or
      // without a caller-supplied text.
      AppSnack.error(context, context.l10n.workspaceTaxContextNotReady);
      return false;
    }
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
      final l10n = context.l10n;
      // #4170 — a sale refused for what the main store holds links to that item's stock
      final stockLink = isTransientNetworkFailure(e) ? null : refusalLinkOf(e);
      AppSnack.error(
        context,
        isTransientNetworkFailure(e)
            ? (l10n.errorOffline)
            : knownRefusalText(l10n, e) ?? errorText,
        action: stockLink == null
            ? null
            : SnackBarAction(label: l10n.refusalOpenStock, onPressed: () => context.go(stockLink)),
      );
    }
    return false;
  }
}

/// #4402 -- a form's save on the same guarded path as [runGuarded]: its start
/// and end in the trace, the watcher told, and what it threw traced under
/// [domain]/[message]. It answers instead of showing a snackbar: null when
/// [action] succeeded, else [problem]'s sentence for what it threw, which a
/// sheet says under its fields (or the caller shows). The one place a save
/// catches, so a screen never writes its own try/catch.
Future<String?> guardSave({
  required String domain,
  required String message,
  required Future<void> Function() action,
  required String Function(Object error) problem,
}) async {
  final what = message.replaceFirst(RegExp(r'\s+failed$'), '');
  TraceLogger.instance.log(TraceLevel.info, domain, '$what — started');
  final watcher = guardedCommandWatcher;
  final watched = watcher?.started(domain, message);
  try {
    await action();
    TraceLogger.instance.log(TraceLevel.info, domain, '$what — done');
    if (watched != null) watcher?.ended(watched);
    return null;
  } on Object catch (e, st) {
    if (watched != null) watcher?.ended(watched, error: e);
    _traceCaught(domain, message, e, st, otherwise: TraceLevel.warn);
    return problem(e);
  }
}

/// #4402 -- a read a screen needs before it can go on (the item behind an
/// editor, the variants of a sheet): [read]'s value, or, when it threw, the
/// trace of it under [domain]/[message] and [fallback]'s answer for the error
/// (which may say so on the screen). The one place such a read catches.
Future<T> guardRead<T>({
  required String domain,
  required String message,
  required Future<T> Function() read,
  required T Function(Object error) fallback,
}) async {
  try {
    return await read();
  } on Object catch (e, st) {
    _traceCaught(domain, message, e, st, otherwise: TraceLevel.warn);
    return fallback(e);
  }
}

/// The server's own refusal codes (`DKL04`): a sentence for the person, never
/// a fault of the app.
const _ownRefusalPrefix = 'DK';

/// The trace of what a guarded action caught, at the level its kind deserves:
/// an answer that could not be read or a defect of the app is an error, which
/// the reporter may send; a refusal the server worded itself is an answer, a
/// warning that stays on the device. Anything else (a lost connection, a
/// database error, a local [StateError]) keeps the level the guard always gave
/// it, [otherwise]: nothing proves it is one or the other.
void _traceCaught(
  String domain,
  String message,
  Object error,
  StackTrace stack, {
  required TraceLevel otherwise,
}) {
  final failure = appFailureFrom(error);
  final level = switch (failure) {
    _ when isReportableFailure(failure) => TraceLevel.error,
    Refusal(:final code?) when code.startsWith(_ownRefusalPrefix) =>
      TraceLevel.warn,
    _ => otherwise,
  };
  if (level == TraceLevel.error) {
    // Through `error`, which holds a single dropped connection down to a
    // warning and raises a run of them.
    TraceLogger.instance.error(domain, message, error: error, stackTrace: stack);
  } else {
    TraceLogger.instance.warn(domain, message, error: error, stackTrace: stack);
  }
}
