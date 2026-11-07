// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the invoice profiles this build installs: a static list,
// compiled in, like the VAT filing add-ons. FatturaPA is the first profile
// that left the application; the others (UBL, CII, KSeF) follow the same road.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';

/// Every installed invoice profile.
final List<InvoiceProfileContribution> installedInvoiceProfiles = [
  const ItFatturaPaProfile(),
];
