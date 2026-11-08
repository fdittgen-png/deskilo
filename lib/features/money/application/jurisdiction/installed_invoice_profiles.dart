// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the invoice profiles this build installs: a static list,
// compiled in, like the VAT filing add-ons. FatturaPA and the KSeF FA(3)
// have left the application; the others (UBL, CII) follow the same road.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';
import 'package:deskilo_jurisdiction_pl/deskilo_jurisdiction_pl.dart';

/// Every installed invoice profile.
final List<InvoiceProfileContribution> installedInvoiceProfiles = [
  const ItFatturaPaProfile(),
  const PlKsefFa3Profile(),
];
