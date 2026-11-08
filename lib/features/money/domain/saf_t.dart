// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 -- moved to deskilo_accounting_interchange; this path re-exports it
// until the sweep PR (#3403).
//
// buildSafTFile is the one wrapper kept here: the package builds on the
// reference it is given; this fills in the installed snapshot
// (ActiveTaxReference) when the request carries none, as the writer always
// did. #3403 sweep: callers pass the workspace's reference, then this
// wrapper goes -- not a plain shim delete.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    as model
    show SafTRequest, buildSafTFile;

import '../../../core/vat/tax_reference_active.dart';

export 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    hide SageAccounts, buildSafTFile;

String buildSafTFile(model.SafTRequest request) => model.buildSafTFile(
  request.withReference(request.reference ?? ActiveTaxReference.current),
);
