// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2012 C — one plan-media write from the editor (an illustration image,
// a background, its removal). While it runs, [busy] is true: the editor
// shows progress and a second write is refused, so a double tap is never
// a second image. A failure — refused, or an answer that never came — is
// said honestly: the image could not be CONFIRMED as saved. "Try again"
// reruns the SAME write: for an illustration image the same operation id
// (#2012 B), so a retry after a lost answer converges on one image.
import 'package:flutter/material.dart';

import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';

Future<void> runPlanMediaWrite(
  BuildContext context, {
  required ValueNotifier<bool> busy,
  required String trace,
  required Future<void> Function() write,
  required VoidCallback onDone,
}) async {
  if (busy.value) return;
  busy.value = true;
  try {
    await write();
  } catch (e, st) {
    TraceLogger.instance.error('editor', trace, error: e, stackTrace: st);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    AppSnack.error(
      context,
      l10n?.editorMediaWriteFailed ??
          'The image could not be confirmed as saved. Trying again never '
              'adds it twice.',
      replace: true,
      action: SnackBarAction(
        key: const ValueKey('plan-media-retry'),
        label: l10n?.commonRetry ?? 'Try again',
        onPressed: () {
          if (!context.mounted) return;
          runPlanMediaWrite(
            context,
            busy: busy,
            trace: trace,
            write: write,
            onDone: onDone,
          );
        },
      ),
    );
    return;
  } finally {
    busy.value = false;
  }
  onDone();
}
