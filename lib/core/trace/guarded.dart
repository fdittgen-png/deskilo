// SPDX-License-Identifier: 0BSD
import '../../l10n/app_localizations.dart';
import '../validation/pending_validation.dart';
import 'package:flutter/widgets.dart';

import '../ui/app_snack.dart';
import 'trace_logger.dart';

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
  try {
    await action();
    TraceLogger.instance.log(TraceLevel.info, domain, '$what — done');
    return true;
  } on PendingValidationException catch (e, st) {
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
    debugPrint('$message: $e\n$st');
    TraceLogger.instance.error(domain, message, error: e, stackTrace: st);
    if (errorText != null && context.mounted) {
      AppSnack.error(context, errorText);
    }
    return false;
  }
}
