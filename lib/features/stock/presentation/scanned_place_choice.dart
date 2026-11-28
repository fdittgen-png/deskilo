// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4495 -- a scanned code that several places carry (Site A / Shop and Site B / Shop are both SHOP): the person says which one, as site ›
// place. Nothing is chosen for them; closing the sheet scans nothing.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/form_sheet.dart';
import '../domain/stock_code_resolver.dart';

/// Asks which of [places] the scanned [code] means; null when the sheet is closed without a choice.
Future<ScannedPlace?> showScannedPlaceChoice(BuildContext context, String code, List<ScannedPlace> places) => showAppSheet<ScannedPlace>(
  context: context,
  builder: (context) => SheetShell(
    title: context.l10n.stockScanWhichPlace(code),
    children: [
      for (final p in places)
        ListTile(
          key: ValueKey('scan-place-choice-${p.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(p.path.isEmpty ? p.name : p.path),
          onTap: () => Navigator.of(context).pop(p),
        ),
    ],
  ),
);
