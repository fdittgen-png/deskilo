// SPDX-License-Identifier: 0BSD
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
  try {
    await action();
    return true;
  } catch (e, st) {
    debugPrint('$message: $e\n$st');
    TraceLogger.instance.error(domain, message, error: e, stackTrace: st);
    if (errorText != null && context.mounted) {
      AppSnack.error(context, errorText);
    }
    return false;
  }
}
