// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 -- moved to deskilo_accounting_interchange; this path re-exports it
// (and the wrappers that keep the old signatures) until the sweep PR (#3403).
export 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    hide SageAccounts, buildSafTFile;
export '../../../core/vat/invoice_model_wrappers.dart' show SageAccounts, buildSafTFile;
