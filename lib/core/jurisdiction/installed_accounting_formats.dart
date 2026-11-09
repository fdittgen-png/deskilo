// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the accounting formats this build installs, each
// declaring the chart its defaults are rows of and, for a journal file, its
// journals: a static list, compiled in, like the other capabilities.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_de/deskilo_jurisdiction_de.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:meta/meta.dart';

import 'jurisdiction_resolver.dart';

/// Every installed accounting format declaration.
@visibleForTesting
const List<AccountingFormatContribution> installedAccountingFormats = [
  DeDatevFormat(),
  FrFecFormat(),
];

/// What the installed add-on declares of [formatId]; a format the export can
/// run with no declaration is a composition fault, so this refuses.
AccountingFormatContribution accountingFormatOf(String formatId) =>
    resolveAccountingFormat(formatId, installedAccountingFormats) ??
    (throw StateError('no installed declaration for the $formatId format'));
