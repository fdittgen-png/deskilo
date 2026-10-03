// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// #1851 — the explicit opt-in before an alpha or beta feature is
/// switched on. True only when the owner confirms; dismissing it writes
/// nothing.
///
/// #1851 B — the preview says, before anything is written, which features
/// ask for consent and at what stage of review each one is, and which
/// prerequisites come on with them and how many.
Future<bool> confirmExperimentalOptIn(
  BuildContext context,
  List<String> featureNames, {
  List<String> stages = const [],
  List<String> alsoOn = const [],
}) async {
  final l10n = AppLocalizations.of(context);
  final names = featureNames.join(', ');
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('feature-opt-in'),
      title: Text(
        l10n?.featureOptInTitle ?? 'Switch on an experimental feature?',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.featureOptInBody(names) ??
                  'Not yet reviewed as stable: $names. It may change and '
                      'has known limits. Switch on only if this space '
                      'accepts that.',
            ),
            for (final (i, name) in featureNames.indexed)
              if (i < stages.length)
                Padding(
                  key: ValueKey('feature-opt-in-stage-$i'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n?.featureOptInStage(name, stages[i]) ??
                        '$name: ${stages[i]}',
                  ),
                ),
            if (alsoOn.isNotEmpty)
              Padding(
                key: const ValueKey('feature-opt-in-also-on'),
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n?.featureOptInAlsoOn(alsoOn.length, alsoOn.join(', ')) ??
                      'Also switched on, because they are needed '
                          '(${alsoOn.length}): ${alsoOn.join(', ')}',
                ),
              ),
          ],
        ),
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
