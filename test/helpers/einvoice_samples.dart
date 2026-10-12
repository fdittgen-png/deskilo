// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/einvoice_format.dart';

/// #2358 — the sample file each format is validated as, by
/// tool/einvoice/validate.sh (see einvoice_validation.dart).
const Map<EInvoiceFormat, String> eInvoiceSampleFiles = {
  EInvoiceFormat.facturX: 'factur-x.pdf',
  EInvoiceFormat.en16931Ubl: 'en16931-ubl.xml',
  EInvoiceFormat.en16931Cii: 'en16931-cii.xml',
  EInvoiceFormat.peppolBis: 'peppol-bis.xml',
  EInvoiceFormat.xrechnung: 'xrechnung.xml',
  EInvoiceFormat.ciusRo: 'cius-ro.xml',
  EInvoiceFormat.fatturaPa: 'fatturapa.xml',
  EInvoiceFormat.ksefFa3: 'ksef-fa3.xml',
};
