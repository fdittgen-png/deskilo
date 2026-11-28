// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4497 -- the VATEX exemption-reason codes (the CEF code list for EN 16931, BT-121) a VAT rate of category E or O
// may name: one list, read by the invoice model and mirrored by the setup questionnaire (web/setup_params.js
// VAT_EXEMPTIONS), which test/lint/vatex_codes_parity_test.dart keeps equal to it.

/// Category O has exactly one (BR-O-10).
const vatexOutsideScope = 'VATEX-EU-O';

/// The codes by UNCL5305 category: E (exempt, by the article of Council Directive 2006/112/EC that exempts it) and
/// O (outside the scope of VAT). A rate of category Z (zero-rated) or S names none.
const vatRateExemptionCodes = <String, List<String>>{
  'E': [
    'VATEX-EU-79-C',
    'VATEX-EU-132',
    'VATEX-EU-143',
    'VATEX-EU-148',
    'VATEX-EU-151',
    'VATEX-EU-309',
  ],
  'O': [vatexOutsideScope],
};
