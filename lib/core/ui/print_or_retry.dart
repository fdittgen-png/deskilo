// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';
import '../trace/trace_logger.dart';
import 'app_snack.dart';

/// #3680 — runs a printing or export action whose sources are awaited reads.
/// A source that did not answer ends here: traced, then the read-failed
/// message with Retry, which calls [refresh] (the action's sources are
/// asked again, not their remembered failure) and runs the same action.
/// Never an uncaught error, and never a document built from a missing source.
Future<void> printOrRetry(
  BuildContext context,
  String what,
  Future<void> Function() run, {
  void Function()? refresh,
}) async {
  try {
    await run();
  } on Object catch (e, st) {
    TraceLogger.instance.error('money', '$what read failed', error: e, stackTrace: st);
    if (!context.mounted) return;
    AppSnack.error(
      context,
      context.l10n.readStateFailed,
      action: SnackBarAction(
        key: const ValueKey('print-read-retry'),
        label: context.l10n.commonRetry,
        onPressed: () {
          refresh?.call();
          unawaited(printOrRetry(context, what, run, refresh: refresh));
        },
      ),
    );
  }
}
