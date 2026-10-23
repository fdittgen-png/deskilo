// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../l10n/context_l10n.dart';
import '../ui/app_snack.dart';
import 'file_delivery.dart';
import 'file_saver.dart';

/// Tells the person what [delivery] achieved, in the platform's own terms:
/// "Saved to" only for a file they can open, a private copy named as such,
/// a browser request as a request, the share sheet as a hand-over, a
/// refusal as a refusal. [retry] is offered on a browser request, whose
/// hand-over a browser may have blocked: the action is the user gesture
/// that lets it through.
void announceFileDelivery(
  BuildContext context,
  FileDelivery delivery, {
  VoidCallback? retry,
}) {
  final l10n = context.l10n;
  switch (delivery) {
    case LocalSave(outcome: SavedFile(:final path)):
      AppSnack.success(context, l10n.commonSavedTo(path));
    case LocalSave(outcome: SavedPrivately(:final path)):
      AppSnack.info(context, l10n.fileKeptInApp(_nameOf(path)));
    case LocalSave(outcome: DownloadRequested(:final fileName)):
      AppSnack.info(
        context,
        l10n.fileDownloadRequested(fileName),
        action: retry == null
            ? null
            : SnackBarAction(
                key: const ValueKey('file-download-again'),
                label: l10n.fileDownloadAgain,
                onPressed: retry,
              ),
      );
    case LocalSave(outcome: SaveFailed(:final reason)):
    case DeliveryFailed(:final reason):
      AppSnack.error(context, _failure(l10n, reason));
    case HandedToShareSheet(:final fileName):
      AppSnack.info(context, l10n.fileHandedToShareSheet(fileName));
    case DeliveryCancelled():
      AppSnack.info(context, l10n.fileDeliveryCancelled);
  }
}

/// The file's own name: an app-private path means nothing to the person
/// and is not a place they can go.
String _nameOf(String path) => path.split('/').last;

String _failure(AppLocalizations l10n, SaveFailure reason) => switch (reason) {
  SaveFailure.noStorage => l10n.fileSaveFailedBecause(
    l10n.fileSaveFailureNoStorage,
  ),
  SaveFailure.writeFailed => l10n.fileSaveFailedBecause(
    l10n.fileSaveFailureWrite,
  ),
  SaveFailure.shareUnavailable => l10n.fileSaveFailedBecause(
    l10n.fileSaveFailureShare,
  ),
  SaveFailure.unknown => l10n.commonSaveFailed,
};
