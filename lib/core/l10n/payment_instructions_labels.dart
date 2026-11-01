// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The words of the bank-account fields of the payment instructions, as the
// Payment methods screen labels them, for the places that name a field
// without drawing its input: an assistant's proposal to change the account
// (#3132) and the owners' notice that it changed.
import '../../l10n/app_localizations.dart';

/// The label of one bank-account field by its wire key, or null for a key
/// that is not one of them.
String? paymentInstructionsFieldLabel(AppLocalizations l10n, String key) =>
    switch (key) {
      'iban' => l10n.paymentInstructionsIbanTitle,
      'bic' => l10n.paymentBicLabel,
      'bank_name' => l10n.paymentBankNameLabel,
      'account_number' => l10n.paymentAccountNumberLabel,
      'bank_code' => l10n.paymentBankCodeLabel,
      'qr_iban' => l10n.paymentQrIbanLabel,
      _ => null,
    };
