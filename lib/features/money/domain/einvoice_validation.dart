// SPDX-License-Identifier: AGPL-3.0-or-later
import 'einvoice_format.dart';

/// #2358 — the formats an OFFICIAL validator accepts, and which one.
///
/// "Ready — this file satisfies EN 16931" used to rest on a check of
/// which fields were present. Now every format named here has a sample
/// built by the app's own serializer (test/features/money/
/// einvoice_samples_test.dart) that the `CI · E-invoice validators`
/// workflow runs through the named validator at a pinned version
/// (tool/einvoice/validate.sh); test/lint/einvoice_validation_test.dart
/// keeps the three lists in step. The app claims validation for these
/// formats only, naming the validator.
///
/// Two are proven by their schema alone, and say so: the SdI and KSeF
/// check the business rules on submission, behind accounts. CIUS-RO runs
/// the UBL schema and the CEN rules; ANAF's own rules sit behind its web
/// service.
const Map<EInvoiceFormat, String> eInvoiceValidators = {
  EInvoiceFormat.facturX: 'Mustang 2.26.0 (PDF/A-3, Factur-X EN 16931, French CIUS)',
  EInvoiceFormat.en16931Ubl: 'KoSIT 1.6.3 (EN 16931 1.3.16)',
  EInvoiceFormat.en16931Cii: 'KoSIT 1.6.3 (EN 16931 1.3.16)',
  EInvoiceFormat.peppolBis: 'KoSIT 1.6.3 (Peppol BIS Billing 3.0.21)',
  EInvoiceFormat.xrechnung: 'KoSIT 1.6.3 (XRechnung 3.0.2)',
  EInvoiceFormat.ciusRo: 'KoSIT 1.6.3 (UBL 2.1, EN 16931 1.3.16)',
  EInvoiceFormat.fatturaPa: 'SdI schema FPR12 1.2.3',
  EInvoiceFormat.ksefFa3: 'KSeF schema FA(3)',
};
