// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2331 — the configuration of an imported file is never dropped in
// silence.
//
// The XML import applies a file's `<configuration>` (tariffs, legal
// identity, booking and validation rules, roles) only while the space has
// "Configuration in the space file" on. That flag is a platform feature,
// off on a new space, so the very first import — the setup questionnaire's
// file onto the space its owner just created — used to apply the plan and
// the settings and skip the rest without a word. This dialog says so
// before anything is applied, and lets somebody who may change the
// configuration switch the feature on for this import.
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_feature.dart';
import '../feature_names.dart';

/// Asks what to do with a file's configuration on a space that has the
/// configuration transfer off. Pops `true` (switch it on and apply),
/// `false` (import without the configuration) or `null` (cancel).
/// [maySwitchOn] hides the first choice from somebody who may not change
/// the space's features.
Future<bool?> askConfigurationTransfer(
  BuildContext context, {
  required bool maySwitchOn,
}) {
  // English only where no localization is installed (a bare test app).
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('en'));
  final feature = featureName(l10n, WorkspaceFeature.configurationTransfer);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.workspaceXmlImportConfigurationOffTitle),
      content: Text(
        maySwitchOn
            ? l10n.workspaceXmlImportConfigurationOffBody(feature)
            : l10n.workspaceXmlImportConfigurationOffNoRight(feature),
      ),
      actions: [
        TextButton(
          key: const Key('configurationTransferCancel'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: const Key('configurationTransferSkip'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.workspaceXmlImportConfigurationSkip),
        ),
        if (maySwitchOn)
          FilledButton(
            key: const Key('configurationTransferSwitchOn'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.workspaceXmlImportConfigurationSwitchOn),
          ),
      ],
    ),
  );
}
