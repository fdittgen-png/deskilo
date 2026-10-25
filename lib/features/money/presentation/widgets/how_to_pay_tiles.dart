// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// The bank details a country without IBAN needs on the how-to-pay
/// card (#711): bank name, account number, the routing code under its
/// LOCAL name (sort code / routing number / transit · institution),
/// and a BIC for cross-border transfers. One tile per filled field.
class BankDetailTiles extends ConsumerWidget {
  const BankDetailTiles({super.key, required this.instructions});

  final PaymentInstructions instructions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(children: [
// #711 — local bank details for the countries that do not
// bank by IBAN. One tile per filled field; the routing code
// wears its local name.
if (instructions.bankName.trim().isNotEmpty)
  ListTile(
    key: const Key('howToPayBankName'),
    leading: const Icon(Icons.account_balance_outlined),
    title: Text(l10n.paymentBankNameLabel),
    subtitle: Text(instructions.bankName.trim()),
  ),
if (instructions.accountNumber.trim().isNotEmpty)
  CopyTile(
    key: const Key('howToPayAccountNumber'),
    icon: Icons.numbers_outlined,
    title: l10n.paymentAccountNumberLabel,
    value: instructions.accountNumber.trim(),
    copiedMessage: l10n.paymentCopied,
  ),
if (instructions.bankCode.trim().isNotEmpty)
  CopyTile(
    key: const Key('howToPayBankCode'),
    icon: Icons.route_outlined,
    title: bankCodeLabelFor(
      CountryCatalog.byCode(
        ref.watch(currentWorkspaceProvider).value?.countryCode ?? '',
      ).scheme,
      sortCode: l10n.paymentSortCodeLabel,
      routingNumber:
          l10n.paymentRoutingNumberLabel,
      transitNumber:
          l10n.paymentTransitNumberLabel,
      bankCode: l10n.paymentBankCodeLabel,
    ),
    value: instructions.bankCode.trim(),
    copiedMessage: l10n.paymentCopied,
  ),
if (instructions.bic.trim().isNotEmpty)
  CopyTile(
    key: const Key('howToPayBic'),
    icon: Icons.swap_horiz_outlined,
    title: l10n.paymentBicLabel,
    value: instructions.bic.trim(),
    copiedMessage: l10n.paymentCopied,
  ),
    ]);
  }
}

/// A how-to-pay row whose value copies to the clipboard on tap (#155
/// IBAN pattern, shared with the #192 Wero/Lydia/Wise rows).
class CopyTile extends StatelessWidget {
  const CopyTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.copiedMessage,
  });

  final IconData icon;
  final String title;
  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('how-to-pay-tiles-copy'),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.copy_outlined, size: 18),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        AppSnack.success(context, copiedMessage);
      },
    );
  }
}


/// The workspace's payment instructions (#155): IBAN copies to the
/// clipboard, the PayPal.me link opens externally, the reference hint is
/// plain text. Purely informational — recording a payment stays the
/// separate spec §8 confirmation flow.
/// Public since #711 so the bank-scheme labelling can be tested on its
/// own; the bill composes it, nothing else constructs it.
class HowToPayCard extends ConsumerWidget {
  const HowToPayCard({super.key, required this.instructions, this.onPayOnline});

  final PaymentInstructions instructions;

  /// When non-null, a "Pay online" button heads the card (0043).
  final VoidCallback? onPayOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final paypalUri = instructions.paypalMeUri;
    // (field, icon, brand label) of the #192 copy-to-clipboard methods —
    // one data row per method instead of three pasted tiles.
    final copyMethods = [
      (
        'Wero',
        instructions.wero.trim(),
        Icons.smartphone_outlined,
        l10n.paymentMethodWero,
      ),
      (
        'Lydia',
        instructions.lydia.trim(),
        Icons.smartphone_outlined,
        l10n.paymentMethodLydia,
      ),
      (
        'Wise',
        instructions.wise.trim(),
        Icons.alternate_email,
        l10n.paymentMethodWise,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.paymentInstructionsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (onPayOnline != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FilledButton.icon(
                  key: const Key('pay-online-button'),
                  onPressed: onPayOnline,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(l10n.payOnlineButton),
                ),
              ),
            // #711 — bank details for countries without IBAN, labelled
            // by the workspace's banking scheme.
            BankDetailTiles(instructions: instructions),
            if (instructions.iban.trim().isNotEmpty)
              CopyTile(
                key: const Key('howToPayIban'),
                icon: Icons.account_balance_outlined,
                // IBAN is a language-neutral banking acronym — the key
                // carries it verbatim in every locale.
                title: l10n.paymentInstructionsIbanTitle,
                value: instructions.iban.trim(),
                copiedMessage:
                    l10n.paymentInstructionsIbanCopied,
              ),
            if (paypalUri != null)
              ListTile(
                key: const Key('howToPayPaypal'),
                leading: const Icon(Icons.open_in_new),
                // Brand name — reuses the #154 method label key.
                title: Text(l10n.paymentMethodPaypal),
                subtitle: Text(paypalUri.toString()),
                // Launch failures are traced inside the shared link seam.
                onTap: () => ref.read(linkLauncherProvider)(paypalUri),
              ),
            // #192 — Wero / Lydia / Wise: phone number, phone/username,
            // Wisetag or link. All copy to the clipboard like the IBAN;
            // the titles reuse the #154 method labels (brand names).
            for (final (keySuffix, value, icon, title) in copyMethods)
              if (value.isNotEmpty)
                CopyTile(
                  key: Key('howToPay$keySuffix'),
                  icon: icon,
                  title: title,
                  value: value,
                  copiedMessage: l10n.paymentInstructionsValueCopied,
                ),
            if (instructions.reference.trim().isNotEmpty)
              ListTile(
                key: const Key('howToPayReference'),
                leading: const Icon(Icons.tag_outlined),
                title: Text(
                  l10n.paymentInstructionsReferenceLabel,
                ),
                subtitle: Text(instructions.reference.trim()),
              ),
          ],
        ),
      ),
    );
  }
}
