// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4163 -- what the server freezes on an issued invoice and the Demo must
// show too: the capacity the customer stated and the country (the France
// e-reporting sorts the buyer from these, never from a VAT number). A Demo
// invoice that states none is a consumer in the Demo's own country, as every private
// customer of the Demo is; the Demo's business customer states `business`.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../features/money/application/jurisdiction/installed_vat_filings.dart';

/// The frozen legal facts a stated [capacity] (`business` or `consumer`)
/// leaves on an invoice.
Map<String, Object?> demoFrozenCapacity(String capacity, {String? country}) => {
  'schema': 1,
  'buyer_capacity': capacity,
  'capacity_source': 'member',
  'buyer_country': country ?? eReportingCountry,
};

/// [invoice] as the server would hold it: with its frozen capacity, a
/// consumer when none was stated.
Invoice withDemoCapacity(Invoice invoice) => invoice.legalSnapshot != null
    ? invoice
    : invoice.copyWith(
        legalSnapshot: demoFrozenCapacity(
          'consumer',
          country: invoice.buyerParty?.country.isNotEmpty ?? false
              ? invoice.buyerParty!.country
              : null,
        ),
      );
