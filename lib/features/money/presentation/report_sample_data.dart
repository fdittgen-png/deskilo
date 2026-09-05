// SPDX-License-Identifier: 0BSD
//
// The fixture the report editor's quick preview renders against when no
// real invoice exists yet (#474). Split out of report_defaults.dart:
// the shipped TEMPLATES and the SAMPLE DATA they are previewed with are
// separate concerns, and only one of them is legally load-bearing.
//
// Everything here is invented. Nothing reads the workspace, and nothing
// here may ever start to — a preview that quietly showed a real member's
// name and balance would leak one member's money to whoever is editing
// the template.
import '../../../l10n/app_localizations.dart';

/// Simulated-execution data (#474): a plausible invoice with lines and
/// VAT, plus the reminder and legal-mention fields (#480) — the quick
/// preview runs on it when no real invoice exists yet. Everything is
/// sample text, no live data.
Map<String, Object?> sampleReportData(AppLocalizations? l10n) => {
      'workspace': 'Coworking Demo',
      'workspace_address': '1 Example Street, 12345 Demo City',
      'member': 'Alex Sample',
      'number': 'INV-2026-0042',
      'period': 'July 2026',
      'issued': '2026-07-31',
      'issued_by': 'Demo Owner',
      'replaces': '',
      'total': '145,00 €',
      'charges': '165,00 €',
      'payments': '-20,00 €',
      'net_total': '120,83 €',
      'vat_total': '24,17 €',
      'voided': false,
      'proforma': false,
      'copy': false,
      'credit_note': false,
      'refund_total': '',
      'has_vat': true,
      'lines': [
        {
          'label': l10n?.invoicePdfDescription ?? 'Subscription',
          'amount': '120,00 €',
          'negative': false,
          'qty': '1',
          'unit_price': '120,00 €',
          'vat_rate': '20 %',
          'net': '100,00 €',
        },
        {
          'label': 'Extra day',
          'amount': '25,00 €',
          'negative': false,
          'qty': '1',
          'unit_price': '25,00 €',
          'vat_rate': '20 %',
          'net': '20,83 €',
        },
        {
          'label': 'Credit',
          'amount': '-20,00 €',
          'negative': true,
          'qty': '1',
          'unit_price': '-20,00 €',
          'vat_rate': '',
          'net': '-20,00 €',
        },
      ],
      'vat': [
        {'rate': '20 %', 'net': '120,83 €', 'amount': '24,17 €'},
      ],
      'reminder_level': 1,
      'reminder_date': '2026-08-15',
      'days_open': 15,
      // #480 — the legal mention variables, filled like a French SARL.
      'seller_legal_form': 'SARL au capital de 7 500 €',
      'seller_registration': 'RCS Demo City 123 456 789',
      // #871 — the bank block, so the designer's preview shows what a
      // real document will print rather than four empty lines.
      'iban': 'FR76 3000 1007 9412 3456 7890 185',
      'bic': 'BDFEFRPPCCT',
      'bank_name': 'Banque de Démonstration',
      'bank_account': '',
      'bank_code': '',
      'account_holder': 'Demo Coworking',
      'payment_reference': 'INV-2026-0007',
      'seller_vat_id': 'FR 39 680 357 910',
      'seller_legal_id': '680 357 910',
      'exemption_reason': '',
      'client_name': 'Anne DUPONT',
      'client_company': 'Atelier Dupont SARL',
      'client_phone': '+33 6 12 34 56 78',
      'client_email': 'anne@atelier-dupont.example',
      'client_address': 'Atelier Dupont SARL\n3 Avenue de la Liberté\n35000 RENNES',
      'client_vat_id': 'FR 79 849 149 108',
      'client_legal_id': '849 149 108',
      'payment_terms_source': 'workspace',
      'usage_paid': '100,00 €',
      'usage_included_half_days': '22',
      'usage_used_half_days': '6',
      'usage_remaining_half_days': '16',
      'usage_extra_half_days': '0',
      'usage_overage': '',
      'usage_supplements': '',
      'usage_records': [
        {'date': '2026-09-02', 'space': 'A1', 'counted': '4 h 00'},
        {'date': '2026-09-04', 'space': 'A1', 'counted': '8 h 00'},
      ],
      'payment_terms':
          l10n?.invoiceLegalPaymentTermsDefault ?? 'Payment on receipt.',
      'late_penalty': l10n?.invoiceLegalLatePenaltyDefault ??
          'Late-payment penalty: three times the statutory interest rate.',
      'recovery_indemnity': l10n?.invoiceLegalRecoveryDefault ??
          'Fixed recovery indemnity for collection costs: €40.',
      'escompte': l10n?.invoiceLegalEscompteDefault ??
          'No discount for early payment.',
      'insurance': '',
      'special_mentions': '',
    };
