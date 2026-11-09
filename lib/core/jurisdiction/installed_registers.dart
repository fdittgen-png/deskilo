// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the registers add-ons this build installs: a static
// list, compiled in, like the other capabilities. A country not listed writes
// no register of issued invoices beside its return.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart';
import 'package:meta/meta.dart';

import 'jurisdiction_resolver.dart';

/// Every installed registers add-on.
@visibleForTesting
const List<RegisterContribution> installedRegisters = [EsRegisters()];

/// The registers of [country]'s law, or null when it asks none.
RegisterContribution? registersOf(String country) =>
    resolveRegisters(LegalContext(countryCode: country), installedRegisters);
