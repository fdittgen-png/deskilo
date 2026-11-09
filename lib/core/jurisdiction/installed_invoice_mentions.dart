// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the national invoice mentions this build installs: a
// static list, compiled in, like the VAT filing add-ons and the invoice
// profiles. A country not listed states none.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ca/deskilo_jurisdiction_ca.dart';
import 'package:deskilo_jurisdiction_ch/deskilo_jurisdiction_ch.dart';
import 'package:deskilo_jurisdiction_de/deskilo_jurisdiction_de.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:deskilo_jurisdiction_gb/deskilo_jurisdiction_gb.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';
import 'package:deskilo_jurisdiction_us/deskilo_jurisdiction_us.dart';

/// Every installed invoice mentions add-on.
const List<InvoiceMentionsContribution> installedInvoiceMentions = [
  CaInvoiceMentions(),
  ChInvoiceMentions(),
  DeInvoiceMentions(),
  EsInvoiceMentions(),
  FrInvoiceMentions(),
  GbInvoiceMentions(),
  ItInvoiceMentions(),
  UsInvoiceMentions(),
];
