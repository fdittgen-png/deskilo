// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// #1851 — the explicit opt-in before an alpha or beta feature is
/// switched on. True only when the owner confirms; dismissing it writes
/// nothing.
Future<bool> confirmExperimentalOptIn(
  BuildContext context,
  List<String> featureNames,
) async {
  final l10n = AppLocalizations.of(context);
  final names = featureNames.join(', ');
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('feature-opt-in'),
      title: Text(
        l10n?.featureOptInTitle ?? 'Switch on an experimental feature?',
      ),
      content: Text(
        l10n?.featureOptInBody(names) ??
            'Not yet reviewed as stable: $names. It may change and has '
                'known limits. Switch on only if this space accepts that.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('feature-opt-in-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('feature-opt-in-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.featureOptInConfirm ?? 'Switch on'),
        ),
      ],
    ),
  );
  return answer ?? false;
}
