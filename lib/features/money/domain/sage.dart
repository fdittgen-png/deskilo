// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 -- moved to deskilo_accounting_interchange; this path re-exports it
// until the sweep PR (#3403).
//
// SageAccounts is the one wrapper kept here: the package's class reads its
// codes from the reference it is given, and falls back to nothing; this
// subclass falls back to the installed snapshot (ActiveTaxReference), as the
// class always did. #3403 sweep: callers pass the workspace's reference, then
// this file goes -- not a plain shim delete.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    as model
    show SageAccounts;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart'
    show TaxReferenceSet;

import '../../../core/vat/tax_reference_active.dart';

export 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    hide SageAccounts, buildSafTFile;

class SageAccounts extends model.SageAccounts {
  const SageAccounts({
    super.debtors,
    super.sales,
    super.bank,
    super.taxCode,
    super.reference,
  });

  @override
  TaxReferenceSet get installedReference => ActiveTaxReference.current;
}
