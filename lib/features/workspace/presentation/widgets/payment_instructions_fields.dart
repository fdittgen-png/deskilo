// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The payment instructions form, shared by the payment methods screen and
// the setup guide's step: one field per way to pay, every one optional,
// the bank-code field labelled by the country's banking scheme (#711) and
// the QR-IBAN only for a Swiss space (#2360).
import 'package:flutter/material.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/payment_instructions.dart';

/// One controller per field, seeded from what is stored.
class PaymentInstructionsDraft {
  PaymentInstructionsDraft(PaymentInstructions stored)
    : iban = TextEditingController(text: stored.iban),
      accountNumber = TextEditingController(text: stored.accountNumber),
      bankCode = TextEditingController(text: stored.bankCode),
      bankName = TextEditingController(text: stored.bankName),
      bic = TextEditingController(text: stored.bic),
      qrIban = TextEditingController(text: stored.qrIban),
      paypalMe = TextEditingController(text: stored.paypalMe),
      reference = TextEditingController(text: stored.reference),
      wero = TextEditingController(text: stored.wero),
      lydia = TextEditingController(text: stored.lydia),
      wise = TextEditingController(text: stored.wise);

  final TextEditingController iban;
  final TextEditingController accountNumber;
  final TextEditingController bankCode;
  final TextEditingController bankName;
  final TextEditingController bic;
  final TextEditingController qrIban;
  final TextEditingController paypalMe;
  final TextEditingController reference;
  final TextEditingController wero;
  final TextEditingController lydia;
  final TextEditingController wise;

  List<TextEditingController> get _all => [
    iban,
    accountNumber,
    bankCode,
    bankName,
    bic,
    qrIban,
    paypalMe,
    reference,
    wero,
    lydia,
    wise,
  ];

  /// Fires on every keystroke in any field.
  Listenable get changes => Listenable.merge(_all);

  /// What the fields hold now.
  PaymentInstructions get value => PaymentInstructions(
    iban: iban.text,
    accountNumber: accountNumber.text,
    bankCode: bankCode.text,
    bankName: bankName.text,
    bic: bic.text,
    qrIban: qrIban.text,
    paypalMe: paypalMe.text,
    reference: reference.text,
    wero: wero.text,
    lydia: lydia.text,
    wise: wise.text,
  );

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

class PaymentInstructionsFields extends StatelessWidget {
  const PaymentInstructionsFields({
    super.key,
    required this.draft,
    required this.countryCode,
    required this.enabled,
  });

  final PaymentInstructionsDraft draft;

  /// The workspace's country: it names the bank-code field.
  final String countryCode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = CountryCatalog.byCode(countryCode).scheme;
    Widget field(String key, TextEditingController controller, String label) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextField(
            key: Key(key),
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(labelText: label),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(
          'workspaceSettingsIban',
          draft.iban,
          l10n.paymentInstructionsIbanTitle,
        ),
        // #711 — the fields a non-IBAN country needs, labelled by the
        // workspace's banking scheme: "Sort code" in London, "Routing
        // number" in New York, "Transit · institution" in Toronto.
        field(
          'workspaceSettingsBankName',
          draft.bankName,
          l10n.paymentBankNameLabel,
        ),
        field(
          'workspaceSettingsAccountNumber',
          draft.accountNumber,
          l10n.paymentAccountNumberLabel,
        ),
        field(
          'workspaceSettingsBankCode',
          draft.bankCode,
          bankCodeLabelFor(
            scheme,
            sortCode: l10n.paymentSortCodeLabel,
            routingNumber: l10n.paymentRoutingNumberLabel,
            transitNumber: l10n.paymentTransitNumberLabel,
            bankCode: l10n.paymentBankCodeLabel,
          ),
        ),
        // #2360 — a Swiss space also states the QR-IBAN of its QR-bill.
        if (scheme == BankingScheme.ch)
          field(
            'workspaceSettingsQrIban',
            draft.qrIban,
            l10n.paymentQrIbanLabel,
          ),
        field('workspaceSettingsBic', draft.bic, l10n.paymentBicLabel),
        field(
          'workspaceSettingsPaypalMe',
          draft.paypalMe,
          l10n.paymentInstructionsPaypalLabel,
        ),
        field(
          'workspaceSettingsWero',
          draft.wero,
          l10n.paymentInstructionsWeroLabel,
        ),
        field(
          'workspaceSettingsLydia',
          draft.lydia,
          l10n.paymentInstructionsLydiaLabel,
        ),
        field(
          'workspaceSettingsWise',
          draft.wise,
          l10n.paymentInstructionsWiseLabel,
        ),
        field(
          'workspaceSettingsReference',
          draft.reference,
          l10n.paymentInstructionsReferenceLabel,
        ),
      ],
    );
  }
}
