// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_xml.dart';

/// #2494 — what the settings screen's tools need from its State: the
/// libraries that export, print, restore and reset reach the screen only
/// through this, so none of them reads another's private state.
abstract interface class WorkspaceSettingsHost {
  BuildContext get context;
  WidgetRef get ref;
  bool get mounted;

  /// True while a tool runs: every tool tile is disabled.
  bool get busy;

  /// Runs [action] with the screen's tools disabled until it ends.
  Future<void> whileBusy(Future<void> Function() action);

  /// Runs [action] guarded (trace + the screen's failure text) with the
  /// tools disabled; [message] is the trace line of a failure.
  Future<void> runTool(String message, Future<void> Function() action);

  /// Settings ride the EXISTING owner writers (#153/#155/#146) after an
  /// XML import; the brand colour's refusal, or ''.
  Future<String> applyImportedSettings(
    Workspace workspace,
    WorkspaceXmlData data,
    XmlImportProgress progress, {
    required bool switchTransferOn,
  });

  /// Re-seed the form so imported settings show immediately.
  void reseed();
}

/// #1532 — how far an XML import got, so a stop partway is not reported
/// as if nothing had happened.
class XmlImportProgress {
  bool anythingApplied = false;
}

/// Confirms a local export saved (or reports failure) — never a share.
void announceSaved(BuildContext context, AppLocalizations l10n, String? path,
    {SnackBarAction? action}) {
  if (path == null) {
    AppSnack.error(context, l10n.commonSaveFailed);
    return;
  }
  AppSnack.success(context, l10n.commonSavedTo(path), action: action);
}
