// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3702 -- a level kept up because another level needs it, said beside the
// choices: which level holds it where it is.
import 'package:flutter/material.dart';

import '../../../../core/ui/inline_banner.dart';
import '../../domain/setup_levels.dart';

/// One line per process held, reading like a gap: "tax: VAT needs money:
/// invoices". [words] turns `process.level → process.minimum` into the line.
List<Widget> setupHeldNotes(
  Map<SetupProcess, ({SetupProcess by, String level})> held,
  SetupLevelVector vector,
  String Function(String gap) words,
) => [
  for (final MapEntry(key: process, value: hold) in held.entries)
    InlineBanner(
      key: ValueKey('setup-held-${process.name}'),
      icon: Icons.lock_outline,
      text: words(
        '${hold.by.name}.${hold.level} → ${process.name}.${vector[process]}',
      ),
    ),
];
