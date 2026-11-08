// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 -- moved to deskilo_accounting_interchange; this path re-exports it
// until the sweep PR (#3403).
export 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    hide SageAccounts, buildSafTFile;
export 'sage.dart';
