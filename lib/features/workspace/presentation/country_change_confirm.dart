// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/i18n/country_names.dart';
import '../../../core/l10n/context_l10n.dart';
import '../domain/workspace_feature.dart';
import 'feature_names.dart';

/// #2454 — asks before the space moves to [country], naming the features that
/// are on and that [country] does not offer. They stop working there; their
/// stored switches are kept, so they return if the country is changed back.
/// True when the owner agrees.
Future<bool> confirmCountryChange(
  BuildContext context,
  String country,
  List<WorkspaceFeature> lost,
) async {
  final l10n = context.l10n;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.countryChangeTitle),
      content: Text(
        l10n.countryChangeBody(
          localizedCountryName(l10n, country),
          [for (final f in lost) featureName(l10n, f)].join(', '),
        ),
        key: const ValueKey('country-change-body'),
      ),
      actions: [
        TextButton(
          key: const ValueKey('country-change-cancel'),
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('country-change-confirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.countryChangeConfirm),
        ),
      ],
    ),
  );
  return agreed ?? false;
}
