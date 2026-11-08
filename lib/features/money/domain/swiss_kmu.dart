// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 -- moved to deskilo_accounting_interchange; this path only re-exports it
// until the sweep PR (#3403) rewrites the importers and deletes it.
export 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    hide SageAccounts, buildSafTFile;
