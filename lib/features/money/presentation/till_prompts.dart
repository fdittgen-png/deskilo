// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- what the till asks before a line is rung up: the age of the customer for an age-restricted item.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';

/// Asks the operator to confirm that the customer is at least [minAge] for [name]; true only when confirmed.
Future<bool> showTillAgeDialog(BuildContext context, {required String name, required int minAge}) async {
  final l10n = context.l10n;
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(name),
      content: Text(l10n.tillAgeQuestion(minAge)),
      actions: [
        TextButton(key: const ValueKey('till-age-no'), onPressed: () => Navigator.of(c).pop(false), child: Text(l10n.tillAgeNo)),
        FilledButton(key: const ValueKey('till-age-yes'), onPressed: () => Navigator.of(c).pop(true), child: Text(l10n.tillAgeYes(minAge))),
      ],
    ),
  );
  return yes == true;
}
